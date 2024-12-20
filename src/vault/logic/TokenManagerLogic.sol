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

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "lib/openzeppelin-contracts/contracts/utils/Address.sol";
import { WETH } from "lib/solmate/src/tokens/WETH.sol";
import { Common } from "../generic/Common.sol";
import { Storage } from "../generic/Storage.sol";

contract TokenManagerLogic is Storage {
    using Address for address payable;
    using SafeERC20 for IERC20;

    /**********
     * Errors *
     **********/
    error InvalidRecipient();
    error VaultBalanceOverflow();
    error VaultBalanceUnderflow();
    error VaultBalanceChangeIncorrect();
    error LpBalanceChangeIncorrect();
    error DepositAmountIncorrect();
    error UnsupportedTokenType();

    /**********
     * Events *
     **********/

    event LogVesselAssetTransfer(address from, address to, uint256 assetId, uint256 amount);

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @dev Transfers funds from msg.sender to the exchange. Refund extra native tokens sent to vault.
    function transferIn(uint256 _assetId, uint256 _amount) public payable {
        emit LogVesselAssetTransfer(msg.sender, address(this), _assetId, _amount);
        if (Common.isERC20(_assetId)) {
            if (_amount == 0) return;
            address _tokenAddress = assetIdToInfo[_assetId].assetAddress;
            IERC20 _token = IERC20(_tokenAddress);
            uint256 _exchangeBalanceBefore = _token.balanceOf(address(this));
            _token.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 exchangeBalanceAfter = _token.balanceOf(address(this));
            if (exchangeBalanceAfter < _exchangeBalanceBefore) {
                revert VaultBalanceOverflow();
            }
            if (exchangeBalanceAfter != _exchangeBalanceBefore + _amount) {
                revert VaultBalanceChangeIncorrect();
            }
        } else if (Common.isNative(_assetId)) {
            if (msg.value < _amount) {
                revert DepositAmountIncorrect();
            }
            uint256 _refundAmount = msg.value - _amount;
            if (_refundAmount > 0) {
                Address.sendValue(payable(msg.sender), _refundAmount);
            }
        } else {
            revert UnsupportedTokenType();
        }
    }

    /// @dev Transfers funds from the exchange to recipient.
    function transferOut(address payable _recipient, uint256 _assetId, uint256 _amount) public {
        emit LogVesselAssetTransfer(address(this), _recipient, _assetId, _amount);
        // Make sure we don't accidentally burn funds.
        if (_recipient == address(0x0)) {
            revert InvalidRecipient();
        }
        if (Common.isERC20(_assetId)) {
            if (_amount == 0) return;
            address _tokenAddress = assetIdToInfo[_assetId].assetAddress;
            IERC20 _token = IERC20(_tokenAddress);
            uint256 _exchangeBalanceBefore = _token.balanceOf(address(this));
            _token.safeTransfer(_recipient, _amount);
            uint256 _exchangeBalanceAfter = _token.balanceOf(address(this));
            if (_exchangeBalanceAfter > _exchangeBalanceBefore) {
                revert VaultBalanceUnderflow();
            }
            if (_exchangeBalanceAfter != _exchangeBalanceBefore - _amount) {
                revert VaultBalanceChangeIncorrect();
            }
        } else if (Common.isNative(_assetId)) {
            if (_amount == 0) return;
            Address.sendValue(_recipient, _amount);
        } else {
            revert UnsupportedTokenType();
        }
    }

    /// @dev Transfers funds from the exit LP to recipient.
    function transferOutFromExitLp(address _lp, address payable _recipient, uint256 _assetId, uint256 _amount) public {
        emit LogVesselAssetTransfer(_lp, _recipient, _assetId, _amount);
        if (_recipient == address(0x0)) {
            revert InvalidRecipient();
        }
        if (Common.isERC20(_assetId)) {
            if (_amount == 0) return;
            address _tokenAddress = assetIdToInfo[_assetId].assetAddress;
            IERC20 _token = IERC20(_tokenAddress);
            _token.safeTransferFrom(_lp, _recipient, _amount);
        } else if (Common.isNative(_assetId)) {
            // transfer WETH from lp to vault -> unwrap WETH -> transfer ETH from vault to recipient
            if (_amount == 0) return;
            uint256 _exchangeBalanceBefore = address(this).balance;

            IERC20(wethAddress).safeTransferFrom(_lp, address(this), _amount);
            WETH(payable(wethAddress)).withdraw(_amount);
            Address.sendValue(_recipient, _amount);

            uint256 _exchangeBalanceAfter = address(this).balance;
            if (_exchangeBalanceAfter != _exchangeBalanceBefore) {
                revert VaultBalanceChangeIncorrect();
            }
        } else {
            revert UnsupportedTokenType();
        }
    }

    /// @dev Backfill funds from vault to exitLP.
    function backfillToExitLp(address payable _lp, uint256 _assetId, uint256 _amount) public {
        emit LogVesselAssetTransfer(address(this), _lp, _assetId, _amount);
        if (_lp == address(0x0)) {
            revert InvalidRecipient();
        }
        if (Common.isERC20(_assetId)) {
            transferOut(_lp, _assetId, _amount);
        } else if (Common.isNative(_assetId)) {
            if (_amount == 0) return;
            uint256 _exchangeBalanceBefore = address(this).balance;
            uint256 _lpBalanceBefore = WETH(payable(wethAddress)).balanceOf(_lp);

            WETH(payable(wethAddress)).deposit{value: _amount}();
            IERC20(wethAddress).safeTransfer(_lp, _amount);

            uint256 _exchangeBalanceAfter = address(this).balance;
            uint256 _lpBalanceAfter = WETH(payable(wethAddress)).balanceOf(_lp);
            if (_exchangeBalanceAfter != _exchangeBalanceBefore - _amount) {
                revert VaultBalanceChangeIncorrect();
            }
            if (_lpBalanceAfter != _lpBalanceBefore + _amount) {
                revert LpBalanceChangeIncorrect();
            }
        } else {
            revert UnsupportedTokenType();
        }
    }
}
