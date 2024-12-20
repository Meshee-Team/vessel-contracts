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

import { Storage } from "../generic/Storage.sol";

contract MessageQueueLogic is Storage {
    /**********
     * Errors *
     **********/
    error DepositMessage_WrongLen();
    error DepositMessage_WrongType();
    error RegisterMessage_VesselKeyWrongLen();
    error RegisterMessage_WrongLen();
    error RegisterMessage_WrongType();
    error FastWithdrawL1Message_WrongLen();
    error FastWithdrawL1Message_WrongType();
    error WithdrawMessage_WrongLen();
    error WithdrawMessage_WrongType();
    error AmmPoolCreateMessage_WrongLen();
    error AmmPoolCreateMessage_WrongType();
    error FastWithdrawL2Message_WrongLen();
    error FastWithdrawL2Message_WrongType();

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Encode l1->l2 deposit message by concatenating following:
    ///     - previous l1->l2 message queue hash (32 bytes)
    ///     - message type: 0 for deposit (1 byte)
    ///     - user address to deposit (20 bytes)
    ///     - asset id (4 bytes)
    ///     - deposit asset amount (16 bytes)
    function encodeDepositMessage(
        bytes32 _prevMessageQueueHash,
        address _userAddress,
        uint32 _assetId,
        uint128 _depositAmount
    )
        public
        pure
        returns (bytes memory _message)
    {
        _message = abi.encodePacked(_prevMessageQueueHash, bytes1(0), _userAddress, _assetId, _depositAmount);
    }

    function decodeDepositMessage(bytes calldata _message)
        public
        pure
        returns (bytes32 _prevMessageQueueHash, address _userAddress, uint32 _assetId, uint128 _depositAmount)
    {
        if (_message.length != 73) {
            revert DepositMessage_WrongLen();
        }
        if (_message[32] != 0) {
            revert DepositMessage_WrongType();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _prevMessageQueueHash := calldataload(_message.offset)
            _userAddress := shr(96, calldataload(add(_message.offset, 33))) // mask last 12 bytes
            _assetId := shr(224, calldataload(add(_message.offset, 53))) // mask last 28 bytes
            _depositAmount := shr(128, calldataload(add(_message.offset, 57))) // mask last 16 bytes
        }
    }
    
    /// @notice Encode l1->l2 register message by concatenating following:
    ///     - previous l1->l2 message queue hash (32 bytes)
    ///     - message type: 1 for register (1 byte)
    ///     - user address (20 bytes)
    ///     - user vessel public key (64 bytes)
    function encodeRegisterMessage(
        bytes32 _prevMessageQueueHash,
        address _userAddress,
        bytes calldata _vesselPubKey
    )
        public
        pure
        returns (bytes memory _message)
    {
        if (_vesselPubKey.length != 64) {
            revert RegisterMessage_VesselKeyWrongLen();
        }
        _message = abi.encodePacked(_prevMessageQueueHash, bytes1(uint8(1)), _userAddress, _vesselPubKey);
    }

    function decodeRegisterMessage(bytes calldata _message)
        public
        pure
        returns (bytes32 _prevMessageQueueHash, address _userAddress, bytes memory _vesselPubKey)
    {
        if (_message.length != 117) {
            revert RegisterMessage_WrongLen();
        }
        if (_message[32] != bytes1(uint8(1))) {
            revert RegisterMessage_WrongType();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _prevMessageQueueHash := calldataload(_message.offset)
            _userAddress := shr(96, calldataload(add(_message.offset, 33))) // mask last 12 bytes
            let _vesselPubKeyPart1 := calldataload(add(_message.offset, 53))
            let _vesselPubKeyPart2 := calldataload(add(_message.offset, 85))
            _vesselPubKey := mload(0x40) // allocate free memory
            mstore(_vesselPubKey, 64)
            mstore(add(_vesselPubKey, 32), _vesselPubKeyPart1)
            mstore(add(_vesselPubKey, 64), _vesselPubKeyPart2)
            mstore(0x40, add(_vesselPubKey, 96)) // move free memory pointer
        }
    }

    /// @notice Encode l1->l2 fast-withdraw message by concatenating following:
    ///     - previous l1->l2 message queue hash (32 bytes)
    ///     - message type: 2 for fast-withdraw (1 byte)
    ///     - liqudity provider address (20 bytes)
    ///     - recipient address (20 bytes)
    ///     - asset id (4 bytes)
    ///     - withdraw amount (16 bytes)
    ///     - nonce (32 bytes)    
    function encodeFastWithdrawL1Message(
        bytes32 _prevMessageQueueHash,
        address _lpAddr,
        address _recipientAddr,
        uint32 _assetId,
        uint128 _assetAmount,
        uint256 _nonce
    )
        public
        pure
        returns (bytes memory _message)
    {
        _message = abi.encodePacked(
            _prevMessageQueueHash,
            bytes1(uint8(2)),
            _lpAddr,
            _recipientAddr,
            _assetId,
            _assetAmount,
            _nonce
        );
    }

    function decodeFastWithdrawL1Message(bytes calldata _message)
        public
        pure
        returns (
            bytes32 _prevMessageQueueHash,
            address _lpAddr,
            address _recipientAddr,
            uint32 _assetId,
            uint128 _assetAmount,
            uint256 _nonce
        )
    {
        if (_message.length != 125) {
            revert FastWithdrawL1Message_WrongLen();
        }
        if (_message[32] != bytes1(uint8(2))) {
            revert FastWithdrawL1Message_WrongType();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _prevMessageQueueHash := calldataload(_message.offset)
            _lpAddr := shr(96, calldataload(add(_message.offset, 33))) // mask last 12 bytes
            _recipientAddr := shr(96, calldataload(add(_message.offset, 53))) // mask last 12 bytes
            _assetId := shr(224, calldataload(add(_message.offset, 73))) // mask last 28 bytes
            _assetAmount := shr(128, calldataload(add(_message.offset, 77))) // mask last 16 bytes
            _nonce := calldataload(add(_message.offset, 93))
        }
    }

    /// @notice Encode l2->l1 withdraw message by concatenating following:
    ///     - previous l2->l1 message queue hash (32 bytes)
    ///     - message type: 0 for withdraw (1 byte)
    ///     - user address to withdraw (20 bytes)
    ///     - withdraw asset id (4 bytes)
    ///     - withdraw asset amount (16 bytes)
    function encodeWithdrawMessage(
        bytes32 _prevMessageQueueHash,
        address _userAddress,
        uint32 _assetId,
        uint128 _assetAmount
    )
        public
        pure
        returns (bytes memory _message)
    {
        _message = abi.encodePacked(_prevMessageQueueHash, bytes1(0), _userAddress, _assetId, _assetAmount);
    }

    function decodeWithdrawMessage(bytes calldata _message)
        public
        pure
        returns (bytes32 _prevMessageQueueHash, address _userAddress, uint32 _assetId, uint128 _assetAmount)
    {
        if (_message.length != 73) {
            revert WithdrawMessage_WrongLen();
        }
        if (_message[32] != 0) {
            revert WithdrawMessage_WrongType();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _prevMessageQueueHash := calldataload(_message.offset)
            _userAddress := shr(96, calldataload(add(_message.offset, 33))) // mask last 12 bytes
            _assetId := shr(224, calldataload(add(_message.offset, 53))) // mask last 28 bytes
            _assetAmount := shr(128, calldataload(add(_message.offset, 57))) // mask last 16 bytes
        }
    }

    /// @dev Encode l2->l1 AMM pool create message by concatenating following:
    ///     - previous l2->l1 message queue hash (32 bytes)
    ///     - message type: 0 for withdraw (1 byte)
    ///     - AMM pool ID (4 byte)
    ///     - AMM pool base asset ID (4 byte)
    ///     - AMM pool quote asset ID (4 byte)
    ///     - AMM pool mininum tick price (16 byte)
    ///     - AMM pool tick price delta (16 byte)
    ///     - AMM pool total ticks (8 byte)
    ///     - AMM pool current tick index [0, totalTicks) (8 byte)
    function encodeAmmPoolCreateMessage(
        bytes32 _prevMessageQueueHash,
        uint32 _poolId,
        uint32 _baseAssetId,
        uint32 _quoteAssetId,
        uint128 _minPrice,
        uint128 _priceDelta,
        uint64 _totalTicks,
        uint64 _curTickIndex
    )
        public
        pure
        returns (bytes memory _message)
    {
        _message = abi.encodePacked(
            _prevMessageQueueHash,
            bytes1(uint8(1)),
            _poolId,
            _baseAssetId,
            _quoteAssetId,
            _minPrice,
            _priceDelta,
            _totalTicks,
            _curTickIndex
        );
    }

    function decodeAmmPoolCreateMessage(bytes calldata _message)
        public
        pure
        returns (
            bytes32 _prevMessageQueueHash,
            uint32 _poolId,
            uint32 _baseAssetId,
            uint32 _quoteAssetId,
            uint128 _minPrice,
            uint128 _priceDelta,
            uint64 _totalTicks,
            uint64 _curTickIndex
        )
    {
        if (_message.length != 93) {
            revert AmmPoolCreateMessage_WrongLen();
        }
        if (_message[32] != bytes1(uint8(1))) {
            revert AmmPoolCreateMessage_WrongType();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _prevMessageQueueHash := calldataload(_message.offset)
            _poolId := shr(224, calldataload(add(_message.offset, 33))) // mask last 28 bytes
            _baseAssetId := shr(224, calldataload(add(_message.offset, 37))) // mask last 28 bytes
            _quoteAssetId := shr(224, calldataload(add(_message.offset, 41))) // mask last 28 bytes
            _minPrice := shr(128, calldataload(add(_message.offset, 45))) // mask last 16 bytes
            _priceDelta := shr(128, calldataload(add(_message.offset, 61))) // mask last 16 bytes
            _totalTicks := shr(192, calldataload(add(_message.offset, 77))) // mask last 24 bytes
            _curTickIndex := shr(192, calldataload(add(_message.offset, 85))) // mask last 24 bytes
        }
    }

    /// @notice Encode l2->l1 fast-withdraw message by concatenating following:
    ///     - previous l2->l1 message queue hash (32 bytes)
    ///     - message type: 2 for fast-withdraw (1 byte)
    ///     - liquidity provider address to backfill (20 bytes)
    ///     - backfill asset id (4 bytes)
    ///     - backfill asset amount (16 bytes)
    function encodeFastWithdrawL2Message(
        bytes32 _prevMessageQueueHash,
        address _lpAddr,
        uint32 _assetId,
        uint128 _backfillAmount
    )
        public
        pure
        returns (bytes memory _message)
    {
        _message = abi.encodePacked(
            _prevMessageQueueHash,
            bytes1(uint8(2)),
            _lpAddr,
            _assetId,
            _backfillAmount
        );
    }

    function decodeFastWithdrawL2Message(bytes calldata _message)
        public
        pure
        returns (bytes32 _prevMessageQueueHash, address _lpAddr, uint32 _assetId, uint128 _backfillAmount)
    {
        if (_message.length != 73) {
            revert FastWithdrawL2Message_WrongLen();
        }
        if (_message[32] != bytes1(uint8(2))) {
            revert FastWithdrawL2Message_WrongType();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _prevMessageQueueHash := calldataload(_message.offset)
            _lpAddr := shr(96, calldataload(add(_message.offset, 33))) // mask last 12 bytes
            _assetId := shr(224, calldataload(add(_message.offset, 53))) // mask last 28 bytes
            _backfillAmount := shr(128, calldataload(add(_message.offset, 57))) // mask last 16 bytes
        }
    }
}
