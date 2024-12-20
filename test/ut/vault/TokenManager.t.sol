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
import { Governance } from "src/vault/Governance.sol";
import { TokenManager } from "src/vault/TokenManager.sol";

contract TokenManagerTest is TokenManager, TestBase {
    address internal adminAddr = address(1);
    address internal operatorAddr = address(2);
    address internal assetAddr1 = address(3);
    address internal assetAddr2 = address(4);

    function setUp() public virtual {
        initTokenManager();
        operators[operatorAddr] = true;
    }

    function testRegisterNewAsset() public {
        vm.prank(operatorAddr);
        this.registerNewAsset(assetAddr1, 2, 12, 6, 18);
        assertEq(assetAddressToId[assetAddr1], 2);
        (address assetAddress, uint8 limitDigit, uint8 precisionDigit, uint8 decimals, bool isActive) =
            this.getAssetInfo(2);
        assertEq(assetAddr1, assetAddress);
        assertEq(12, limitDigit);
        assertEq(6, precisionDigit);
        assertEq(18, decimals);
        assertEq(false, isActive);
    }

    function testRegisterNewAsset_expectRevert_duplicated() public {
        vm.prank(operatorAddr);
        this.registerNewAsset(assetAddr1, 2, 12, 6, 18);

        vm.prank(operatorAddr);
        vm.expectRevert(TokenManager.TokenManager_AssetAlreadyRegistered.selector);
        this.registerNewAsset(assetAddr1, 3, 12, 6, 18);

        vm.prank(operatorAddr);
        vm.expectRevert(TokenManager.TokenManager_AssetIdAlreadyUsed.selector);
        this.registerNewAsset(assetAddr2, 2, 12, 6, 18);
    }

    function testRegisterNewAsset_expectRevert_assetIdOverflow() public {
        uint256 overflowAssetId = uint256(0xFFFFFFFF) + 1;
        vm.prank(operatorAddr);
        vm.expectRevert(TokenManager.TokenManager_AssetIdTooBig.selector);
        this.registerNewAsset(assetAddr1, overflowAssetId, 12, 6, 18);
    }

    function testRegisterNewAsset_expectRevert_notAuthorized() public {
        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        this.registerNewAsset(assetAddr1, 2, 12, 6, 18);
    }

    function testRegisterNewAsset_expectRevert_precisionDigitTooBig() public {
        vm.startPrank(operatorAddr);
        vm.expectRevert(TokenManager.TokenManager_AssetPrecisionTooBig.selector);
        this.registerNewAsset(assetAddr1, 2, 12, 14, 13);
        this.registerNewAsset(assetAddr1, 2, 12, 10, 13);
        vm.expectRevert(TokenManager.TokenManager_AssetPrecisionTooBig.selector);
        this.updateAssetLimitAndPrecision(2, 12, 14);
        vm.stopPrank();
    }

    function testConstrainAmountWithPrecision() public {
        uint256 amount = 1_123_456_789; // 1.123456789 * 1e9
        vm.prank(operatorAddr);
        this.registerNewAsset(assetAddr1, 1, 12, 6, 9);
        assertEq(constrainAmountWithPrecision(1, amount), 1_123_456_000);

        vm.prank(operatorAddr);
        this.updateAssetLimitAndPrecision(1, 12, 0);
        assertEq(constrainAmountWithPrecision(1, amount), 1_000_000_000);
        assertEq(constrainAmountWithPrecision(1, 123_456_789), 0);
    }

    function testUpdateAsset() public {
        vm.prank(operatorAddr);
        this.updateAssetLimitAndPrecision(0, 13, 5);
        (address assetAddress, uint8 limitDigit, uint8 precisionDigit, uint8 decimals, bool isActive) =
            this.getAssetInfo(0);
        assertEq(address(0), assetAddress);
        assertEq(13, limitDigit);
        assertEq(5, precisionDigit);
        assertEq(18, decimals);
        assertEq(false, isActive);

        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        this.updateAssetLimitAndPrecision(0, 14, 4);
    }

    function testNativeToken() public {
        // check native token is self-registered
        assertEq(assetAddressToId[address(0)], 0);
        (address assetAddress, uint8 limitDigit, uint8 precisionDigit, uint8 decimals, bool isActive) =
            this.getAssetInfo(0);
        assertEq(address(0), assetAddress);
        assertEq(10, limitDigit);
        assertEq(8, precisionDigit);
        assertEq(18, decimals);
        assertEq(false, isActive);

        // register native token expects to fail
        vm.prank(operatorAddr);
        vm.expectRevert(TokenManager.TokenManager_AssetIdZeroIsSetToNativeToken.selector);
        this.registerNewAsset(address(0), 1, 10, 8, 18);

        vm.prank(operatorAddr);
        vm.expectRevert(TokenManager.TokenManager_AssetIdZeroIsSetToNativeToken.selector);
        this.registerNewAsset(assetAddr1, 0, 10, 8, 18);
    }

    function testSetAssetActive() public {
        (,,,, bool isActive) = getAssetInfo(0);
        assertTrue(isActive == false);

        vm.prank(operatorAddr);
        this.setAssetActive(0);
        (,,,, isActive) = getAssetInfo(0);
        assertTrue(isActive == true);

        vm.prank(operatorAddr);
        this.setAssetInactive(0);
        (,,,, isActive) = getAssetInfo(0);
        assertTrue(isActive == false);
    }

    function testSetAssetActive_expectRevert_notAuthorized() public {
        admin = adminAddr;

        vm.prank(admin);
        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        this.setAssetActive(0);

        vm.prank(admin);
        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        this.setAssetInactive(0);
    }
}
