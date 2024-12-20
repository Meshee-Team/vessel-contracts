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

import { Governance } from "./Governance.sol";

contract VerifierManager is Governance {
    /**********
     * Events *
     **********/

    event LogNewSnarkVerifier(address);
    event LogNewCircuitVersion(string);

    /***************
     * Constructor *
     ***************/

    /// @dev old initializer, should only be used to initialize newly deployed vault.
    function initVerifierManager() internal {
        circuitVersion = "";
        snarkVerifier = address(0);
        eternalTreeRoot = 0;
        ephemeralTreeRoot = 0;
    }

    /************************
     * Restricted Functions *
     ************************/

    /// @notice Only admin can update verifier.
    function updateAll(address _snarkVerifier, string calldata _circuitVersion) public onlyAdmin {
        updateSnarkVerifierAddress(_snarkVerifier);
        updateCircuitVersion(_circuitVersion);
    }

    /// @notice Only admin can update verifier.
    function updateSnarkVerifierAddress(address _newVerifier) public onlyAdmin {
        snarkVerifier = _newVerifier;
        emit LogNewSnarkVerifier(snarkVerifier);
    }

    /// @notice Only admin can update circuit version.
    function updateCircuitVersion(string calldata _newCircuitVersion) public onlyAdmin {
        circuitVersion = _newCircuitVersion;
        emit LogNewCircuitVersion(_newCircuitVersion);
    }
}
