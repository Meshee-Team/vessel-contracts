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

import { TestBase } from "test/utils/TestBase.sol";
import { MessageQueueLogic } from "src/vault/logic/MessageQueueLogic.sol";

contract MessageQueueLogicTest is MessageQueueLogic, TestBase {
    function setUp() public virtual {}

    function test_encodeDepositMessage() public {
        bytes32 _prevMessageQueueHash = hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a273";
        address _userAddress = address(0x17aA9E82D538daA15E5aaDcdde5989615632Af6a);
        uint32 _assetId = 1;
        uint128 _amount = 8_000_000_000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730017aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd65000";

        assertEq(this.encodeDepositMessage(_prevMessageQueueHash, _userAddress, _assetId, _amount), _message);
    }

    function test_decodeDepositMessage() public {
        bytes32 _prevMessageQueueHash = hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a273";
        address _userAddress = address(0x17aA9E82D538daA15E5aaDcdde5989615632Af6a);
        uint32 _assetId = 1;
        uint128 _amount = 8_000_000_000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730017aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd65000";

        (bytes32 _r1, address _r3, uint256 _r4, uint256 _r5) = this.decodeDepositMessage(_message);
        assertEq(_prevMessageQueueHash, _r1);
        assertEq(_userAddress, _r3);
        assertEq(_assetId, _r4);
        assertEq(_amount, _r5);

        // wrong msg length should revert
        bytes memory _messageWrongLen =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730017aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd6500000";
        vm.expectRevert(DepositMessage_WrongLen.selector);
        this.decodeDepositMessage(_messageWrongLen);

        // wrong msg type byte should revert
        bytes memory _messageWrongType =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730117aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd65000";
        vm.expectRevert(DepositMessage_WrongType.selector);
        this.decodeDepositMessage(_messageWrongType);
    }

    function test_encodeRegisterMessage() public {
        bytes32 _prevMessageQueueHash = hex"8449503d56f64b62dfac841f8f52f248f6e78e7c6f45b8de0a6a5f64a373af0c";
        address _userAddress = address(0xa160C12722d06b0cfcD08D5f1CaeDd33E732B51d);
        bytes memory _vesselPubKey =
        // solhint-disable-next-line max-line-length
            hex"6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f6286638";
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"8449503d56f64b62dfac841f8f52f248f6e78e7c6f45b8de0a6a5f64a373af0c01a160c12722d06b0cfcd08d5f1caedd33e732b51d6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f6286638";

        assertEq(this.encodeRegisterMessage(_prevMessageQueueHash, _userAddress, _vesselPubKey), _message);
    }

    function test_decodeRegisterMessage() public {
        bytes32 _prevMessageQueueHash = hex"8449503d56f64b62dfac841f8f52f248f6e78e7c6f45b8de0a6a5f64a373af0c";
        address _userAddress = address(0xa160C12722d06b0cfcD08D5f1CaeDd33E732B51d);
        bytes memory _vesselPubKey =
        // solhint-disable-next-line max-line-length
            hex"6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f6286638";
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"8449503d56f64b62dfac841f8f52f248f6e78e7c6f45b8de0a6a5f64a373af0c01a160c12722d06b0cfcd08d5f1caedd33e732b51d6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f6286638";

        (bytes32 _r1, address _r3, bytes memory _r4) = this.decodeRegisterMessage(_message);
        assertEq(_prevMessageQueueHash, _r1);
        assertEq(_userAddress, _r3);
        assertEq(_vesselPubKey, _r4);

        // wrong msg length should revert
        bytes memory _messageWrongLen =
        // solhint-disable-next-line max-line-length
            hex"8449503d56f64b62dfac841f8f52f248f6e78e7c6f45b8de0a6a5f64a373af0c01a160c12722d06b0cfcd08d5f1caedd33e732b51d6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f628663800";
        vm.expectRevert(RegisterMessage_WrongLen.selector);
        this.decodeRegisterMessage(_messageWrongLen);

        // wrong msg type byte should revert
        bytes memory _messageWrongType =
        // solhint-disable-next-line max-line-length
            hex"8449503d56f64b62dfac841f8f52f248f6e78e7c6f45b8de0a6a5f64a373af0c02a160c12722d06b0cfcd08d5f1caedd33e732b51d6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f6286638";
        vm.expectRevert(RegisterMessage_WrongType.selector);
        this.decodeRegisterMessage(_messageWrongType);
    }

    function test_encodeFastWithdrawL1Message() public {
        bytes32 _prevMessageQueueHash = hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a273";
        address _lpAddress = address(0x17aA9E82D538daA15E5aaDcdde5989615632Af6a);
        address _recipientAddress = address(0xa160C12722d06b0cfcD08D5f1CaeDd33E732B51d);
        uint32 _assetId = 1;
        uint128 _assetAmount = 8_000_000_000;
        uint256 _nonce = 321;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730217aa9e82d538daa15e5aadcdde5989615632af6aa160c12722d06b0cfcd08d5f1caedd33e732b51d00000001000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000141";

        assertEq(
            this.encodeFastWithdrawL1Message(
                _prevMessageQueueHash,
                _lpAddress,
                _recipientAddress,
                _assetId,
                _assetAmount,
                _nonce
            ),
            _message
        );
    }

    function test_decodeFastWithdrawL1Message() public {
        bytes32 _prevMessageQueueHash = hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a273";
        address _lpAddress = address(0x17aA9E82D538daA15E5aaDcdde5989615632Af6a);
        address _recipientAddress = address(0xa160C12722d06b0cfcD08D5f1CaeDd33E732B51d);
        uint32 _assetId = 1;
        uint128 _assetAmount = 8_000_000_000;
        uint256 _nonce = 321;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730217aa9e82d538daa15e5aadcdde5989615632af6aa160c12722d06b0cfcd08d5f1caedd33e732b51d00000001000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000141";

        (bytes32 _r1, address _r3, address _r4, uint32 _r5, uint128 _r6, uint256 _r7) =
            this.decodeFastWithdrawL1Message(_message);
        assertEq(_prevMessageQueueHash, _r1);
        assertEq(_lpAddress, _r3);
        assertEq(_recipientAddress, _r4);
        assertEq(_assetId, _r5);
        assertEq(_assetAmount, _r6);
        assertEq(_nonce, _r7);

        // wrong msg length should revert
        bytes memory _messageWrongLen =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730217aa9e82d538daa15e5aadcdde5989615632af6aa160c12722d06b0cfcd08d5f1caedd33e732b51d00000001000000000000000000000001dcd65000000000000000000000000000000000000000000000000000000000000000014100";
        vm.expectRevert(FastWithdrawL1Message_WrongLen.selector);
        this.decodeFastWithdrawL1Message(_messageWrongLen);

        // wrong msg type byte should revert
        bytes memory _messageWrongType =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730317aa9e82d538daa15e5aadcdde5989615632af6aa160c12722d06b0cfcd08d5f1caedd33e732b51d00000001000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000141";
        vm.expectRevert(FastWithdrawL1Message_WrongType.selector);
        this.decodeFastWithdrawL1Message(_messageWrongType);
    }

    function test_encodeWithdrawMessage() public {
        bytes32 _prevMessageQueueHash = hex"4e10d4b281dc7457f58b831a6f6c1be8801041e4c15b193cdf57e565d959f457";
        address _userAddress = address(0xaECeDac11A8D59F9f5Ed269a8825f2371178A3eD);
        uint32 _assetId = 1;
        uint128 _amount = 4_000_000_000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"4e10d4b281dc7457f58b831a6f6c1be8801041e4c15b193cdf57e565d959f45700aecedac11a8d59f9f5ed269a8825f2371178a3ed00000001000000000000000000000000ee6b2800";

        assertEq(this.encodeWithdrawMessage(_prevMessageQueueHash, _userAddress, _assetId, _amount), _message);
    }

    function test_decodeWithdrawMessage() public {
        bytes32 _prevMessageQueueHash = hex"4e10d4b281dc7457f58b831a6f6c1be8801041e4c15b193cdf57e565d959f457";
        address _userAddress = address(0xaECeDac11A8D59F9f5Ed269a8825f2371178A3eD);
        uint32 _assetId = 1;
        uint128 _amount = 4_000_000_000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"4e10d4b281dc7457f58b831a6f6c1be8801041e4c15b193cdf57e565d959f45700aecedac11a8d59f9f5ed269a8825f2371178a3ed00000001000000000000000000000000ee6b2800";

        (bytes32 _r1, address _r3, uint32 _r4, uint128 _r5) =
            this.decodeWithdrawMessage(_message);
        assertEq(_prevMessageQueueHash, _r1);
        assertEq(_userAddress, _r3);
        assertEq(_assetId, _r4);
        assertEq(_amount, _r5);

        // wrong msg length should revert
        bytes memory _messageWrongLen =
        // solhint-disable-next-line max-line-length
            hex"4e10d4b281dc7457f58b831a6f6c1be8801041e4c15b193cdf57e565d959f45700aecedac11a8d59f9f5ed269a8825f2371178a3ed00000001000000000000000000000000ee6b280000";
        vm.expectRevert(WithdrawMessage_WrongLen.selector);
        this.decodeWithdrawMessage(_messageWrongLen);

        // wrong msg type byte should revert
        bytes memory _messageWrongType =
        // solhint-disable-next-line max-line-length
            hex"4e10d4b281dc7457f58b831a6f6c1be8801041e4c15b193cdf57e565d959f45701aecedac11a8d59f9f5ed269a8825f2371178a3ed00000001000000000000000000000000ee6b2800";
        vm.expectRevert(WithdrawMessage_WrongType.selector);
        this.decodeWithdrawMessage(_messageWrongType);
    }

    function test_encodeAmmPoolCreateMessage() public {
        bytes32 _prevMessageQueueHash = hex"0000000000000000000000000000000000000000000000000000000000000000";
        uint32 _poolId = 0;
        uint32 _baseAssetId = 0;
        uint32 _quoteAssetId = 1;
        uint128 _minPrice = 0;
        uint128 _priceDelta = 1_000_000_000_000_000_000;
        uint64 _totalTicks = 20_000;
        uint64 _curTick = 3000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"0000000000000000000000000000000000000000000000000000000000000000010000000000000000000000010000000000000000000000000000000000000000000000000de0b6b3a76400000000000000004e200000000000000bb8";

        assertEq(
            this.encodeAmmPoolCreateMessage(
                _prevMessageQueueHash,
                _poolId,
                _baseAssetId,
                _quoteAssetId,
                _minPrice,
                _priceDelta,
                _totalTicks,
                _curTick
            ),
            _message
        );
    }

    function test_decodeAmmPoolCreateMessage() public {
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"0000000000000000000000000000000000000000000000000000000000000000010000000000000000000000010000000000000000000000000000000000000000000000000de0b6b3a76400000000000000004e200000000000000bb8";

        (bytes32 _r1, uint32 _r3, uint32 _r4, uint32 _r5, uint128 _r6, uint128 _r7, uint64 _r8, uint64 _r9) =
            this.decodeAmmPoolCreateMessage(_message);
        assertEq(hex"0000000000000000000000000000000000000000000000000000000000000000", _r1);
        assertEq(0, _r3);
        assertEq(0, _r4);
        assertEq(1, _r5);
        assertEq(0, _r6);
        assertEq(1_000_000_000_000_000_000, _r7);
        assertEq(20_000, _r8);
        assertEq(3000, _r9);

        // wrong msg length should revert
        bytes memory _messageWrongLen =
        // solhint-disable-next-line max-line-length
            hex"0000000000000000000000000000000000000000000000000000000000000000010000000000000000000000010000000000000000000000000000000000000000000000000de0b6b3a76400000000000000004e200000000000000bb800";
        vm.expectRevert(AmmPoolCreateMessage_WrongLen.selector);
        this.decodeAmmPoolCreateMessage(_messageWrongLen);

        // wrong msg type byte should revert
        bytes memory _messageWrongType =
        // solhint-disable-next-line max-line-length
            hex"0000000000000000000000000000000000000000000000000000000000000000020000000000000000000000010000000000000000000000000000000000000000000000000de0b6b3a76400000000000000004e200000000000000bb8";
        vm.expectRevert(AmmPoolCreateMessage_WrongType.selector);
        this.decodeAmmPoolCreateMessage(_messageWrongType);
    }

    function test_encodeFastWithdrawL2Message() public {
        bytes32 _prevMessageQueueHash = hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a273";
        address _lpAddress = address(0x17aA9E82D538daA15E5aaDcdde5989615632Af6a);
        uint32 _assetId = 1;
        uint128 _backfillAmount = 8_000_000_000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730217aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd65000";

        assertEq(
            this.encodeFastWithdrawL2Message(_prevMessageQueueHash, _lpAddress, _assetId, _backfillAmount),
            _message
        );
    }

    function test_decodeFastWithdrawL2Message() public {
        bytes32 _prevMessageQueueHash = hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a273";
        address _lpAddress = address(0x17aA9E82D538daA15E5aaDcdde5989615632Af6a);
        uint32 _assetId = 1;
        uint128 _backfillAmount = 8_000_000_000;
        bytes memory _message =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730217aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd65000";

        (bytes32 _r1, address _r3, uint32 _r4, uint128 _r5) = this.decodeFastWithdrawL2Message(_message);
        assertEq(_prevMessageQueueHash, _r1);
        assertEq(_lpAddress, _r3);
        assertEq(_assetId, _r4);
        assertEq(_backfillAmount, _r5);

        // wrong msg length should revert
        bytes memory _messageWrongLen =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730217aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd650";
        vm.expectRevert(FastWithdrawL2Message_WrongLen.selector);
        this.decodeFastWithdrawL2Message(_messageWrongLen);

        // wrong msg type byte should revert
        bytes memory _messageWrongType =
        // solhint-disable-next-line max-line-length
            hex"ca3ba2a1118ea48332addfddc01437a9bcdccec08acdc548e9238c805cc7a2730317aa9e82d538daa15e5aadcdde5989615632af6a00000001000000000000000000000001dcd65000";
        vm.expectRevert(FastWithdrawL2Message_WrongType.selector);
        this.decodeFastWithdrawL2Message(_messageWrongType);
    }
}