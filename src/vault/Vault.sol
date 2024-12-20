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

import { IVault } from "../interface/IVault.sol";
import { Common } from "./generic/Common.sol";
import { Constants } from "./generic/Constants.sol";
import { DataTypes } from "./generic/DataTypes.sol";
import { Storage } from "./generic/Storage.sol";
import { Configuration } from "./Configuration.sol";
import { EIP712 } from "./EIP712.sol";
import { Governance } from "./Governance.sol";
import { TokenManager } from "./TokenManager.sol";
import { VerifierManager } from "./VerifierManager.sol";

// solhint-disable-next-line max-line-length
contract Vault is
    Storage,
    Governance,
    Configuration,
    EIP712,
    TokenManager,
    VerifierManager,
    IVault
{
    using Common for bool;

    /**********
     * Errors *
     **********/
    error InvalidVesselKeyLength();
    error InvalidRegisterSignature();
    error InvalidAssetType();
    error FastWithdraw_RequestExpired();
    error FastWithdraw_InvalidUserSignature();
    error FastWithdraw_UserNonceAlreadyUsed();
    error FastWithdraw_InvalidFeeAmount();

    /***************
     * Constructor *
     ***************/

    /// @dev Vault contract must be deployed with upgradeable proxy. Initialization from constructor is disabled.
    constructor() {
        _disableInitializers();
    }

    /// @dev old initializer, should only be used to initialize newly deployed vault.
    function initialize(address _vaultAdmin) internal {
        initGovernance(_vaultAdmin);
        initTokenManager();
        initVerifierManager();
        domainSeparator = _hashDomain(
            EIP712Domain({
                name: Constants.CONTRACT_NAME,
                version: Constants.CONTRACT_VERSION,
                chainId: block.chainid,
                verifyingContract: address(this)
            })
        );
    }

    function initialize_v2(address _vaultAdmin) public reinitializer(2) {
        __ReentrancyGuard_init();

        // Admin cannot be zero after initialization.
        // We use it as the condition to check whether it is a new or upgrade process.
        // Admin will not get reset if it is upgrade process.
        if (admin == address(0)) {
            initialize(_vaultAdmin);
        } else {
            postCommitConfirmation.l2NextCommitHash = l2ToL1MessageQueueCommitHash;
        }
    }

    // @dev Fallback function to receive ETH when unwrapping WETH
    receive() external payable {}

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @notice Check and register a user.
    ///     User registration is authorized by operator signature to avoid potential exploit like transaction front-run.
    function registerUser(
        bytes calldata _vesselKey,
        address _operator,
        uint8 _sigV,
        bytes32 _sigR,
        bytes32 _sigS
    )
        public
        nonReentrant
        onlyConfigured
    {
        if (_vesselKey.length != 64) {
            revert InvalidVesselKeyLength();
        }

        // verify operator signature
        bytes32 _digest = _digestUserBinding(_vesselKey, msg.sender);
        if (!_verifyECDSA(_operator, _digest, _sigV, _sigR, _sigS)) {
            revert InvalidRegisterSignature();
        }

        // Perform d-call to userApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "registerVesselKey(address,bytes)",
            msg.sender,
            _vesselKey
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = userApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /// @notice Deposit ERC20.
    function depositERC20(uint256 _assetId, uint256 _amount) public nonReentrant onlyConfigured {
        if (!Common.isERC20(_assetId)) {
            revert InvalidAssetType();
        }
        _depositAsset(_assetId, _amount);
    }

    /// @notice Deposit native asset.
    function depositNative() public payable nonReentrant onlyConfigured {
        uint256 _amount = msg.value;
        uint256 _assetId = 0;
        _depositAsset(_assetId, _amount);
    }

    /// @notice Withdraw balance.
    function withdraw(uint256 _assetId, uint256 _amount) public nonReentrant onlyConfigured {
        // Perform d-call to userApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "withdrawAsset(uint256,uint256)",
            _assetId,
            _amount
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = userApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /*************************************************
     * Composite Public Functions for UX Convenience *
     ************************************************/

    /// @notice Register and deposit ERC20.
    function registerAndDepositERC20(
        bytes calldata _vesselKey,
        address _operator,
        uint8 _sigV,
        bytes32 _sigR,
        bytes32 _sigS,
        uint256 _assetId,
        uint256 _amount
    )
        external
    {
        registerUser(_vesselKey, _operator, _sigV, _sigR, _sigS);
        depositERC20(_assetId, _amount);
    }

    /// @notice Register and deposit native asset.
    function registerAndDepositNative(
        bytes calldata _vesselKey,
        address _operator,
        uint8 _sigV,
        bytes32 _sigR,
        bytes32 _sigS
    )
        external
        payable
    {
        registerUser(_vesselKey, _operator, _sigV, _sigR, _sigS);
        depositNative();
    }

    /// @notice Withdraw all.
    function withdrawAll(uint256 _assetId) external {
        uint256 _balance = pendingWithdraw[msg.sender][_assetId];
        withdraw(_assetId, _balance);
    }

    /************************
     * Restricted Functions *
     ************************/

    /// @notice Only operator can pre-commit sub chain progress to primary chain.
    /// @param _nextL1CommitIndex L1 to L2 message queue index to be committed in next proof.
    function preCommitSubChainProgress(uint256 _nextL1CommitIndex)
        external payable
        nonReentrant
        onlyConfigured
        onlyOperator
    {
        // Perform d-call to ManagerApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "preCommitSubChainProgress(uint256)",
            _nextL1CommitIndex
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = managerApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /// @notice Only operator can finalize PostCommitConfirmation passed from primary chain.
    /// @param _l2ToL1Messages L2 to L1 messages conforming to PostCommitConfirmation.l2NextCommitDigest.
    function finalizePostCommitConfirmation(bytes[] calldata _l2ToL1Messages)
        external
        nonReentrant
        onlyConfigured
        onlyOperator
    {
        // Perform d-call to ManagerApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "finalizePostCommitConfirmation(bytes[])",
            _l2ToL1Messages
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = managerApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /// @notice Receive cross-chain message from ICrossChainPortal.
    ///     Primary chain will only receive L1MessageQueueCheckpoint from subsidiary chain.
    ///     Subsidiary chain will only receive MessageQueueConfirmation from primary chain.
    /// @param _srcLogicChainId source chain
    /// @param _payload message payload
    function receiveMessageCrossChain(
        uint32 _srcLogicChainId,
        bytes calldata _payload
    )
        external
        nonReentrant
        onlyConfigured
        onlyFromCrossChainPortal
    {
        // Perform d-call to MultiChainLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "receiveMessage(uint32,bytes)",
            _srcLogicChainId,
            _payload
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = multiChainLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /// @notice Only operator can commit SNARK proof to update on-chain state.
    /// @param _instances: list of public instances to verify along with SNARK proof.
    ///     Encoding of instances must be consistent with circuit:
    ///     - 12 * aggregation circuit lhs & rhs values used by verifier
    ///     - state before hash:
    ///         - subChain0 l1 to l2 message queue hash before
    ///         - subChain1 l1 to l2 message queue hash before
    ///         - l2 to l1 message queue hash before
    ///         - eternal mpt root before
    ///         - ephemeral mpt root before
    ///     - state after hash:
    ///         - subChain0 l1 to l2 message queue hash after
    ///         - subChain1 l1 to l2 message queue hash after
    ///         - l2 to l1 message queue hash after
    ///         - eternal mpt root after
    ///         - ephemeral mpt root after
    /// @param _proof: SNARK proof to commit
    /// @param _stateBefore: preimage of state before hash
    /// @param _stateAfter: preimage of state after hash
    /// @param _batchId: used to track the progress of SNARK proofs.
    /// @param _lastEventId: used to track the progress of SNARK proofs.
    function commitSnarkProof(
        uint256[] calldata _instances,
        bytes calldata _proof,
        DataTypes.VesselState calldata _stateBefore,
        DataTypes.VesselState calldata _stateAfter,
        uint256 _batchId,
        uint256 _lastEventId
    )
        external payable
        nonReentrant
        onlyConfigured
        onlyOperator
        onlyPrimaryChain
    {
        // Perform d-call to ManagerApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            // solhint-disable-next-line max-line-length
            "commitSnarkProof(uint256[],bytes,(uint256,uint256,bytes32[],bytes32[]),(uint256,uint256,bytes32[],bytes32[]),uint256,uint256)",
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = managerApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /// @notice Withdraw asset in an expeditious manner.
    ///     Only whitelisted exitLP can call this function.
    ///     Assets will be transfered from exitLP and not affect assets under the Vault.
    ///     Message queue will be updated to notify off-chain processor to refill the exitLP.
    function fastWithdraw(
        address _lpAddr,
        address _recipientAddr,
        address _assetAddr,
        uint256 _assetAmount,
        uint256 _feeAmount,
        uint256 _nonce,
        uint256 _expireTimestampSec,
        uint8 _sigV,
        bytes32 _sigR,
        bytes32 _sigS
    )
        external
        nonReentrant
        onlyConfigured
        onlyExitManager
    {
        // check asset id and active
        uint256 _assetId = _checkAndExtractAssetId(_assetAddr);

        // check expire timestamp
        if (block.timestamp > _expireTimestampSec) {
            revert FastWithdraw_RequestExpired();
        }

        // check signature validity
        bytes32 _digest = _digestFastWithdraw(
            _recipientAddr,
            _assetAddr,
            _assetAmount,
            _feeAmount,
            _nonce,
            _expireTimestampSec
        );
        if (!_verifyECDSA(_recipientAddr, _digest, _sigV, _sigR, _sigS)) {
            revert FastWithdraw_InvalidUserSignature();
        }

        // check and mark nonce usage
        if (fastExitUserNonce[_recipientAddr][_nonce]) {
            revert FastWithdraw_UserNonceAlreadyUsed();
        }
        fastExitUserNonce[_recipientAddr][_nonce] = true;

        // check fee amount not eceeds total asset amount
        if (_feeAmount > _assetAmount) {
            revert FastWithdraw_InvalidFeeAmount();
        }

        // Perform d-call to ManagerApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "fastWithdraw(address,address,uint256,uint256,uint256,uint256)",
            _lpAddr,
            _recipientAddr,
            _assetId,
            _assetAmount,
            _feeAmount,
            _nonce
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = managerApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
    }

    /**********************
     * Internal Functions *
     **********************/

    function _depositAsset(
        uint256 _assetId,
        uint256 _amount
    )
        internal
        assetActive(_assetId)
        vaultAssetAmountUnderLimit(_assetId)
    {
        uint256 _actualAmount = constrainAmountWithPrecision(_assetId, _amount);

        // Perform d-call to userApiLogic contract
        bytes memory _data = abi.encodeWithSignature(
            "depositAsset(uint256,uint256)",
            _assetId,
            _actualAmount
        );
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success,) = userApiLogicAddress.delegatecall(_data);
        _success.popupRevertReason();
     }
}
