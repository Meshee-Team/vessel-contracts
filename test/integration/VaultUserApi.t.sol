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

import { IntegrationBase } from "test/integration/IntegrationBase.t.sol";
import { Configuration } from "src/vault/Configuration.sol";
import { Vault } from "src/vault/Vault.sol";
import { TokenManager } from "src/vault/TokenManager.sol";
import { UserApiLogic } from "src/vault/logic/UserApiLogic.sol";

contract VaultUserApi is IntegrationBase {
    function setUp() public virtual {
        deployAndConfigureAll();
    }

    function test_configure() public {
        vm.prank(admin);
        vaults[0].setConfigured(false);

        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].registerUser(hex"", address(0), 0, 0, 0);
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].depositERC20(0, 0);
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].depositNative();
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].withdraw(0, 0);
    }

    function _registerTestUser(uint32 _vaultId, uint32 _userId) internal {
        address _userAddr = users[_userId];
        bytes memory _vesselKey = vesselKeys[_userId];
        bytes32 _sigR = bytes32(slice(registerSigs[_userId], 0, 32));
        bytes32 _sigS = bytes32(slice(registerSigs[_userId], 32, 64));
        uint8 _sigV = uint8(registerSigs[_userId][64]);

        vm.expectEmit(true, true, false, false);
        emit UserApiLogic.LogL1ToL2MessageQueueRegister(_userAddr, _vesselKey, bytes32(0));
        vm.prank(_userAddr);
        vaults[_vaultId].registerUser(_vesselKey, operator, _sigV, _sigR, _sigS);
    }

    function test_registerUser() public {
        _registerTestUser(0, 0);
    }

    function test_registerUser_expectRevert() public {
        address _userAddr = users[0];
        bytes memory _vesselKey = vesselKeys[0];
        bytes32 _sigR = bytes32(slice(registerSigs[0], 0, 32));
        bytes32 _sigS = bytes32(slice(registerSigs[0], 32, 64));
        uint8 _sigV = uint8(registerSigs[0][64]);

        vm.startPrank(_userAddr);
        // case #1: InvalidVesselKeyLength
        vm.expectRevert(Vault.InvalidVesselKeyLength.selector);
        vaults[0].registerUser(hex"123456", operator, _sigV, _sigR, _sigS);

        // case #2: InvalidOperatorSignature
        vm.expectRevert(Vault.InvalidRegisterSignature.selector);
        vaults[0].registerUser(_vesselKey, operator, 27, _sigR, _sigS);
        vm.stopPrank();
    }

    function test_depositERC20() public {
        _registerTestUser(0, 0);
        uint256 _amount = 123_000_000;

        vm.startPrank(users[0]);
        testToken.mint(_amount);
        testToken.approve(address(vaults[0]), _amount);
        vm.expectEmit(true, true, true, false);
        emit UserApiLogic.LogL1ToL2MessageQueueDeposit(users[0], ERC20_ASSET_ID, _amount, bytes32(0));
        vaults[0].depositERC20(ERC20_ASSET_ID, _amount);
        vm.stopPrank();
    }

    function test_depositERC20_constrainPrecision() public {
        _registerTestUser(0, 0);
        uint256 _amount = 123_456_789;
        uint256 _actualAmount = 123_000_000;

        vm.startPrank(users[0]);
        testToken.mint(_amount);
        testToken.approve(address(vaults[0]), _amount);
        uint256 _userBalanceBefore = testToken.balanceOf(users[0]);
        vm.expectEmit(true, true, true, false);
        emit UserApiLogic.LogL1ToL2MessageQueueDeposit(users[0], ERC20_ASSET_ID, _actualAmount, bytes32(0));
        vaults[0].depositERC20(ERC20_ASSET_ID, _amount);
        assertEq(_userBalanceBefore - _actualAmount, testToken.balanceOf(users[0]));
        vm.stopPrank();
    }

    function test_depositERC20_expectRevert() public {
        _registerTestUser(0, 0);
        uint256 _amount = 123_000_000;

        vm.startPrank(users[0]);
        testToken.mint(_amount);
        testToken.approve(address(vaults[0]), _amount);
        // case #1: InvalidAssetType
        vm.expectRevert(Vault.InvalidAssetType.selector);
        vaults[0].depositERC20(NATIVE_ASSET_ID, _amount);

        // case #2: assetInActive
        vm.expectRevert(TokenManager.TokenManager_AssetInactive.selector);
        vaults[0].depositERC20(2, _amount);
        vm.stopPrank();
    }

    function test_depositNative() public {
        _registerTestUser(0, 0);
        uint256 _amount = 120_000_000_000;

        vm.startPrank(users[0]);
        vm.deal(users[0], _amount);
        vm.expectEmit(true, true, true, false);
        emit UserApiLogic.LogL1ToL2MessageQueueDeposit(users[0], NATIVE_ASSET_ID, _amount, bytes32(0));
        vaults[0].depositNative{value: _amount}();
        vm.stopPrank();
    }

    function test_depositNative_constrainPrecision() public {
        _registerTestUser(0, 0);
        uint256 _amount = 123_456_789_123;
        uint256 _actualAmount = 120_000_000_000;

        vm.startPrank(users[0]);
        vm.deal(users[0], _amount);
        uint256 _userBalanceBefore = users[0].balance;
        vm.expectEmit(true, true, true, false);
        emit UserApiLogic.LogL1ToL2MessageQueueDeposit(users[0], NATIVE_ASSET_ID, _actualAmount, bytes32(0));
        vaults[0].depositNative{value: _amount}();
        assertEq(_userBalanceBefore - _actualAmount, users[0].balance);
        vm.stopPrank();
    }

    function test_depositNative_expectRevert() public {
        _registerTestUser(0, 0);
        uint256 _amount = 120_000_000_000;

        // set ETH inactive
        vm.prank(operator);
        vaults[0].setAssetInactive(0);

        vm.startPrank(users[0]);
        vm.deal(users[0], _amount);
        // case #1: assetInActive
        vm.expectRevert(TokenManager.TokenManager_AssetInactive.selector);
        vaults[0].depositNative{value: _amount}();
        vm.stopPrank();
    }

    function test_withdraw() public {
        uint256 _amount = 123_456;
        setPendingWithdraw(address(vaults[0]), NATIVE_ASSET_ID, users[0], _amount);

        vm.startPrank(users[0]);
        vm.deal(address(vaults[0]), _amount);
        vm.expectEmit();
        emit UserApiLogic.LogWithdraw(users[0], NATIVE_ASSET_ID, _amount);
        vaults[0].withdraw(NATIVE_ASSET_ID, _amount);
        vm.stopPrank();
    }

    function test_registerAndDepositERC20() public {
        address _userAddr = users[0];
        bytes memory _vesselKey = vesselKeys[0];
        bytes32 _sigR = bytes32(slice(registerSigs[0], 0, 32));
        bytes32 _sigS = bytes32(slice(registerSigs[0], 32, 64));
        uint8 _sigV = uint8(registerSigs[0][64]);
        uint256 _amount = 123_000_000;

        vm.startPrank(users[0]);
        testToken.mint(_amount);
        testToken.approve(address(vaults[0]), _amount);
        vm.expectEmit(true, true, false, false);
        emit UserApiLogic.LogL1ToL2MessageQueueRegister(_userAddr, _vesselKey, bytes32(0));
        vm.expectEmit(true, true, true, false);
        emit UserApiLogic.LogL1ToL2MessageQueueDeposit(users[0], ERC20_ASSET_ID, _amount, bytes32(0));
        vaults[0].registerAndDepositERC20(
            _vesselKey,
            operator,
            _sigV,
            _sigR,
            _sigS,
            ERC20_ASSET_ID,
            _amount
        );
        vm.stopPrank();
    }

    function test_registerAndDepositNative() public {
        address _userAddr = users[0];
        bytes memory _vesselKey = vesselKeys[0];
        bytes32 _sigR = bytes32(slice(registerSigs[0], 0, 32));
        bytes32 _sigS = bytes32(slice(registerSigs[0], 32, 64));
        uint8 _sigV = uint8(registerSigs[0][64]);
        uint256 _amount = 120_000_000_000;

        vm.startPrank(users[0]);
        vm.deal(users[0], _amount);
        vm.expectEmit(true, true, false, false);
        emit UserApiLogic.LogL1ToL2MessageQueueRegister(_userAddr, _vesselKey, bytes32(0));
        vm.expectEmit(true, true, true, false);
        emit UserApiLogic.LogL1ToL2MessageQueueDeposit(users[0], NATIVE_ASSET_ID, _amount, bytes32(0));
        vaults[0].registerAndDepositNative{value: _amount}(
            _vesselKey,
            operator,
            _sigV,
            _sigR,
            _sigS
        );
        vm.stopPrank();
    }
}