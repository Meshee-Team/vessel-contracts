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
import { Storage } from "../generic/Storage.sol";

contract UserApiLogic is Storage {
    using Common for bool;

    /**********
     * Errors *
     **********/
    error PendingWithdrawUnderflow();
    error PendingWithdrawNotEnough();

    /**********
     * Events *
     **********/

    event LogWithdraw(address userAddress, uint256 assetId, uint256 amount);
    event LogNewPendingWithdrawAmount(address account, uint256 assetId, uint256 amount);
    event LogL1ToL2MessageQueueRegister(address userAddress, bytes vesselKey, bytes32 newHash);
    event LogL1ToL2MessageQueueDeposit(address userAddress, uint256 assetId, uint256 amount, bytes32 newHash);

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @dev Register vesselKey to userAddress.
    ///     "payable" because it may be called along with "deposit"
    function registerVesselKey(address _userAddress, bytes calldata _vesselKey) public payable {
        _pushL1ToL2RegisterMessage(_userAddress, _vesselKey);
    }

    /// @dev Deposit asset.
    function depositAsset(uint256 _assetId, uint256 _actualAmount) public payable {
        // Perform d-call to transfer into Vault
        bytes memory _data = abi.encodeWithSignature(
            "transferIn(uint256,uint256)",
            _assetId,
            _actualAmount
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = tokenManagerLogicAddress.delegatecall(_data);
        _success.popupRevertReason();

        _pushL1ToL2DepositMessage(msg.sender, uint32(_assetId), uint128(_actualAmount));
    }

    /// @dev Withdraw asset from claimable amount.
    function withdrawAsset(uint256 _assetId, uint256 _amount) public {
        // decrease claimable amount
        if (pendingWithdraw[msg.sender][_assetId] < _amount) {
            revert PendingWithdrawNotEnough();
        }
        pendingWithdraw[msg.sender][_assetId] -= _amount;
        emit LogNewPendingWithdrawAmount(msg.sender, _assetId, pendingWithdraw[msg.sender][_assetId]);

        // Perform d-call to transfer out Vault
        bytes memory _data = abi.encodeWithSignature(
            "transferOut(address,uint256,uint256)",
            msg.sender,
            _assetId,
            _amount
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = tokenManagerLogicAddress.delegatecall(_data);
        _success.popupRevertReason();

        emit LogWithdraw(msg.sender, _assetId, _amount);
    }

    /**********************
     * Internal Functions *
     **********************/

    function _pushL1ToL2RegisterMessage(
        address _userAddress,
        bytes calldata _vesselKey
    ) internal {
        // Perform s-call to encode register msg
        bytes memory _data = abi.encodeWithSignature(
            "encodeRegisterMessage(bytes32,address,bytes)",
            l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex],
            _userAddress,
            _vesselKey
        );
        (bool _success, bytes memory _returnData) = messageQueueLogicAddress.staticcall(_data);
        _success.popupRevertReason();

        bytes memory _newMessage = abi.decode(_returnData, (bytes));
        bytes32 _newHash = keccak256(_newMessage);
        l1ToL2MessageQueueTailIndex++;
        l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex] = _newHash;
        emit LogL1ToL2MessageQueueRegister(_userAddress, _vesselKey, _newHash);
    }

    /// @dev Add new deposit message to l1->l2 message queue.
    function _pushL1ToL2DepositMessage(
        address _userAddress,
        uint32 _assetId,
        uint128 _amount
    ) public {
        // Perform s-call to encode deposit msg
        bytes memory _data = abi.encodeWithSignature(
            "encodeDepositMessage(bytes32,address,uint32,uint128)",
            l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex],
            _userAddress,
            _assetId,
            _amount
        );
        (bool _success, bytes memory _returnData) = messageQueueLogicAddress.staticcall(_data);
        _success.popupRevertReason();

        bytes memory _newMessage = abi.decode(_returnData, (bytes));
        bytes32 _newHash = keccak256(_newMessage);
        l1ToL2MessageQueueTailIndex++;
        l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex] = _newHash;
        emit LogL1ToL2MessageQueueDeposit(_userAddress, _assetId, _amount, _newHash);
    }
}
