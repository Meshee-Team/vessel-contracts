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

contract GovernanceTest is Governance, TestBase {
    address internal addr1 = address(1);
    address internal addr2 = address(2);
    address internal constant ZERO = 0x0000000000000000000000000000000000000000;

    function setUp() public virtual {}

    function testInitialize() public {
        assertEq(ZERO, admin);
        assertEq(false, operators[addr1]);
        initGovernance(addr1);
        assertEq(addr1, admin);
        assertEq(true, operators[addr1]);
    }

    function test_registerExitManager() public {
        initGovernance(addr1);
        assertEq(exitManagers[addr2], false);
        
        vm.expectRevert(Governance.Gov_CallerNotAdmin.selector);
        this.registerExitManager(addr2);

        vm.prank(addr1);
        this.registerExitManager(addr2);
        assertEq(exitManagers[addr2], true);
        
        vm.prank(addr1);
        this.unregisterExitManager(addr2);
        assertEq(exitManagers[addr2], false);
    }

    function testModifyOperators() public {
        initGovernance(addr1);
        assertEq(false, operators[addr2]);

        vm.startPrank(addr1);
        this.registerOperator(addr2);
        assertEq(true, operators[addr2]);
        this.unregisterOperator(addr2);
        assertEq(false, operators[addr2]);
        vm.stopPrank();
    }

    function testTransferAdmin() public {
        initGovernance(addr1);
        assertEq(addr1, admin);

        vm.prank(addr1);
        this.transferAdmin(addr2);
        assertEq(addr2, admin);
    }
}
