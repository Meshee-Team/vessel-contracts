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

import { Common } from "../generic/Common.sol";
import { DataTypes } from "../generic/DataTypes.sol";
import { Storage } from "../generic/Storage.sol";

contract MultiChainLogic is Storage {
    using Common for bool;

    /**********
     * Errors *
     **********/
    error Multi_InvalidCheckpoint();
    error Multi_InvalidConfirmation();
    error Multi_InvalidLogicChainId();
    error Multi_InvalidMessageOrigin();

    /**********
     * Events *
     **********/
    event LogPreCommitCheckpointSent(
        uint256 logicChainId,
        uint256 l1MessageCnt,
        bytes32 l1LastCommitHash,
        bytes32 l1NextCommitHash,
        bytes32 l2LastCommitHash
    );
    event LogPreCommitCheckpointReceived(
        uint256 logicChainId,
        uint256 l1MessageCnt,
        bytes32 l1LastCommitHash,
        bytes32 l1NextCommitHash,
        bytes32 l2LastCommitHash
    );
    event LogPostCommitConfirmationSent(
        uint32 logicChainId,
        uint256 l1MessageCnt,
        bytes32 l1NextCommitHash,
        bytes32 l2NextCommitHash
    );
    event LogPostCommitConfirmationReceived(
        uint32 logicChainId,
        uint256 l1MessageCnt,
        bytes32 l1NextCommitHash,
        bytes32 l2NextCommitHash
    );

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @dev send L1MessageQueueCheckpoint to primary chain. Return the actual gas paied for cross-chain msg.
    function sendMessageToPrimary(DataTypes.PreCommitCheckpoint memory _cp)
        public
        payable
        returns (uint256 _msgValueUsed)
    {
        emit LogPreCommitCheckpointSent(
            _cp.logicChainId,
            _cp.l1MessageCnt,
            _cp.l1LastCommitHash,
            _cp.l1NextCommitHash,
            _cp.l2LastCommitHash
        );
        
        if (logicChainId == primaryLogicChainId) {
            // directly call receive function.
            _receiveMessageFromSub(_cp);
            return 0;
        } else {
            // send cross-chain message
            return _sendMessageToPrimaryCrossChain(_cp);
        }
    }

    /// @dev send MessageQueueConfirmation to subsidiary chain. Return the actual gas paied for cross-chain msg.
    function sendMessageToSub(DataTypes.PostCommitConfirmation memory _c)
        public
        payable
        returns (uint256 _msgValueUsed)
    {
        emit LogPostCommitConfirmationSent(
            _c.logicChainId,
            _c.l1MessageCnt,
            _c.l1NextCommitHash,
            _c.l2NextCommitHash
        );
        
        if (logicChainId == _c.logicChainId) {
            // directly call receive function
            _receiveMessageFromPrimary(_c);
            return 0;
        } else {
            // send cross-chain message
            return _sendMessageToSubCrossChain(_c);
        }
    }

    function receiveMessage(uint32 _srcLogicChainId, bytes calldata _payload) public {
        if (logicChainId == primaryLogicChainId) {
            // decode PreCommitCheckpoint message
            (
                uint32 _logicChainId,
                uint256 _l1MessageCnt,
                bytes32 _l1LastCommitHash,
                bytes32 _l1NextCommitHash,
                bytes32 _l2LastCommitHash
            ) = abi.decode(_payload, (uint32, uint256, bytes32, bytes32, bytes32));

            if (_srcLogicChainId != _logicChainId) {
                revert Multi_InvalidMessageOrigin();
            }

            DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
                logicChainId: _logicChainId,
                l1MessageCnt: _l1MessageCnt,
                l1LastCommitHash: _l1LastCommitHash,
                l1NextCommitHash: _l1NextCommitHash,
                l2LastCommitHash: _l2LastCommitHash
            });
            _receiveMessageFromSub(_cp);
        } else {
            // decode MessageQueueConfirmation message
            (
                uint32 _logicChainId,
                uint256 _l1MessageCnt,
                bytes32 _l1NextCommitHash,
                bytes32 _l2NextCommitHash
            ) = abi.decode(_payload, (uint32, uint256, bytes32, bytes32));

            if (_srcLogicChainId != primaryLogicChainId) {
                revert Multi_InvalidMessageOrigin();
            }

            DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
                logicChainId: _logicChainId,
                l1MessageCnt: _l1MessageCnt,
                l1NextCommitHash: _l1NextCommitHash,
                l2NextCommitHash: _l2NextCommitHash
            });
            _receiveMessageFromPrimary(_c);
        }
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev send L1 message queue progress to primary chain through LayerZero protocol.
    function _sendMessageToPrimaryCrossChain(DataTypes.PreCommitCheckpoint memory _cp)
        internal
        returns (uint256 _msgValue)
    {
        bytes memory _payload = abi.encode(_cp);
        return _lzSend(primaryLogicChainId, _payload);
    }

    /// @dev send mq confirmation to subsidiary chain through LayerZero protocol.
    function _sendMessageToSubCrossChain(DataTypes.PostCommitConfirmation memory _c)
        internal
        returns (uint256 _msgValue)
    {
        bytes memory _payload = abi.encode(_c);
        return _lzSend(_c.logicChainId, _payload);
    }

    /// @dev send cross-chain message and returns the actual fee paid
    function _lzSend(uint32 _dstLogicChainId, bytes memory _payload) internal returns (uint256 _msgValueUsed) {
        // quote cross-chain msg fee
        _msgValueUsed = crossChainPortalContract.quote(_dstLogicChainId, _payload);

        // send cross-chain message, refund excess gas to tx sender
        crossChainPortalContract.sendMessageCrossChain{value: _msgValueUsed}(
            _dstLogicChainId,
            _payload,
            payable(msg.sender)
        );
    }

    /// @dev receive PreCommitCheckpoint from subsidiary chain.
    function _receiveMessageFromSub(DataTypes.PreCommitCheckpoint memory _cp) internal {
        // check whether there is a pending checkpoint (overwrite is okay as long as lastCommitHash stays consistent)
        DataTypes.PreCommitCheckpoint storage currentCp = preCommitCheckpointList[_cp.logicChainId];
        if (currentCp.l1LastCommitHash != _cp.l1LastCommitHash || currentCp.l2LastCommitHash != _cp.l2LastCommitHash)
        {
            revert Multi_InvalidCheckpoint();
        }

        currentCp.logicChainId = _cp.logicChainId;
        currentCp.l1MessageCnt = _cp.l1MessageCnt;
        currentCp.l1NextCommitHash = _cp.l1NextCommitHash;
        emit LogPreCommitCheckpointReceived(
            _cp.logicChainId,
            _cp.l1MessageCnt,
            _cp.l1LastCommitHash,
            _cp.l1NextCommitHash,
            _cp.l2LastCommitHash
        );
    }

    /// @dev receive PostCommitConfirmation from primary chain.
    function _receiveMessageFromPrimary(DataTypes.PostCommitConfirmation memory _c) internal {
        if (_c.logicChainId != logicChainId) {
            revert Multi_InvalidLogicChainId();
        }

        // check whether there is a pending confirmation
        DataTypes.PostCommitConfirmation storage currentC = postCommitConfirmation;
        if (currentC.l1MessageCnt != 0 || currentC.l2NextCommitHash != l2ToL1MessageQueueCommitHash)
        {
            revert Multi_InvalidConfirmation();
        }

        currentC.logicChainId = _c.logicChainId;
        currentC.l1MessageCnt = _c.l1MessageCnt;
        currentC.l1NextCommitHash = _c.l1NextCommitHash;
        currentC.l2NextCommitHash = _c.l2NextCommitHash;
        emit LogPostCommitConfirmationReceived(
            _c.logicChainId,
            _c.l1MessageCnt,
            _c.l1NextCommitHash,
            _c.l2NextCommitHash
        );
    }
}
