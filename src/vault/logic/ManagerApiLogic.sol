/*
Copyright 2024 Vessel Team.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific
language governing permissions and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { Address } from "lib/openzeppelin-contracts/contracts/utils/Address.sol";
import { Common } from "../generic/Common.sol";
import { Constants } from "../generic/Constants.sol";
import { DataTypes } from "../generic/DataTypes.sol";
import { Storage } from "../generic/Storage.sol";

contract ManagerApiLogic is Storage {
    using Common for bool;

    /**********
     * Errors *
     **********/
    error SNARKProof_ProofRejectedByVerifier();
    error SNARKProof_InstanceLengthNotMatchSnarkProof(uint256 expect, uint256 actual);
    error SNARKProof_InstanceNotMatch_StateBefore(uint256 expect, uint256 actual);
    error SNARKProof_InstanceNotMatch_StateAfter(uint256 expect, uint256 actual);
    error SNARKProof_StateNotMatch_MerkleRoot();
    error SNARKProof_StateNotMatch_MsgQueueCnt();
    error SNARKProof_StateNotMatch_L1MsgQueueHashBefore();
    error SNARKProof_StateNotMatch_L1MsgQueueHashAfter();
    error SNARKProof_StateNotMatch_L2MsgQueueHashBefore();
    error L1Msg_InvalidNextL1Cp();
    error L1Msg_InvalidConfirmation();
    error L2Msg_TypeNotSupported();
    error L2Msg_MessageHashNotMatch();
    error MsgValueInsufficient(uint256 actual, uint256 msgValue);
    error PendingWithdraw_Overflow();

    /**********
     * Events *
     **********/
    event LogProofCommitted(uint256 batchId, uint256 lastEventId);
    event LogNewEternalTreeRoot(uint256);
    event LogNewEphemeralTreeRoot(uint256);
    event LogNewPendingWithdrawAmount(address account, uint256 assetId, uint256 amount);
    // solhint-disable-next-line max-line-length
    event LogL1ToL2MessageQueueFastWithdraw(address lpAddr, address recipientAddr, uint256 assetId, uint256 assetAmount, uint256 nonce, bytes32 newHash);
    event LogFastWithdrawBackfill(address lpAddress, uint256 assetId, uint256 amount);
    event LogAmmPoolCreated(
        uint32 poolId,
        uint32 baseAssetId,
        uint32 quoteAssetId,
        uint128 minPrice,
        uint128 priceDelta,
        uint64 totalTicks,
        uint64 curTickIndex
    );
    event LogL1ToL2MessageQueueUpdate(uint256 newIndex);
    event LogL2ToL1MessageQueueUpdate(bytes32 newHash);

    /*************************
     * Public View Functions *
     *************************/

    /// @dev calculate stateHash for given state. 
    function calculateStateHash(DataTypes.VesselState calldata _state) public pure returns (bytes32) {
        bytes memory _b = abi.encode(_state.eternalTreeRoot, _state.ephemeralTreeRoot);
        for (uint256 _i = 0; _i < _state.l1MessageQueueHash.length; _i++) {
            _b = abi.encode(_b, _state.l1MessageQueueHash[_i]);
        }
        for (uint256 _i = 0; _i < _state.l2MessageQueueHash.length; _i++) {
            _b = abi.encode(_b, _state.l2MessageQueueHash[_i]);
        }

        return keccak256(_b);
    }

    /// @dev Encode (uint256[], bytes) into calldata.
    function encodeVerifyData(
        uint256[] memory _instances,
        bytes calldata _proof
    )
        public
        pure
        returns (bytes memory _encodedData)
    {
        bytes memory _instancesData = abi.encodePacked(_instances);
        _encodedData = abi.encodePacked(_instancesData, _proof);
    }

    /// @dev Encode data and call verifier.
    function verifySnarkProof(
        uint256[] calldata _instances,
        bytes calldata _proof,
        address _snarkVerifier
    )
        public
        view
        returns (bool)
    {
        bytes memory _data = encodeVerifyData(_instances, _proof);
        bool _success = false;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _success := staticcall(gas(), _snarkVerifier, add(_data, 0x20), mload(_data), 0, 0)
        }
        return _success;
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    function preCommitSubChainProgress(uint256 _nextL1CommitIndex) public payable {
        if (_nextL1CommitIndex < l1ToL2MessageQueueCommitIndex || _nextL1CommitIndex > l1ToL2MessageQueueTailIndex) {
            revert L1Msg_InvalidNextL1Cp();
        }

        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: logicChainId,
            l1MessageCnt: _nextL1CommitIndex - l1ToL2MessageQueueCommitIndex,
            l1LastCommitHash: l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex],
            l1NextCommitHash: l1ToL2MessageQueueHash[_nextL1CommitIndex],
            l2LastCommitHash: l2ToL1MessageQueueCommitHash
        });

        // Perform d-call to MultiChainLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "sendMessageToPrimary((uint32,uint256,bytes32,bytes32,bytes32))",
            _cp
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success, bytes memory _res) = multiChainLogicAddress.delegatecall(_data);
        _success.popupRevertReason();

        // refund excessive native fee
        uint256 _actualFee = abi.decode(_res, (uint256));
        _refundExcessiveMsgValue(_actualFee);
    }

    function finalizePostCommitConfirmation(bytes[] calldata _l2Messages) public {
        DataTypes.PostCommitConfirmation storage c = postCommitConfirmation;

        // Finalize l1 message queue update on subsidiary chain.
        uint256 _newL1Index = l1ToL2MessageQueueCommitIndex + c.l1MessageCnt;
        if (_newL1Index > l1ToL2MessageQueueTailIndex || l1ToL2MessageQueueHash[_newL1Index] != c.l1NextCommitHash) {
            revert L1Msg_InvalidConfirmation();
        } else {
            updateL1ToL2MessageQueue(_newL1Index);
        }

        // Finalize l2 message queue update on subsidiary chain.
        bytes32 _newL2Hash = l2ToL1MessageQueueCommitHash;
        for (uint256 _i = 0; _i < _l2Messages.length; _i++) {
            if (_l2Messages[_i][32] == 0) {
                // Perform s-call to decode withdraw msg
                bytes memory _data = abi.encodeWithSignature("decodeWithdrawMessage(bytes)", _l2Messages[_i]);
                (bool _success, bytes memory _returnData) = messageQueueLogicAddress.staticcall(_data);
                _success.popupRevertReason();
                (
                    bytes32 _prevMessageQueueHash,
                    address _userAddress,
                    uint32 _assetId,
                    uint128 _withdrawAmount
                ) = abi.decode(_returnData, (bytes32, address, uint32, uint128));

                _increasePendingWithdraw(_userAddress, _assetId, _withdrawAmount);
                if (_prevMessageQueueHash != _newL2Hash) {
                    revert L2Msg_MessageHashNotMatch();
                }
            } else if (_l2Messages[_i][32] == bytes1(uint8(1))) {
                // Perform s-call to decode ammPoolCreate msg
                bytes memory _data = abi.encodeWithSignature("decodeAmmPoolCreateMessage(bytes)", _l2Messages[_i]);
                (bool _success, bytes memory _returnData) = messageQueueLogicAddress.staticcall(_data);
                _success.popupRevertReason();
                (
                    bytes32 _prevMessageQueueHash,
                    uint32 _poolId,
                    uint32 _baseAssetId,
                    uint32 _quoteAssetId,
                    uint128 _minPrice,
                    uint128 _priceDelta,
                    uint64 _totalTicks,
                    uint64 _curTickIndex
                ) = abi.decode(_returnData, (bytes32, uint32, uint32, uint32, uint128, uint128, uint64, uint64));

                if (_prevMessageQueueHash != _newL2Hash) {
                    revert L2Msg_MessageHashNotMatch();
                }
                emit LogAmmPoolCreated(
                    _poolId, _baseAssetId, _quoteAssetId, _minPrice, _priceDelta, _totalTicks, _curTickIndex
                );
            } else if (_l2Messages[_i][32] == bytes1(uint8(2))) {
                // Perform s-call to decode fastWithdraw msg
                bytes memory _data = abi.encodeWithSignature("decodeFastWithdrawL2Message(bytes)", _l2Messages[_i]);
                (bool _success, bytes memory _returnData) = messageQueueLogicAddress.staticcall(_data);
                _success.popupRevertReason();
                (
                    bytes32 _prevMessageQueueHash,
                    address _lpAddr,
                    uint32 _assetId,
                    uint128 _backfillAmount
                ) = abi.decode(_returnData, (bytes32, address, uint32, uint128));

                // Perform d-call to backfill fast-withdraw LP
                _data = abi.encodeWithSignature(
                    "backfillToExitLp(address,uint256,uint256)",
                    _lpAddr,
                    _assetId,
                    _backfillAmount
                );
                // solhint-disable-next-line avoid-low-level-calls
                (_success,) = tokenManagerLogicAddress.delegatecall(_data);
                _success.popupRevertReason();

                if (_prevMessageQueueHash != _newL2Hash) {
                    revert L2Msg_MessageHashNotMatch();
                }
                emit LogFastWithdrawBackfill(_lpAddr, _assetId, _backfillAmount);
            } else {
                revert L2Msg_TypeNotSupported();
            }

            _newL2Hash = keccak256(_l2Messages[_i]);
        }

        if (_newL2Hash != c.l2NextCommitHash) {
            revert L2Msg_MessageHashNotMatch();
        } else {
            updateL2ToL1MessageQueue(_newL2Hash);
            c.l1MessageCnt = 0;
        }
    }

    function commitSnarkProof(
        uint256[] calldata _instances,
        bytes calldata _proof,
        DataTypes.VesselState calldata _stateBefore,
        DataTypes.VesselState calldata _stateAfter,
        uint256 _batchId,
        uint256 _lastEventId
    )
        public
        payable
    {
        _verifySnarkProofAndStateHash(_instances, _proof, _stateBefore, _stateAfter);
        _updateMerkleTreeRoot(_stateBefore, _stateAfter);
        _updateCheckPointAndSendConfirmation(_stateBefore, _stateAfter);
        _updateProofCommitmentMetadata(_batchId, _lastEventId);
    }

    function fastWithdraw(
        address _lpAddr,
        address _recipientAddr,
        uint256 _assetId,
        uint256 _assetAmount,
        uint256 _feeAmount,
        uint256 _nonce
    )
        public
    {
        // Perform d-call to transfer token from exit LP to recipient
        bytes memory _data = abi.encodeWithSignature(
            "transferOutFromExitLp(address,address,uint256,uint256)",
            _lpAddr,
            _recipientAddr,
            _assetId,
            _assetAmount - _feeAmount
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = tokenManagerLogicAddress.delegatecall(_data);
        _success.popupRevertReason();

        _pushL1ToL2FastWithdrawMessage(_lpAddr, _recipientAddr, uint32(_assetId), uint128(_assetAmount), _nonce);
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Internal function for updating pending withdraw.
    function _increasePendingWithdraw(address _account, uint256 _assetId, uint256 _amount) internal {
        uint256 _beforePendingAmount = pendingWithdraw[_account][_assetId];
        unchecked {
            pendingWithdraw[_account][_assetId] += _amount;
        }
        if (pendingWithdraw[_account][_assetId] < _beforePendingAmount) {
            revert PendingWithdraw_Overflow();
        }
        emit LogNewPendingWithdrawAmount(_account, _assetId, pendingWithdraw[_account][_assetId]);
    }

    /// @dev Verify SNARK proof can be accepted by verifier and instances matches the state preimage.
    function _verifySnarkProofAndStateHash(
        uint256[] calldata _instances,
        bytes calldata _proof,
        DataTypes.VesselState calldata _stateBefore,
        DataTypes.VesselState calldata _stateAfter
    )
        internal
        view
    {
        if (_instances.length != 14) {
            revert SNARKProof_InstanceLengthNotMatchSnarkProof(14, _instances.length);
        }
        if (uint256(calculateStateHash(_stateBefore)) % Constants.Q != _instances[12]) {
            revert SNARKProof_InstanceNotMatch_StateBefore(
                uint256(calculateStateHash(_stateBefore)) % Constants.Q,
                _instances[12]
            );
        }
        if (uint256(calculateStateHash(_stateAfter)) % Constants.Q != _instances[13]) {
            revert SNARKProof_InstanceNotMatch_StateAfter(
                uint256(calculateStateHash(_stateAfter)) % Constants.Q,
                _instances[13]
            );
        }
        if (!verifySnarkProof(_instances, _proof, snarkVerifier)) {
            revert SNARKProof_ProofRejectedByVerifier();
        }
    }

    function _updateMerkleTreeRoot(
        DataTypes.VesselState calldata _stateBefore,
        DataTypes.VesselState calldata _stateAfter
    )
        internal
    {
        if (eternalTreeRoot != _stateBefore.eternalTreeRoot ||
            ephemeralTreeRoot != _stateBefore.ephemeralTreeRoot)
        {
            revert SNARKProof_StateNotMatch_MerkleRoot();
        }
        _updateEternalTreeRoot(_stateAfter.eternalTreeRoot);
        _updateEphemeralTreeRoot(_stateAfter.ephemeralTreeRoot);
    }

    function _updateCheckPointAndSendConfirmation(
        DataTypes.VesselState calldata _stateBefore,
        DataTypes.VesselState calldata _stateAfter
    )
        internal
    {
        if (_stateBefore.l1MessageQueueHash.length != chainCnt ||
            _stateBefore.l2MessageQueueHash.length != chainCnt ||
            _stateAfter.l1MessageQueueHash.length != chainCnt ||
            _stateAfter.l2MessageQueueHash.length != chainCnt)
        {
            revert SNARKProof_StateNotMatch_MsgQueueCnt();
        }

        // update subChain checkpoint and send confirmation message
        uint256 _accFee = 0;
        for (uint32 _i = 0; _i < chainCnt; _i++) {
            DataTypes.PreCommitCheckpoint storage cp = preCommitCheckpointList[_i];

            if (cp.l1LastCommitHash != _stateBefore.l1MessageQueueHash[_i]) {
                revert SNARKProof_StateNotMatch_L1MsgQueueHashBefore();
            }
            if (cp.l1NextCommitHash != _stateAfter.l1MessageQueueHash[_i]) {
                revert SNARKProof_StateNotMatch_L1MsgQueueHashAfter();
            }
            if (cp.l2LastCommitHash != _stateBefore.l2MessageQueueHash[_i]) {
                revert SNARKProof_StateNotMatch_L2MsgQueueHashBefore();
            }

            // only send confirmation if necessry
            if (_stateBefore.l1MessageQueueHash[_i] != _stateAfter.l1MessageQueueHash[_i] ||
                _stateBefore.l2MessageQueueHash[_i] != _stateAfter.l2MessageQueueHash[_i])
            {
                DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
                    logicChainId: cp.logicChainId,
                    l1MessageCnt: cp.l1MessageCnt,
                    l1NextCommitHash:  _stateAfter.l1MessageQueueHash[_i],
                    l2NextCommitHash: _stateAfter.l2MessageQueueHash[_i]
                });

                // perform d-call to send PostCommitConfirmation to subChain
                bytes memory _data = abi.encodeWithSignature(
                    "sendMessageToSub((uint32,uint256,bytes32,bytes32))",
                    _c
                );
                // solhint-disable-next-line avoid-low-level-calls
                (bool _success, bytes memory _res) = multiChainLogicAddress.delegatecall(_data);
                _success.popupRevertReason();

                // accumulate fee spent on cross-chain msg
                uint256 _fee = abi.decode(_res, (uint256));
                _accFee += _fee;

                // update checkpoint to be committed
                cp.l1MessageCnt = 0;
                cp.l1LastCommitHash = _stateAfter.l1MessageQueueHash[_i];
                cp.l2LastCommitHash = _stateAfter.l2MessageQueueHash[_i];
            }
        }

        // refund excessive native fee
        _refundExcessiveMsgValue(_accFee);
    }

    /// @dev Add new fast-withdraw l1 message to l1->l2 message queue
    function _pushL1ToL2FastWithdrawMessage(
        address _lpAddr,
        address _recipientAddr,
        uint32 _assetId,
        uint128 _assetAmount,
        uint256 _nonce
    ) public {
        // Perform s-call to encode fastWithdraw-l1 msg
        bytes memory _data = abi.encodeWithSignature(
            "encodeFastWithdrawL1Message(bytes32,address,address,uint32,uint128,uint256)",
            l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex],
            _lpAddr,
            _recipientAddr,
            _assetId,
            _assetAmount,
            _nonce
        );
        (bool _success, bytes memory _returnData) = messageQueueLogicAddress.staticcall(_data);
        _success.popupRevertReason();

        bytes memory _newMessage = abi.decode(_returnData, (bytes));
        bytes32 _newHash = keccak256(_newMessage);
        l1ToL2MessageQueueTailIndex++;
        l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex] = _newHash;
        emit LogL1ToL2MessageQueueFastWithdraw(_lpAddr, _recipientAddr, _assetId, _assetAmount, _nonce, _newHash);
    }

    /// @dev refund msg.value to msg.sender based on actual usage
    function _refundExcessiveMsgValue(uint256 _actualFee) internal {
        if (_actualFee > msg.value) {
            revert MsgValueInsufficient(_actualFee, msg.value);
        } else if (_actualFee < msg.value) {
            uint256 _refundAmount = msg.value - _actualFee;
            Address.sendValue(payable(msg.sender), _refundAmount);
        }
    }

    /// @dev Update SNARK proof metadata.
    function _updateProofCommitmentMetadata(uint256 _batchId, uint256 _lastEventId) internal {
        lastCommitBatchId = _batchId;
        lastCommitEventId = _lastEventId;
        emit LogProofCommitted(lastCommitBatchId, lastCommitEventId);
    }

    /// @dev Only verified SNARK proof should update new root.
    function _updateEternalTreeRoot(uint256 _newEternalTreeRoot) internal {
        eternalTreeRoot = _newEternalTreeRoot;
        emit LogNewEternalTreeRoot(eternalTreeRoot);
    }

    /// @dev Only verified SNARK proof should update new root.
    function _updateEphemeralTreeRoot(uint256 _newEphemeralTreeRoot) internal {
        ephemeralTreeRoot = _newEphemeralTreeRoot;
        emit LogNewEphemeralTreeRoot(ephemeralTreeRoot);
    }

    /// @dev Update l1->l2 message queue with new index.
    /// Caller is responsible to perform relative checkes and make sure this update is legal.
    function updateL1ToL2MessageQueue(uint256 _newIndex) public {
        l1ToL2MessageQueueCommitIndex = _newIndex;
        emit LogL1ToL2MessageQueueUpdate(_newIndex);
    }

    /// @dev Update l2->l1 message queue with new hash. Messages are not stored in contract.
    /// Caller is responsible to perform relative checkes and make sure this update is legal.
    function updateL2ToL1MessageQueue(bytes32 _newHash) public {
        l2ToL1MessageQueueCommitHash = _newHash;
        emit LogL2ToL1MessageQueueUpdate(_newHash);
    }
}
