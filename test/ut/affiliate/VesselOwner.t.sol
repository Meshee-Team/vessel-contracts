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
import { VesselOwner } from "src/affiliate/VesselOwner.sol";

contract VesselOwnerTest is TestBase {
    error AccessControlUnauthorizedAccount(address,bytes32);

    event GrantAccess(bytes32 indexed role, address indexed target, bytes4[] selectors);
    event RevokeAccess(bytes32 indexed role, address indexed target, bytes4[] selectors);
    event Call();

    VesselOwner private owner;

    function setUp() public {
        owner = new VesselOwner();
    }

    function testUpdateAccess() external {
        // revert as sender is not default admin
        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(1), bytes32(0)));
        owner.updateAccess(address(0), new bytes4[](0), bytes32(0), true);
        vm.stopPrank();

        bytes4[] memory _selectors;
        bytes32[] memory _roles;

        // add access then remove access of revertOnCall() function
        _roles = owner.callableRoles(address(this), VesselOwnerTest.revertOnCall.selector);
        assertEq(0, _roles.length);
        _selectors = new bytes4[](1);
        _selectors[0] = VesselOwnerTest.revertOnCall.selector;

        vm.expectEmit();
        emit GrantAccess(bytes32(uint256(1)), address(this), _selectors);

        owner.updateAccess(address(this), _selectors, bytes32(uint256(1)), true);
        _roles = owner.callableRoles(address(this), VesselOwnerTest.revertOnCall.selector);
        assertEq(1, _roles.length);
        assertEq(_roles[0], bytes32(uint256(1)));

        vm.expectEmit();
        emit RevokeAccess(bytes32(uint256(1)), address(this), _selectors);

        owner.updateAccess(address(this), _selectors, bytes32(uint256(1)), false);
        _roles = owner.callableRoles(address(this), VesselOwnerTest.revertOnCall.selector);
        assertEq(0, _roles.length);
    }

    function testAdminExecute() external {
        // revertOnCall()
        vm.expectRevert("Called");
        owner.execute(address(this), 0, abi.encodeWithSelector(VesselOwnerTest.revertOnCall.selector), bytes32(0));

        // emitOnCall()
        vm.expectEmit();
        emit Call();
        owner.execute(address(this), 0, abi.encodeWithSelector(VesselOwnerTest.emitOnCall.selector), bytes32(0));
    }

    function testExecute() external {
        bytes32 _role = bytes32(uint256(101));
        address _address = address(1);

        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = VesselOwnerTest.revertOnCall.selector;
        _selectors[1] = VesselOwnerTest.emitOnCall.selector;

        owner.grantRole(_role, _address);

        // _role has no access, reverted
        vm.startPrank(address(1));
        vm.expectRevert("no access");
        owner.execute(address(this), 0, abi.encodeWithSelector(VesselOwnerTest.revertOnCall.selector), _role);
        vm.stopPrank();

        // grant access to role
        owner.updateAccess(address(this), _selectors, _role, true);

        // call functions
        vm.startPrank(address(1));
        // revertOnCall()
        vm.expectRevert("Called");
        owner.execute(
            address(this), 0, abi.encodeWithSelector(VesselOwnerTest.revertOnCall.selector), bytes32(uint256(101))
        );
        // emitOnCall()
        vm.expectEmit();
        emit Call();
        owner.execute(
            address(this), 0, abi.encodeWithSelector(VesselOwnerTest.emitOnCall.selector), bytes32(uint256(101))
        );
        vm.stopPrank();
    }

    function revertOnCall() external pure {
        revert("Called");
    }

    function emitOnCall() external {
        emit Call();
    }
}
