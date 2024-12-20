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
import { Common } from "./generic/Common.sol";
import { Constants } from "./generic/Constants.sol";
import { DataTypes } from "./generic/DataTypes.sol";
import { Governance } from "./Governance.sol";

contract TokenManager is Governance {
    /**********
     * Errors *
     **********/
    error TokenManager_AssetPrecisionTooBig();
    error TokenManager_AssetInactive();
    error TokenManager_AssetNotRegistered();
    error TokenManager_AssetAlreadyRegistered();
    error TokenManager_AssetIdAlreadyUsed();
    error TokenManager_AssetIdTooBig();
    error TokenManager_AssetIdZeroIsSetToNativeToken();
    error TokenManager_VaultLimitExceeded();

    /**********
     * Events *
     **********/

    event LogAssetActive(uint256 assetId);
    event LogAssetInactive(uint256 assetId);
    event LogAssetRegistered(
        uint256 assetId, address assetAddress, uint8 limitDigit, uint8 precisionDigit, uint8 decimals
    );
    event LogAssetLimitAndPrecisionUpdated(uint256 assetId, uint8 limitDigit, uint8 precisionDigit);

    /**********************
     * Function Modifiers *
     **********************/

    modifier assetActive(uint256 _assetId) {
        _checkAssetActive(_assetId);
        _;
    }

    modifier vaultAssetAmountUnderLimit(uint256 _assetId) {
        _;
        _checkVaultAssetAmountUnderLimit(_assetId);
    }

    /***************
     * Constructor *
     ***************/

    /// @dev old initializer, should only be used to initialize newly deployed vault.
    function initTokenManager() internal {
        // Register native asset (address 0) as id 0.
        assetAddressToId[address(0)] = 0;
        assetIdToInfo[0] = DataTypes.AssetInfo(address(0), 10, 8, 18, false);
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Retrieve assetInfo by assetId.
    function getAssetInfo(uint256 _assetId)
        public
        view
        returns (address _assetAddress, uint8 _limitDigit, uint8 _precisionDigit, uint8 _decimals, bool _isActive)
    {
        _assetAddress = assetIdToInfo[_assetId].assetAddress;
        _limitDigit = assetIdToInfo[_assetId].limitDigit;
        _precisionDigit = assetIdToInfo[_assetId].precisionDigit;
        _decimals = assetIdToInfo[_assetId].decimals;
        _isActive = assetIdToInfo[_assetId].isActive;
    }

    /// @notice constrain amount to align with asset precisionDigit and decimals.
    ///     The returned constrainedAmount is truncated to be multiple of (0.1 ** precisionDigit)
    ///     and then multiply to (10 ** decimals).
    function constrainAmountWithPrecision(
        uint256 _assetId,
        uint256 _amount
    )
        public
        view
        returns (uint256 _constrainedAmount)
    {
        uint8 _precisionDigit = assetIdToInfo[_assetId].precisionDigit;
        uint8 _decimals = assetIdToInfo[_assetId].decimals;
        uint256 _divisor = uint256(10) ** uint256(_decimals - _precisionDigit);
        _constrainedAmount = (_amount / _divisor) * _divisor;
    }

    /************************
     * Restricted Functions *
     ************************/

    /// @notice Only operator can register a new asset.
    function registerNewAsset(
        address _assetAddress,
        uint256 _assetId,
        uint8 _limitDigit,
        uint8 _precisionDigit,
        uint8 _decimals
    )
        public
        onlyOperator
    {
        _registerNewAsset(_assetAddress, _assetId, _limitDigit, _precisionDigit, _decimals);
    }

    /// @notice Only operator can update limitDigit and precisionDigit. Asset address and decimals cannot be changed.
    function updateAssetLimitAndPrecision(
        uint256 _assetId,
        uint8 _limitDigit,
        uint8 _precisionDigit
    )
        public
        onlyOperator
    {
        if (_precisionDigit > assetIdToInfo[_assetId].decimals) {
            revert TokenManager_AssetPrecisionTooBig();
        }
        assetIdToInfo[_assetId].limitDigit = _limitDigit;
        assetIdToInfo[_assetId].precisionDigit = _precisionDigit;
        emit LogAssetLimitAndPrecisionUpdated(_assetId, _limitDigit, _precisionDigit);
    }

    /// @notice Only operator can activate an asset.
    function setAssetActive(uint256 _assetId) public onlyOperator {
        assetIdToInfo[_assetId].isActive = true;
        emit LogAssetActive(_assetId);
    }

    /// @notice Only operator can activate an asset.
    function setAssetInactive(uint256 _assetId) public onlyOperator {
        assetIdToInfo[_assetId].isActive = false;
        emit LogAssetInactive(_assetId);
    }

    /**********************
     * Internal Functions *
     **********************/

    function _checkAssetActive(uint256 _assetId) internal view {
        if (!assetIdToInfo[_assetId].isActive) {
            revert TokenManager_AssetInactive();
        }
    }

    function _checkVaultAssetAmountUnderLimit(uint256 _assetId) internal view {
        uint256 _amountLimit = uint256(10) ** uint256(assetIdToInfo[_assetId].limitDigit);
        uint256 _amountLimitWithDecimals = (uint256(10) ** uint256(assetIdToInfo[_assetId].decimals)) * _amountLimit;
        if (Common.isNative(_assetId)) {
            if (address(this).balance >= _amountLimitWithDecimals) {
                revert TokenManager_VaultLimitExceeded();
            }
        } else {
            if (IERC20(assetIdToInfo[_assetId].assetAddress).balanceOf(address(this)) >= _amountLimitWithDecimals) {
                revert TokenManager_VaultLimitExceeded();
            }
        }
    }

    function _checkAndExtractAssetId(address _assetAddress) internal view returns (uint256) {
        uint256 _assetId = 0;
        if (_assetAddress != Constants.ETH_ADDRESS) {
            _assetId = assetAddressToId[_assetAddress];
            if (_assetId == 0) {
                revert TokenManager_AssetNotRegistered();
            }
        }
        _checkAssetActive(_assetId);
        return _assetId;
    }

    /// @dev Internal function for register new asset. New registered asset will be inactive by default.
    /// @param _limitDigit deposit amount will be constrained to less than (10 ** limitDigit).
    /// @param _precisionDigit deposit amount will be constrained to be multiple of (0.1 ** precisionDigit), taking
    ///     decimals into consideration.
    /// @param _decimals ERC20 token decimals.
    function _registerNewAsset(
        address _assetAddress,
        uint256 _assetId,
        uint8 _limitDigit,
        uint8 _precisionDigit,
        uint8 _decimals
    )
        internal
    {
        if (_assetId > 0xFFFFFFFF) {
            revert TokenManager_AssetIdTooBig();
        }
        if (assetAddressToId[_assetAddress] != 0) {
            revert TokenManager_AssetAlreadyRegistered();
        }
        if (assetIdToInfo[_assetId].assetAddress != address(0)) {
            revert TokenManager_AssetIdAlreadyUsed();
        }
        if (!(_assetAddress != address(0) && _assetId != 0)) {
            revert TokenManager_AssetIdZeroIsSetToNativeToken();
        }
        if (_precisionDigit > _decimals) {
            revert TokenManager_AssetPrecisionTooBig();
        }
        assetAddressToId[_assetAddress] = _assetId;

        assetIdToInfo[_assetId] = DataTypes.AssetInfo(_assetAddress, _limitDigit, _precisionDigit, _decimals, false);
        emit LogAssetRegistered(_assetId, _assetAddress, _limitDigit, _precisionDigit, _decimals);
    }
}
