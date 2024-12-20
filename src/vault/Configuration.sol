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

import { ICrossChainPortal } from "../interface/ICrossChainPortal.sol";
import { DataTypes } from "./generic/DataTypes.sol";
import { Governance } from "./Governance.sol";

contract Configuration is Governance {
    /**********
     * Errors *
     **********/
    error Config_InvalidSubChainCnt();
    error Config_VaultNotConfigured();
    error Config_NotPrimaryChain();
    error Config_NotFromCrossChainPortal();

    /**********************
     * Function Modifiers *
     **********************/

    modifier onlyConfigured() {
        _checkConfigured();
        _;
    }

    modifier onlyPrimaryChain() {
        _checkPrimary();
        _;
    }

    modifier onlyFromCrossChainPortal() {
        _checkFromCrossChainPortal();
        _;
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    function configureAll(
        address _wethAddress,
        address _userApiLogicAddress,
        address _managerApiLogicAddress,
        address _messageQueueLogicAddress,
        address _tokenManagerLogicAddress,
        address _multiChainLogicAddress,
        address _crossChainPortalContractAddress,
        uint32 _logicChainId,
        uint32 _primaryLogicChainId,
        uint32 _chainCnt,
        DataTypes.PreCommitCheckpoint[] calldata cps
    ) external onlyAdmin {
        wethAddress = _wethAddress;
        userApiLogicAddress = _userApiLogicAddress;
        managerApiLogicAddress = _managerApiLogicAddress;
        messageQueueLogicAddress = _messageQueueLogicAddress;
        tokenManagerLogicAddress = _tokenManagerLogicAddress;
        multiChainLogicAddress = _multiChainLogicAddress;
        crossChainPortalContract = ICrossChainPortal(_crossChainPortalContractAddress);
        logicChainId = _logicChainId;
        primaryLogicChainId = _primaryLogicChainId;
        chainCnt =  _chainCnt;

        // initialize checkpoints of subsidiary chains
        for (uint256 _i = 0; _i < cps.length; _i++) {
            preCommitCheckpointList[cps[_i].logicChainId] = cps[_i];
        }
    }

    function setConfigured(bool _isConfigured) external onlyAdmin {
        isConfigured = _isConfigured;
    }

    /**********************
     * Internal Functions *
     **********************/

    function _checkConfigured() internal view {
        if (!isConfigured) {
            revert Config_VaultNotConfigured();
        }
    }

    function _checkPrimary() internal view {
        if (logicChainId != primaryLogicChainId) {
            revert Config_NotPrimaryChain();
        }
    }

    function _checkFromCrossChainPortal() internal view {
        if (msg.sender != address(crossChainPortalContract)) {
            revert Config_NotFromCrossChainPortal();
        }
    }
}
