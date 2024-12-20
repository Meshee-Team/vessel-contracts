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

library Common {
    /// @notice Asset is ERC20 iff assetId > 0.
    function isERC20(uint256 _assetId) internal pure returns (bool) {
        return _assetId > 0;
    }

    /// @notice Asset is native iff assetId == 0.
    function isNative(uint256 _assetId) internal pure returns (bool) {
        return _assetId == 0;
    }

    /// @dev Below lines will propagate inner error up for delegate-call.
    function popupRevertReason(bool _success) internal pure {
        if (!_success) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let _ptr := mload(0x40)
                let _size := returndatasize()
                returndatacopy(_ptr, 0, _size)
                revert(_ptr, _size)
            }
        }
    }
}
