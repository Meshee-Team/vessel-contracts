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
import { UserApiLogic } from "src/vault/logic/UserApiLogic.sol";
import { TokenManagerLogic } from "src/vault/logic/TokenManagerLogic.sol";
import { DataTypes } from "src/vault/generic/DataTypes.sol";
import { Token } from "src/misc/Token.sol";

contract UserApiLogicTest is UserApiLogic, TestBase {
    address internal user = address(100);
    Token internal testToken;

    function setUp() public virtual {
        testToken = new Token(user, 10 ** 18, 12, "Token12", "T12");

        assetIdToInfo[NATIVE_ASSET_ID] = DataTypes.AssetInfo({
            assetAddress: address(0),
            limitDigit: 10,
            precisionDigit: 8,
            decimals: 18,
            isActive: true
        });
        assetIdToInfo[ERC20_ASSET_ID] = DataTypes.AssetInfo({
            assetAddress: address(testToken),
            limitDigit: 10,
            precisionDigit: 8,
            decimals: 12,
            isActive: true
        });
        assetAddressToId[address(0)] = NATIVE_ASSET_ID;
        assetAddressToId[address(testToken)] = ERC20_ASSET_ID;

        MessageQueueLogic _messageQueueLogic = new MessageQueueLogic();
        messageQueueLogicAddress = address(_messageQueueLogic);
        TokenManagerLogic _tokenManagerLogic = new TokenManagerLogic();
        tokenManagerLogicAddress = address(_tokenManagerLogic);
    }

    function test_registerVesselKey() public {
        bytes memory _vesselKey =
        // solhint-disable-next-line max-line-length
            hex"6466d378c9f5cf0332352cd8866f8537cb4acc5deeb31c35422b23c69d11e232123703e60915149994c085946b83f7bf821915d781660bab49a7f2d3f6286638";
        
        // only check emit but not hash calculation
        vm.expectEmit(true, true, false, false);
        emit LogL1ToL2MessageQueueRegister(user, _vesselKey, bytes32(0));
        this.registerVesselKey(user, _vesselKey);

        assertEq(l1ToL2MessageQueueTailIndex, 1);
    }

    function test_depositAsset() public {
        uint256 _assetId = ERC20_ASSET_ID;
        uint256 _amount = 123456;

        vm.startPrank(user);
        testToken.approve(address(this), _amount);

        // only check emit but not hash calculation
        vm.expectEmit();
        emit TokenManagerLogic.LogVesselAssetTransfer(user, address(this), _assetId, _amount);
        vm.expectEmit(true, true, true, false);
        emit LogL1ToL2MessageQueueDeposit(user, _assetId, _amount, bytes32(0));
        this.depositAsset(_assetId, _amount);

        assertEq(l1ToL2MessageQueueTailIndex, 1);
        vm.stopPrank();
    }

    function test_withdrawAsset() public {
        uint256 _assetId = NATIVE_ASSET_ID;
        uint256 _pendingAmount = 789012;
        uint256 _withdrawAmount = 123456;
        pendingWithdraw[user][_assetId] = _pendingAmount;

        vm.startPrank(user);
        vm.expectEmit();
        emit LogNewPendingWithdrawAmount(user, NATIVE_ASSET_ID, _pendingAmount - _withdrawAmount);
        vm.expectEmit();
        emit TokenManagerLogic.LogVesselAssetTransfer(address(this), user, _assetId, _withdrawAmount);
        vm.expectEmit();
        emit LogWithdraw(user, _assetId, _withdrawAmount);
        this.withdrawAsset(_assetId, _withdrawAmount);
        vm.stopPrank();
    }
}