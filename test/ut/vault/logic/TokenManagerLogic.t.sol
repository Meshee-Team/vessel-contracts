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

import { WETH } from "lib/solmate/src/tokens/WETH.sol";
import { TestBase } from "test/utils/TestBase.sol";
import { TokenManagerLogic } from "src/vault/logic/TokenManagerLogic.sol";
import { DataTypes } from "src/vault/generic/DataTypes.sol";
import { Token } from "src/misc/Token.sol";

contract TokenManagerLogicTest is TokenManagerLogic, TestBase {
    address internal lp = address(100);
    address internal user = address(101);
    WETH internal weth;
    Token internal testToken;

    // used to receive eth from WETH
    receive() external payable {}

    function setUp() public virtual {
        weth = new WETH();
        wethAddress = address(weth);

        testToken = new Token(lp, 10 ** 18, 12, "Token12", "T12");
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
    }

    function test_transferIn_ERC20() public {
        uint256 _amount = 12345;
        uint256 _lpBalanceBefore = testToken.balanceOf(lp);
        uint256 _vaultBalanceBefore = testToken.balanceOf(address(this));

        vm.startPrank(lp);
        testToken.approve(address(this), _amount);
        vm.expectEmit();
        emit LogVesselAssetTransfer(lp, address(this), ERC20_ASSET_ID, _amount);
        this.transferIn(ERC20_ASSET_ID, _amount);
        vm.stopPrank();

        assertEq(_lpBalanceBefore - _amount, testToken.balanceOf(lp));
        assertEq(_vaultBalanceBefore + _amount, testToken.balanceOf(address(this)));
    }

    function test_tranferIn_native() public {
        uint256 _amount = 12345;
        vm.deal(address(lp), _amount); // lp must have enough balance
        uint256 _lpBalanceBefore = address(lp).balance;
        uint256 _vaultBalanceBefore = address(this).balance;

        vm.prank(lp);
        vm.expectEmit();
        emit LogVesselAssetTransfer(lp, address(this), NATIVE_ASSET_ID, _amount);
        this.transferIn{value: _amount}(NATIVE_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore - _amount, address(lp).balance);
        assertEq(_vaultBalanceBefore + _amount, address(this).balance);
    }

    function test_transferOut_ERC20() public {
        uint256 _amount = 12345;
        testToken.mint(_amount); // vault must have enough balance
        uint256 _lpBalanceBefore = testToken.balanceOf(lp);
        uint256 _vaultBalanceBefore = testToken.balanceOf(address(this));

        vm.expectEmit();
        emit LogVesselAssetTransfer(address(this), lp, ERC20_ASSET_ID, _amount);
        this.transferOut(payable(address(lp)), ERC20_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore + _amount, testToken.balanceOf(lp));
        assertEq(_vaultBalanceBefore - _amount, testToken.balanceOf(address(this)));
    }

    function test_transferOut_native() public {
        uint256 _amount = 12345;
        uint256 _lpBalanceBefore = address(lp).balance;
        uint256 _vaultBalanceBefore = address(this).balance;

        vm.expectEmit();
        emit LogVesselAssetTransfer(address(this), lp, NATIVE_ASSET_ID, _amount);
        this.transferOut(payable(address(lp)), NATIVE_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore + _amount, address(lp).balance);
        assertEq(_vaultBalanceBefore - _amount, address(this).balance);
    }

    function test_transferOutFromExitLp_ERC20() public {
        uint256 _amount = 12345;
        uint256 _lpBalanceBefore = testToken.balanceOf(lp);
        uint256 _vaultBalanceBefore = testToken.balanceOf(address(this));
        uint256 _userBalanceBefore = testToken.balanceOf(user);

        vm.prank(lp);
        testToken.approve(address(this), _amount);
        vm.expectEmit();
        emit LogVesselAssetTransfer(lp, user, ERC20_ASSET_ID, _amount);
        this.transferOutFromExitLp(lp, payable(user), ERC20_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore - _amount, testToken.balanceOf(lp));
        assertEq(_vaultBalanceBefore, testToken.balanceOf(address(this)));
        assertEq(_userBalanceBefore + _amount, testToken.balanceOf(user));
    }

    function test_transferOutFromExitLp_native() public {
        uint256 _amount = 12345;
        vm.deal(address(lp), _amount); // lp must have enough balance
        vm.startPrank(lp);
        weth.deposit{value: _amount}();
        weth.approve(address(this), _amount);
        vm.stopPrank();
        
        uint256 _lpBalanceBefore = weth.balanceOf(lp); // native asset balance is in WETH
        uint256 _vaultBalanceBefore = address(this).balance;
        uint256 _userBalanceBefore = address(user).balance;

        vm.expectEmit();
        emit LogVesselAssetTransfer(lp, user, NATIVE_ASSET_ID, _amount);
        this.transferOutFromExitLp(lp, payable(user), NATIVE_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore - _amount, weth.balanceOf(lp));
        assertEq(_vaultBalanceBefore, address(this).balance);
        assertEq(_userBalanceBefore + _amount, address(user).balance);
    }

    function test_backfillToExitLp_ERC20() public {
        uint256 _amount = 12345;
        testToken.mint(_amount); // vault must have enough balance
        uint256 _lpBalanceBefore = testToken.balanceOf(lp);
        uint256 _vaultBalanceBefore = testToken.balanceOf(address(this));

        vm.expectEmit();
        emit LogVesselAssetTransfer(address(this), lp, ERC20_ASSET_ID, _amount);
        this.backfillToExitLp(payable(address(lp)), ERC20_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore + _amount, testToken.balanceOf(lp));
        assertEq(_vaultBalanceBefore - _amount, testToken.balanceOf(address(this)));
    }

    function test_backfillToExitLp_native() public {
        uint256 _amount = 12345;
        uint256 _lpBalanceBefore = weth.balanceOf(lp); // native asset balance is in WETH
        uint256 _vaultBalanceBefore = address(this).balance;

        vm.expectEmit();
        emit LogVesselAssetTransfer(address(this), lp, NATIVE_ASSET_ID, _amount);
        this.backfillToExitLp(payable(address(lp)), NATIVE_ASSET_ID, _amount);

        assertEq(_lpBalanceBefore + _amount, weth.balanceOf(lp));
        assertEq(_vaultBalanceBefore - _amount, address(this).balance);
    }
}