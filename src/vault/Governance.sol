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

import { Storage } from "./generic/Storage.sol";

contract Governance is Storage {
    /**********
     * Errors *
     **********/
    error Gov_InvalidZeroAddress();
    error Gov_CallerNotAdmin();
    error Gov_CallerNotOperator();
    error Gov_CallerNotExitManager();

    /**********
     * Events *
     **********/

    event AdminTransferred(address oldAdmin, address newAdmin);
    event LogOperatorAdded(address operator);
    event LogOperatorRemoved(address operator);
    event LogExitManagerAdded(address exitManager);
    event LogExitManagerRemoved(address exitManager);

    /**********************
     * Function Modifiers *
     **********************/

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    modifier onlyExitManager() {
        _checkExitManager();
        _;
    }

    /***************
     * Constructor *
     ***************/

    /// @dev old initializer, should only be used to initialize newly deployed vault.
    function initGovernance(address _account) internal {
        operators[_account] = true;
        admin = _account;
    }

    /************************
     * Restricted Functions *
     ************************/

    /// @notice Transfers admin role of the contract to a new account (`newAdmin`).
    function transferAdmin(address _newAdmin) public onlyAdmin {
        if (_newAdmin == address(0)) {
            revert Gov_InvalidZeroAddress();
        }
        address _oldAdmin = admin;
        admin = _newAdmin;
        emit AdminTransferred(_oldAdmin, _newAdmin);
    }

    /// @notice Register a new operator.
    function registerOperator(address _account) public onlyAdmin {
        operators[_account] = true;
        emit LogOperatorAdded(_account);
    }

    /// @notice Unregister an old operator.
    function unregisterOperator(address _account) public onlyAdmin {
        operators[_account] = false;
        emit LogOperatorRemoved(_account);
    }

    /// @notice Register a new exit liquidity provider for fast withdraw.
    function registerExitManager(address _account) public onlyAdmin {
        exitManagers[_account] = true;
        emit LogExitManagerAdded(_account);
    }

    /// @notice Unregister a new exit liquidity provider.
    function unregisterExitManager(address _account) public onlyAdmin {
        exitManagers[_account] = false;
        emit LogExitManagerRemoved(_account);
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev throws if the sender is not the admin.
    function _checkAdmin() internal view {
        if (admin != msg.sender) {
            revert Gov_CallerNotAdmin();
        }
    }

    /// @dev Throws if the sender is not an operator.
    function _checkOperator() internal view {
        if (!operators[msg.sender]) {
            revert Gov_CallerNotOperator();
        }
    }

    /// @dev Throws if the sender is not an exit manager.
    function _checkExitManager() internal view {
        if (!exitManagers[msg.sender]) {
            revert Gov_CallerNotExitManager();
        }
    }
}
