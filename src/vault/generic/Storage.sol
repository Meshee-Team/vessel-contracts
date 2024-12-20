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

import { Initializable } from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {
    ReentrancyGuardUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import { ICrossChainPortal } from "../../interface/ICrossChainPortal.sol";
import { DataTypes } from "./DataTypes.sol";

// solhint-disable-next-line max-states-count
contract Storage is
    Initializable,
    ReentrancyGuardUpgradeable
{
    /*************
     * Variables *
     *************/

    /// @dev deprecated: placeholder of oz4 Initializable
    // solhint-disable-next-line var-name-mixedcase
    uint8 private __deprecated__initialized;
    // solhint-disable-next-line var-name-mixedcase
    bool private __deprecated__initializing;

    /// @dev verifier config
    address public snarkVerifier;
    string public circuitVersion;

    /// @dev mpt state
    uint256 public eternalTreeRoot;
    uint256 public ephemeralTreeRoot;

    /// @dev message quue state
    mapping(uint256 index => bytes32 msgHash) public l1ToL2MessageQueueHash;
    uint256 public l1ToL2MessageQueueTailIndex;
    uint256 public l1ToL2MessageQueueCommitIndex;
    bytes32 public l2ToL1MessageQueueCommitHash;

    /// @dev governance storage
    address public admin;
    mapping(address account => bool isOperator) public operators;

    mapping(address assetAddress => uint256 assetId) public assetAddressToId;
    mapping(uint256 assetId => DataTypes.AssetInfo assetInfo) public assetIdToInfo;

    /// @dev pending withdraw: a map for userAddress => assetId => amount
    mapping(address userAddress => mapping(uint256 assetId => uint256 amount)) public pendingWithdraw;

    /// @dev deprecated: user map
    // solhint-disable-next-line var-name-mixedcase
    mapping(bytes vesselKey => address userAddress) private __deprecated__vesselKeyToUserAddress;

    /// @dev used by EIP712 signature
    bytes32 public domainSeparator;

    /// @dev used by contract operator to check on-chain progress
    uint256 public lastCommitBatchId;
    uint256 public lastCommitEventId;

    /// @dev deprecated: placeholder of oz4 ReentrancyGuard
    // solhint-disable-next-line var-name-mixedcase
    uint256 private __deprecated__status;

    /// @dev used by fast-withdraw feature
    mapping(address account => bool isExitManager) public exitManagers;
    mapping(address userAddress => mapping(uint256 nonce => bool used)) public fastExitUserNonce;
    address public wethAddress;

    /// @dev deprecated: message queue encoder
    // solhint-disable-next-line var-name-mixedcase
    address private __deprecated__mqEncoder;

    /// @dev logic contracts to perform d-call
    address public userApiLogicAddress;
    address public managerApiLogicAddress;
    address public messageQueueLogicAddress;
    address public tokenManagerLogicAddress;
    address public multiChainLogicAddress;

    /// @dev CrossChainPortal contract to transmit message cross-chain
    ICrossChainPortal public crossChainPortalContract;

    /// @dev primary and subsidiary chain configs
    uint32 public logicChainId;
    uint32 public primaryLogicChainId;
    uint32 public chainCnt;
    mapping(uint32 logicChainId => DataTypes.PreCommitCheckpoint cp) public preCommitCheckpointList;
    DataTypes.PostCommitConfirmation public postCommitConfirmation;

    /// @dev whether vault is configured
    bool public isConfigured;
}
