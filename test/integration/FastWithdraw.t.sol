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

import { stdError } from "forge-std/StdError.sol";
import { IntegrationBase } from "test/integration/IntegrationBase.t.sol";
import { ManagerApiLogic } from "src/vault/logic/ManagerApiLogic.sol";
import { Vault } from "src/vault/Vault.sol";
import { Governance } from "src/vault/Governance.sol";
import { TokenManager } from "src/vault/TokenManager.sol";

contract FastWithdrawTest is IntegrationBase {
    function setUp() public virtual {
        deployAndConfigureAll();
    }

    function test_fastWithdraw_ERC20() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"4868b210db04ea6787a2f6e6a0956a0c7a12365c72ea317b62d3dfea7e073dc8";
        bytes32 _sigS = hex"1bdd8a6fd5e27895db846753bcb8fa93671659aa7773f04312062896cda74fac";
        uint8 _sigV = 28;

        // exitLp approve ERC20 allowance to vault proxy
        vm.startPrank(lp);
        testToken.mint(_assetAmount);
        testToken.approve(address(vaults[0]), _assetAmount);
        vm.stopPrank();

        // set block timestamp to fit expiration timestamp
        vm.warp(_expireTimestamp);

        // calculate expect l1->l2 msgQueue tail
        bytes32 l1Tol2TailHash = keccak256(messageQueueLogic.encodeFastWithdrawL1Message(
            0,
            lp,
            _recipient,
            uint32(ERC20_ASSET_ID),
            uint128(_assetAmount),
            _nonce
        ));

        // expect l1->l2 message quueue update and log emit
        vm.expectEmit();
        emit ManagerApiLogic.LogL1ToL2MessageQueueFastWithdraw(
            lp,
            _recipient,
            ERC20_ASSET_ID,
            _assetAmount,
            _nonce,
            l1Tol2TailHash
        );

        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
    }

    function test_fastWithdraw_ERC20_expectFail_timestampExpired() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"4868b210db04ea6787a2f6e6a0956a0c7a12365c72ea317b62d3dfea7e073dc8";
        bytes32 _sigS = hex"1bdd8a6fd5e27895db846753bcb8fa93671659aa7773f04312062896cda74fac";
        uint8 _sigV = 28;

        // set block timestamp to expired
        vm.warp(1_730_101_999);

        vm.expectRevert(Governance.Gov_CallerNotExitManager.selector);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
 
        vm.expectRevert(Vault.FastWithdraw_RequestExpired.selector);
        vm.startPrank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
        vm.stopPrank();
    }

    function test_fastWithdraw_ERC20_expectFail_assetNotRegisterOrInactive() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"4868b210db04ea6787a2f6e6a0956a0c7a12365c72ea317b62d3dfea7e073dc8";
        bytes32 _sigS = hex"1bdd8a6fd5e27895db846753bcb8fa93671659aa7773f04312062896cda74fac";
        uint8 _sigV = 28;

        // set block timestamp to fit expiration timestamp
        vm.warp(_expireTimestamp);

        vm.expectRevert(TokenManager.TokenManager_AssetNotRegistered.selector);
        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );

        vm.prank(operator);
        vaults[0].setAssetInactive(1);
        vm.expectRevert(TokenManager.TokenManager_AssetInactive.selector);
        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
    }

    function test_fastWithdraw_ERC20_expectFail_duplicateNonce() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"4868b210db04ea6787a2f6e6a0956a0c7a12365c72ea317b62d3dfea7e073dc8";
        bytes32 _sigS = hex"1bdd8a6fd5e27895db846753bcb8fa93671659aa7773f04312062896cda74fac";
        uint8 _sigV = 28;

        // exitLp approve ERC20 allowance to vault proxy
        vm.startPrank(lp);
        testToken.mint(_assetAmount);
        testToken.approve(address(vaults[0]), _assetAmount);
        vm.stopPrank();

        // set block timestamp to fit expiration timestamp
        vm.warp(_expireTimestamp);

        vm.startPrank(exitManager);
        // invalid signature
        vm.expectRevert(Vault.FastWithdraw_InvalidUserSignature.selector);
        bytes32 _sigRInvalid = hex"2ad9df656123d9c7f21ef444cffba287eab4ce481d08d38003b92bd21d8d5a64";
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigRInvalid,
            _sigS
        );

        // valid request
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );

        // duplicate nonce
        vm.expectRevert(Vault.FastWithdraw_UserNonceAlreadyUsed.selector);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
        vm.stopPrank();
    }

    function test_fastWithdraw_ERC20_expectFail_insufficientAllowanceOrBalance() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"4868b210db04ea6787a2f6e6a0956a0c7a12365c72ea317b62d3dfea7e073dc8";
        bytes32 _sigS = hex"1bdd8a6fd5e27895db846753bcb8fa93671659aa7773f04312062896cda74fac";
        uint8 _sigV = 28;

        // set block timestamp to fit expiration timestamp
        vm.warp(_expireTimestamp);

        // TODO: use expectPartialRevert after forge-std is upgraded
        vm.expectRevert();
        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );

        // approve allowance but burn balance
        vm.startPrank(lp);
        testToken.approve(address(vaults[0]), _assetAmount);
        testToken.transfer(address(vaults[0]), testToken.balanceOf(lp));
        vm.stopPrank();

        // TODO: use expectPartialRevert after forge-std is upgraded
        vm.expectRevert();
        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(testToken),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
    }

    function test_fastWithdraw_native() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"70ba57046ce805a9aaec19699595a2fd4dbce614c86a2e05e108fee8f3c0e10f";
        bytes32 _sigS = hex"6c7b61a022cfe9b3a262e007715d89d6320d3b101b9b71fe8007e68b5787a39c";
        uint8 _sigV = 28;

        // exitLp deposit and approve WETH allowance to vault proxy
        vm.startPrank(lp);
        vm.deal(lp, _assetAmount);
        weth.deposit{value: _assetAmount}();
        weth.approve(address(vaults[0]), _assetAmount);
        vm.stopPrank();

        // set block timestamp to fit expiration timestamp
        vm.warp(_expireTimestamp);

        // calculate expect l1->l2 msgQueue tail
        bytes32 l1Tol2TailHash = keccak256(messageQueueLogic.encodeFastWithdrawL1Message(
            0,
            lp,
            _recipient,
            uint32(NATIVE_ASSET_ID),
            uint128(_assetAmount),
            _nonce
        ));

        // expect l1->l2 message quueue update and log emit
        vm.expectEmit();
        emit ManagerApiLogic.LogL1ToL2MessageQueueFastWithdraw(
            lp,
            _recipient,
            NATIVE_ASSET_ID,
            _assetAmount,
            _nonce,
            l1Tol2TailHash
        );

        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
    }

    // panic message depends on the WETH implementation
    function test_fastWithdraw_native_expectFail_insufficientAllowanceOrBalance() public {
        // define args
        address _recipient = users[1];
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _nonce = 999_999;
        uint256 _expireTimestamp = 1_730_101_904;

        // signature is prone to change if token address is changed
        bytes32 _sigR = hex"70ba57046ce805a9aaec19699595a2fd4dbce614c86a2e05e108fee8f3c0e10f";
        bytes32 _sigS = hex"6c7b61a022cfe9b3a262e007715d89d6320d3b101b9b71fe8007e68b5787a39c";
        uint8 _sigV = 28;

        // set block timestamp to fit expiration timestamp
        vm.warp(_expireTimestamp);

        vm.expectRevert(stdError.arithmeticError);
        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );

        // approve WETH allowance but have no balance
        vm.startPrank(lp);
        weth.approve(address(vaults[0]), _assetAmount);
        vm.stopPrank();

        vm.expectRevert(stdError.arithmeticError);
        vm.prank(exitManager);
        vaults[0].fastWithdraw(
            lp,
            _recipient,
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestamp,
            _sigV,
            _sigR,
            _sigS
        );
    }
}
