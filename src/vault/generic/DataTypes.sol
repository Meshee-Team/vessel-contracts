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

library DataTypes {
    /// @dev asset registry
    struct AssetInfo {
        address assetAddress;
        uint8 limitDigit;
        uint8 precisionDigit;
        uint8 decimals;
        bool isActive;
    }

    /// @dev subsidiary chain pre-commit checkpoint of next proof batch.
    /// l1LastCommitHash and l1NextCommitHash is used to chain up series of checkpoints.
    /// l1MessageCnt is used to hint postCommitConfirmation.
    struct PreCommitCheckpoint {
        uint32 logicChainId;
        uint256 l1MessageCnt;
        bytes32 l1LastCommitHash;
        bytes32 l1NextCommitHash;
        bytes32 l2LastCommitHash;
    }

    /// @dev subsidiary chain post-commit confirmation of next proof batch.
    /// l1MessageCnt and l1NextCommitHash (along with l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex]) is
    ///     used to chain up series of confirmation.
    /// l2NextCommitDigest is used for validation of L2 message pre-images.
    struct PostCommitConfirmation {
        uint32 logicChainId;
        uint256 l1MessageCnt;
        bytes32 l1NextCommitHash;
        bytes32 l2NextCommitHash;
    }


    /// @dev Vessel state as preimage of SNARK proof instance
    struct VesselState {
        uint256 eternalTreeRoot;
        uint256 ephemeralTreeRoot;
        bytes32[] l1MessageQueueHash; // index by consecutive logicChainId
        bytes32[] l2MessageQueueHash;
    }
}
