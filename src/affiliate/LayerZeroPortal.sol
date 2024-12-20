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

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {
    Origin,
    MessagingReceipt,
    MessagingFee,
    OAppUpgradeable
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import { IVault } from "../interface/IVault.sol";
import { ICrossChainPortal } from "../interface/ICrossChainPortal.sol";

contract LayerZeroPortal is OAppUpgradeable, ICrossChainPortal {
    using OptionsBuilder for bytes;

    /***********
     * Storage *
     ***********/

    /// @dev Mapping to track the maximum received nonce for each source endpoint and sender.
    mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) private receivedNonce;

    /// @dev Vault contract to apply received message from the other chain.
    IVault public vaultContract;

    /// @dev Chain info indexed by consecutive logicChainId.
    uint256 public chainCnt;
    mapping(uint32 logicChainId => uint32 eid) public logicChainIdToEid;
    mapping(uint32 eid => uint32 logicChainId) public eidToLogicChainId;

    /// @dev whether vault is configured
    bool public isConfigured;

    /*************
     * Constants *
     *************/
    uint128 public constant L0_EXECUTION_GAS_LIMIT = 1; // zero gas limit will get reverted
    uint128 public constant L0_EXECUTION_MSG_VALUE = 0;

    /**********
     * Errors *
     **********/

    error L0Portal_NotConfigured();
    error L0Portal_InvalidLogicChainId(uint32 actual);
    error L0Portal_InvalidOrigin(uint32 actualSrcEid, bytes32 actualSender);
    error L0Portal_InvalidNextNonce(uint64 actual);
    error L0Portal_NotFromVaultContract(address actual);

    /**********
     * Events *
     **********/
    event LogL0MsgSent(uint32 dstChain, uint64 nonce, uint256 nativeFee, bytes payload);
    event LogL0MsgReceived(uint32 srcChain, uint64 nonce, bytes payload);

    /**********************
     * Function Modifiers *
     **********************/

    modifier onlyConfigured() {
        _checkConfigured();
        _;
    }

    modifier onlyFromVault() {
        _checkFromVault();
        _;
    }

    /***************
     * Constructor *
     ***************/

    /// @notice Constructor is only used to set immutable endpoint. Use initialize() to initialzie.
    /// @param _endpoint Address of the LayerZero endpoint.
    constructor(address _endpoint)
        OAppUpgradeable(_endpoint)
    {}

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __OApp_init(_owner);
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Get option bytes for specific arguments.
    ///     If you do not pass an ExecutorOrderedExecutionOption in your _lzSend call, the Executor will attempt to
    ///     execute the message despite your application-level nonce enforcement, leading to a message revert.
    ///     However, we in purpose do not pass this Option to simplifiy the payload, as we intend to fail-and-retry
    ///     the default executor to facilitate proper refund of gasLimit.
    /// @param _gasLimit Gas limit on target chain tx execution
    /// @param _msgValue Msg value on target chain tx execution
    function getOptionBytes(uint128 _gasLimit, uint128 _msgValue) public pure returns (bytes memory _option) {
        _option = OptionsBuilder.newOptions().addExecutorLzReceiveOption(_gasLimit, _msgValue);
    }

    /// @notice Quote Layer Zero cost with given input.
    /// @param _dstLogicChainId Destination logic chain id.
    /// @param _payload Message payload being sent.
    function quote(
        uint32 _dstLogicChainId,
        bytes calldata _payload
    ) external view returns (uint256 _nativeFee) {
        if (_dstLogicChainId >= chainCnt) {
            revert L0Portal_InvalidLogicChainId(_dstLogicChainId);
        }

        uint32 _dstEid = logicChainIdToEid[_dstLogicChainId];
        bytes memory _options = getOptionBytes(L0_EXECUTION_GAS_LIMIT, L0_EXECUTION_MSG_VALUE);
        (_nativeFee,) = _quoteWithOptions(
            _dstEid,
            _payload,
            _options,
            false
        );
    }

    /// @notice Public function to get the next expected nonce for a given source endpoint and sender.
    function nextNonce(uint32 _srcEid, bytes32 _sender) public view override returns (uint64) {
        return receivedNonce[_srcEid][_sender] + 1;
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @notice Only vault can sends a cross-chain msg to the primary or subsidiary chain.
    /// @param _dstLogicChainId Destination chain's logicChainId.
    /// @param _payload Message payload. Encode & Decode logic is in Vault contract.
    /// @param _refundAddress Refund in case of failed message. Excessive execution fee in _option CANNOT BE REFUNDED.
    function sendMessageCrossChain(
        uint32 _dstLogicChainId,
        bytes calldata _payload,
        address payable _refundAddress
    ) external payable onlyFromVault onlyConfigured {
        if (_dstLogicChainId >= chainCnt) {
            revert L0Portal_InvalidLogicChainId(_dstLogicChainId);
        }

        uint32 _dstEid = logicChainIdToEid[_dstLogicChainId];
        bytes memory _options = getOptionBytes(L0_EXECUTION_GAS_LIMIT, L0_EXECUTION_MSG_VALUE);
        MessagingReceipt memory _receipt = _lzSend(
            _dstEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(_refundAddress)
        );
        emit LogL0MsgSent(_dstLogicChainId, _receipt.nonce, _receipt.fee.nativeFee, _payload);
    }

    function configureAll(
        address vaultProxyAddress,
        uint32[] calldata eidList
    ) external onlyOwner {
        vaultContract = IVault(vaultProxyAddress);

        chainCnt = eidList.length;
        for (uint32 _i = 0; _i < chainCnt; _i++) {
            logicChainIdToEid[_i] = eidList[_i];
            eidToLogicChainId[eidList[_i]] = uint32(_i);
        }
    }

    function setConfigured(bool _isConfigured) external onlyOwner {
        isConfigured = _isConfigured;
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Receive message with strict nonce enforcement.
    function _lzReceive(
        Origin calldata _origin,
        bytes32, //_guid
        bytes calldata _payload,
        address, //_executor
        bytes calldata //_extraData
    ) internal override onlyConfigured {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);
        uint32 _logicChainId = eidToLogicChainId[_origin.srcEid];
        if (logicChainIdToEid[_logicChainId] != _origin.srcEid) {
            revert L0Portal_InvalidOrigin(_origin.srcEid, _origin.sender);
        }

        vaultContract.receiveMessageCrossChain(
            _logicChainId,
            _payload
        );
        emit LogL0MsgReceived(_logicChainId, _origin.nonce, _payload);
    }

    /// @dev Internal quote function with option bytes.
    function _quoteWithOptions(
        uint32 _dstEid,
        bytes memory _payload,
        bytes memory _options,
        bool _payInLzToken
    ) internal view returns (uint256 _nativeFee, uint256 _zroFee) {
        MessagingFee memory fee = _quote(_dstEid, _payload, _options, _payInLzToken);
        _nativeFee = fee.nativeFee;
        _zroFee = fee.lzTokenFee;
    }

    /// @dev Internal function to accept nonce from the specified source endpoint and sender.
    function _acceptNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) internal {
        receivedNonce[_srcEid][_sender] += 1;
        if (_nonce != receivedNonce[_srcEid][_sender]) {
            revert L0Portal_InvalidNextNonce(_nonce);
        }
    }

    /// @dev Internal function to check whether it is configured.
    function _checkConfigured() internal view {
        if (!isConfigured) {
            revert L0Portal_NotConfigured();
        }
    }

    /// @dev Internal function to check whether caller is vault contract (proxy).
    function _checkFromVault() private view {
        if (msg.sender != address(vaultContract)) {
            revert L0Portal_NotFromVaultContract(msg.sender);
        }
    }
}
