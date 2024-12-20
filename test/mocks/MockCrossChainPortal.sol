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

import { ICrossChainPortal } from "src/interface/ICrossChainPortal.sol";

contract MockCrossChainPortal is ICrossChainPortal{
    event MockCrossChainMsgSent(uint32, bytes, uint256);

    function quote(
        uint32,
        bytes calldata _payload
    ) external pure returns (uint256 nativeFee) {
        return _payload.length;
    }

    /// @dev mock function will not refund excessive amount of cross-chain fee.
    function sendMessageCrossChain(
        uint32 _dstLogicChainId,
        bytes calldata _payload,
        address payable
    ) external payable {
        uint256 _quote = this.quote(_dstLogicChainId, _payload);
        require(msg.value >= _quote, "cross-chain fee not enough");
        emit MockCrossChainMsgSent(_dstLogicChainId, _payload, msg.value);
    }
}