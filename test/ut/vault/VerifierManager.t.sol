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
import { VerifierManager } from "src/vault/VerifierManager.sol";

contract VerifierManagerTest is VerifierManager, TestBase {
    address internal adminAddr = address(1);

    function setUp() public virtual {
        initVerifierManager();
        admin = adminAddr;
    }

    function test_update_metadata() public {
        // assert initial metadata value
        assertEq(keccak256(abi.encodePacked(circuitVersion)), keccak256(abi.encodePacked("")));
        assertEq(snarkVerifier, address(0));

        string memory _newVersion = "v1";
        address _newSnarkVerifier = address(2);

        // only admin can update metadata
        vm.expectRevert(Governance.Gov_CallerNotAdmin.selector);
        this.updateAll(_newSnarkVerifier, _newVersion);

        vm.prank(adminAddr);
        this.updateAll(_newSnarkVerifier, _newVersion);
        assertEq(
            keccak256(abi.encodePacked(circuitVersion)), keccak256(abi.encodePacked(_newVersion))
        );
        assertEq(snarkVerifier, _newSnarkVerifier);
    }

    function test_initState() public {
        // assert initial state value
        assertEq(eternalTreeRoot, 0);
        assertEq(ephemeralTreeRoot, 0);
    }
}
