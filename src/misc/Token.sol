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

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    uint8 public tokenDecimals;

    constructor(
        address admin_,
        uint256 amount_,
        uint8 decimals_,
        string memory name_,
        string memory symbol_
    )
        ERC20(name_, symbol_)
    {
        tokenDecimals = decimals_;
        _mint(admin_, amount_);
    }

    /// @dev self-served mint function for testing purpose.
    function mint(uint256 amount) public {
        require(amount <= 10 ** 24, "Token: can mint up to 1 million tokens each time");
        _mint(msg.sender, amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}
