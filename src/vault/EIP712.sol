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

/// @title EIP712
/// @notice Contains all of the order hashing functions for EIP712 compliant signatures
contract EIP712 is Storage {
    /**********
     * Errors *
     **********/
    error InvalidVParam();

    /***********
     * Structs *
     ***********/

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    /*************
     * Constants *
     *************/

    /// @dev typehash for EIP 712 compatibility.
    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant USER_BINDING_TYPEHASH = keccak256("UserBinding(bytes pubKey,address addr)");

    // solhint-disable-next-line max-line-length
    bytes32 public constant FAST_WITHDRAW_TYPEHASH = keccak256("FastWithdraw(string action,address recipientAddress,address assetAddress,uint256 assetAmount,uint256 feeAmount,uint256 nonce,uint256 expireTimestampSec)");

    string public constant FAST_WITHDRAW_ACTION = "FAST_WITHDRAW";

    /**********************
     * Internal Functions *
     **********************/

    /// @dev hash implementation
    function _hashDomain(EIP712Domain memory _eip712Domain) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(_eip712Domain.name)),
                keccak256(bytes(_eip712Domain.version)),
                _eip712Domain.chainId,
                _eip712Domain.verifyingContract
            )
        );
    }

    function _digestUserBinding(bytes calldata _pubKey, address _addr) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", domainSeparator, keccak256(abi.encode(USER_BINDING_TYPEHASH, keccak256(_pubKey), _addr))
            )
        );
    }

    function _digestFastWithdraw(
        address _lpAddr,
        address _assetAddr,
        uint256 _assetAmount,
        uint256 _feeAmount,
        uint256 _nonce,
        uint256 _expireTimestampSec
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(
                    FAST_WITHDRAW_TYPEHASH,
                    keccak256(bytes(FAST_WITHDRAW_ACTION)),
                    _lpAddr,
                    _assetAddr,
                    _assetAmount,
                    _feeAmount,
                    _nonce,
                    _expireTimestampSec
                ))
            )
        );
    }

    /// @dev Verify ECDSA signature.
    function _verifyECDSA(address _signer, bytes32 _digest, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        if (!(_v == 27 || _v == 28)) {
            revert InvalidVParam();
        }
        address _recoveredSigner = ecrecover(_digest, _v, _r, _s);
        if (_recoveredSigner == address(0)) {
            return false;
        } else {
            return _signer == _recoveredSigner;
        }
    }
}
