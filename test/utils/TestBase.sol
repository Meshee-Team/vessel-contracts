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

import { Test } from "forge-std/Test.sol";

contract TestBase is Test {
    uint256 constant internal NATIVE_ASSET_ID = 0;
    uint256 constant internal ERC20_ASSET_ID = 1;

    uint32 internal constant PRIMARY_CHAIN_ID = 0;
    uint32 internal constant SUB_CHAIN_ID = 1;

    // storage slots
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(8));
    bytes32 internal constant OPERATOR_MAPPING_SLOT = bytes32(uint256(9));
    bytes32 internal constant PENDING_WITHDRAW_SLOT = bytes32(uint256(12));
    bytes32 internal constant VESSEL_KEY_TO_USER_ADDRESS_SLOT = bytes32(uint256(13));
    bytes32 internal constant DOMAIN_SEPARATOR_SLOT = bytes32(uint256(14));
    bytes32 internal constant CROSS_CHAIN_PORTAL_SLOT = bytes32(uint256(27));
    bytes32 internal constant CHAIN_ID_COMPOSITE_SLOT = bytes32(uint256(28));

    function setAdmin(address _contractAddress, address _adminAddress) internal {
        bytes32 _adminValue = _addressToBytes32(_adminAddress);
        vm.store(_contractAddress, ADMIN_SLOT, _adminValue);
    }

    function addOperator(address _contractAddress, address _operatorAddress) internal {
        bytes32 _valueSlot = keccak256(abi.encode(_operatorAddress, OPERATOR_MAPPING_SLOT));
        vm.store(_contractAddress, _valueSlot, bytes32(uint256(1)));
    }

    function setDomainSeparator(address _contractAddress, bytes32 _value) internal {
        vm.store(_contractAddress, DOMAIN_SEPARATOR_SLOT, _value);
    }

    function setPendingWithdraw(address _contract, uint256 _assetId, address _userAddress, uint256 _amount) internal {
        bytes32 _userSlot = keccak256(abi.encode(_userAddress, PENDING_WITHDRAW_SLOT));
        bytes32 _valueSlot = keccak256(abi.encode(_assetId, _userSlot));
        vm.store(_contract, _valueSlot, bytes32(uint256(_amount)));
    }

    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(address(_addr))));
    }
}
