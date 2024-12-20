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
import { WETH } from "lib/solmate/src/tokens/WETH.sol";
import { Token } from "src/misc/Token.sol";
import { MockCrossChainPortal } from "test/mocks/MockCrossChainPortal.sol";
import { MockSnarkVerifier } from "test/mocks/MockSnarkVerifier.sol";
import { ManagerApiLogic } from "src/vault/logic/ManagerApiLogic.sol";
import { MessageQueueLogic } from "src/vault/logic/MessageQueueLogic.sol";
import { MultiChainLogic } from "src/vault/logic/MultiChainLogic.sol";
import { TokenManagerLogic } from "src/vault/logic/TokenManagerLogic.sol";
import { Constants } from "src/vault/generic/Constants.sol";
import { DataTypes } from "src/vault/generic/DataTypes.sol";

contract ManagerApiLogicTest is ManagerApiLogic, TestBase {
    address internal operator = address(100);
    address internal user = address(101);
    address internal lp = address(102);
    WETH internal weth;
    Token internal testToken;
    MessageQueueLogic internal mqLogic;

    // used to receive eth from WETH
    receive() external payable {}

    function setUp() public virtual {
        weth = new WETH();
        wethAddress = address(weth);

        testToken = new Token(user, 10 ** 18, 12, "Token12", "T12");
        assetIdToInfo[NATIVE_ASSET_ID] = DataTypes.AssetInfo({
            assetAddress: address(0),
            limitDigit: 10,
            precisionDigit: 8,
            decimals: 18,
            isActive: true
        });
        assetIdToInfo[ERC20_ASSET_ID] = DataTypes.AssetInfo({
            assetAddress: address(testToken),
            limitDigit: 10,
            precisionDigit: 8,
            decimals: 12,
            isActive: true
        });
        assetAddressToId[address(0)] = NATIVE_ASSET_ID;
        assetAddressToId[address(testToken)] = ERC20_ASSET_ID;

        mqLogic = new MessageQueueLogic();
        messageQueueLogicAddress = address(mqLogic);
        TokenManagerLogic _tokenManagerLogic = new TokenManagerLogic();
        tokenManagerLogicAddress = address(_tokenManagerLogic);
        MultiChainLogic _multiChainLogic = new MultiChainLogic();
        multiChainLogicAddress = address(_multiChainLogic);
        MockCrossChainPortal _portal = new MockCrossChainPortal();
        crossChainPortalContract = _portal;

        // set test contract as primary chain contract, sub chain contract has partial functionality.
        MockSnarkVerifier _snarkVerifier = new MockSnarkVerifier();
        snarkVerifier = address(_snarkVerifier);
        chainCnt = 2;
        primaryLogicChainId = PRIMARY_CHAIN_ID;
    }

    function _configureAsPrimary() internal {
        logicChainId = PRIMARY_CHAIN_ID;
    }

    function _configureAsSubsidiary() internal {
        logicChainId = SUB_CHAIN_ID;
    }

    function _populatePreCommitCheckpoint() public {
        l1ToL2MessageQueueCommitIndex = 0;
        l1ToL2MessageQueueTailIndex = 2;
        l1ToL2MessageQueueHash[1] = hex"1234";  // mock
        l1ToL2MessageQueueHash[2] = hex"5678";  // mock
    }

    function test_preCommitSubChainProgress() public payable {
        _configureAsSubsidiary();
        _populatePreCommitCheckpoint();

        uint256 _expectGas = 160;
        uint256 _excessiveGas = 12345;
        vm.deal(operator, _expectGas + _excessiveGas);

        // commit: nextL1CommitIndex = 2
        vm.startPrank(operator);
        vm.expectEmit();
        emit MultiChainLogic.LogPreCommitCheckpointSent(
            SUB_CHAIN_ID,
            2,
            0,  // current L1 commit Hash is 0
            l1ToL2MessageQueueHash[2],
            0   // current L2 commit Hash is 0
        );
        this.preCommitSubChainProgress{value: _expectGas + _excessiveGas}(2);
        assertEq(_excessiveGas, operator.balance); // proper refund
        vm.stopPrank();

        // overwrite is okay: nextL1CommitIndex = 0
        vm.startPrank(operator);
        vm.expectEmit();
        emit MultiChainLogic.LogPreCommitCheckpointSent(
            SUB_CHAIN_ID,
            0,
            0,  // current L1 commit Hash is 0
            0,
            0   // current L2 commit Hash is 0
        );
        this.preCommitSubChainProgress{value: _excessiveGas}(0);
        assertEq(_excessiveGas - _expectGas, operator.balance); // proper refund
        vm.stopPrank();
    }

    function test_preCommitSubChainProgress_expectFail() public payable {
        _configureAsSubsidiary();
        _populatePreCommitCheckpoint();

        uint256 _expectGas = 160;
        uint256 _excessiveGas = 12345;
        vm.deal(operator, _expectGas + _excessiveGas);

        vm.startPrank(operator);
        // case #1: cross-chain fee fee insufficient
        vm.expectRevert(abi.encodeWithSelector(MsgValueInsufficient.selector, _expectGas, _expectGas - 1));
        this.preCommitSubChainProgress{value: _expectGas - 1}(2);

        // case #2: invalid l1 next commit index
        vm.expectRevert(L1Msg_InvalidNextL1Cp.selector);
        this.preCommitSubChainProgress{value: _expectGas + _excessiveGas}(3);
        vm.stopPrank();
    }

    function _populatePostCommitConfirmation()
        internal
        returns (bytes[] memory _l2Messages, DataTypes.PostCommitConfirmation memory _c)
    {
        _l2Messages = new bytes[](3);

        // #0: withdraw: ${user} withdraw 12345 ${NATIVE_ASSET} from ${PRIMARY_CHAIN_ID}
        _l2Messages[0] = mqLogic.encodeWithdrawMessage(0, user, uint32(NATIVE_ASSET_ID), 12345); // prevHash[0] = 0

        // #1: amm pool create
        _l2Messages[1] = mqLogic.encodeAmmPoolCreateMessage(
            keccak256(_l2Messages[0]),
            0,
            0,
            1,
            10000,
            20000,
            30000,
            10000
        );

        // #2: backfill: backfill 123456 ${NATIVE_ASSET} to LP on ${PRIMARY_CHAIN_ID}
        _l2Messages[2] = mqLogic.encodeFastWithdrawL2Message(
            keccak256(_l2Messages[1]),
            lp,
            uint32(NATIVE_ASSET_ID),
            123456
        );

        // populate postCommitConfirmation storage for next settlement
        _populatePreCommitCheckpoint();
        postCommitConfirmation = DataTypes.PostCommitConfirmation({
            logicChainId: PRIMARY_CHAIN_ID,
            l1MessageCnt: l1ToL2MessageQueueTailIndex,
            l1NextCommitHash: l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex],
            l2NextCommitHash: keccak256(_l2Messages[2])
        });
        return (_l2Messages, postCommitConfirmation);
    }

    function test_finalizePostCommitConfirmation() public payable {
        _configureAsPrimary();
        (bytes[] memory _l2Messages, DataTypes.PostCommitConfirmation memory _c) = _populatePostCommitConfirmation();
        uint256 vaultBalanceBefore = address(this).balance;
        uint256 lpBalanceBefore = weth.balanceOf(lp);

        vm.startPrank(operator);
        vm.expectEmit();
        emit LogL1ToL2MessageQueueUpdate(_c.l1MessageCnt);
        vm.expectEmit();
        emit LogNewPendingWithdrawAmount(user, NATIVE_ASSET_ID, 12345);
        vm.expectEmit();
        emit LogAmmPoolCreated(0, 0, 1, 10000, 20000, 30000, 10000);
        vm.expectEmit();
        emit LogFastWithdrawBackfill(lp, NATIVE_ASSET_ID, 123456);
        vm.expectEmit();
        emit LogL2ToL1MessageQueueUpdate(_c.l2NextCommitHash);

        this.finalizePostCommitConfirmation(_l2Messages);

        assertEq(vaultBalanceBefore - 123456, address(this).balance);
        assertEq(lpBalanceBefore + 123456, weth.balanceOf(lp));
        assertEq(postCommitConfirmation.l1MessageCnt, 0);
        vm.stopPrank();
    }

    function test_finalizePostCommitConfirmation_expectFail() public payable {
        _configureAsPrimary();
        (bytes[] memory _l2Messages, DataTypes.PostCommitConfirmation memory _c) = _populatePostCommitConfirmation();

        vm.startPrank(operator);
        // case #1: invalid l1 confirmation
        postCommitConfirmation.l1NextCommitHash = 0;
        vm.expectRevert(L1Msg_InvalidConfirmation.selector);
        this.finalizePostCommitConfirmation(_l2Messages);
        postCommitConfirmation.l1NextCommitHash = _c.l1NextCommitHash;

        // case #2: message hash not match
        postCommitConfirmation.l2NextCommitHash = 0;
        vm.expectRevert(L2Msg_MessageHashNotMatch.selector);
        this.finalizePostCommitConfirmation(_l2Messages);
        postCommitConfirmation.l2NextCommitHash = _c.l2NextCommitHash;

        vm.stopPrank();
    }

    function _calculateStateHashPublic(DataTypes.VesselState calldata _state) public pure returns (bytes32) {
        return calculateStateHash(_state);
    }

    function _prepareProofCommitForPrimaryChain()
        internal
        returns (
            uint256[] memory _instances,
            bytes memory _proof,
            DataTypes.VesselState memory _stateBefore,
            DataTypes.VesselState memory _stateAfter,
            uint256 _batchId,
            uint256 _lastEventId
        )
    {
        _populatePreCommitCheckpoint();
        preCommitCheckpointList[0] = DataTypes.PreCommitCheckpoint({
            logicChainId: 0,
            l1MessageCnt: l1ToL2MessageQueueTailIndex,
            l1LastCommitHash: 0,
            l1NextCommitHash: l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex],
            l2LastCommitHash: 0
        });
        preCommitCheckpointList[1] = DataTypes.PreCommitCheckpoint({
            logicChainId: 1,
            l1MessageCnt: 100001,           // mock
            l1LastCommitHash: 0,
            l1NextCommitHash: hex"100002",  // mock
            l2LastCommitHash: 0
        });

        _stateBefore = DataTypes.VesselState({
            eternalTreeRoot: 0,
            ephemeralTreeRoot: 0,
            l1MessageQueueHash: new bytes32[](2),
            l2MessageQueueHash: new bytes32[](2)
        });
        _stateAfter = DataTypes.VesselState({
            eternalTreeRoot: 100003,     // mock
            ephemeralTreeRoot: 100004,   // mock
            l1MessageQueueHash: new bytes32[](2),
            l2MessageQueueHash: new bytes32[](2)
        });
        _stateAfter.l1MessageQueueHash[0] = preCommitCheckpointList[0].l1NextCommitHash;
        _stateAfter.l1MessageQueueHash[1] = preCommitCheckpointList[1].l1NextCommitHash;
        _stateAfter.l2MessageQueueHash[0] = hex"100005";    // mock
        _stateAfter.l2MessageQueueHash[1] = hex"100006";    // mock

        _instances = new uint256[](14);
        _instances[12] = uint256(this._calculateStateHashPublic(_stateBefore)) % Constants.Q;
        _instances[13] = uint256(this._calculateStateHashPublic(_stateAfter)) % Constants.Q;
        _proof = hex"1234567890";   // mock
        _batchId = 1;               // mock
        _lastEventId = 1024;        // mock
    }

    function test_commitSnarkProof() public {
        _configureAsPrimary();
        (
            uint256[] memory _instances,
            bytes memory _proof,
            DataTypes.VesselState memory _stateBefore,
            DataTypes.VesselState memory _stateAfter,
            uint256 _batchId,
            uint256 _lastEventId
        ) = _prepareProofCommitForPrimaryChain();

        uint256 _expectGas = 128; // 1 cross-chain confirmation
        uint256 _excessiveGas = 12345;
        vm.deal(operator, _expectGas + _excessiveGas);

        vm.startPrank(operator);
        vm.expectEmit();
        emit LogNewEternalTreeRoot(_stateAfter.eternalTreeRoot);
        vm.expectEmit();
        emit LogNewEphemeralTreeRoot(_stateAfter.ephemeralTreeRoot);
        vm.expectEmit();
        emit MultiChainLogic.LogPostCommitConfirmationSent(
            0,
            preCommitCheckpointList[0].l1MessageCnt,
            preCommitCheckpointList[0].l1NextCommitHash,
            _stateAfter.l2MessageQueueHash[0]
        );  // confirmation on primary
        vm.expectEmit();
        emit MultiChainLogic.LogPostCommitConfirmationSent(
            1,
            preCommitCheckpointList[1].l1MessageCnt,
            preCommitCheckpointList[1].l1NextCommitHash,
            _stateAfter.l2MessageQueueHash[1]
        );  // confirmation on subsidiary
        vm.expectEmit();
        emit LogProofCommitted(_batchId, _lastEventId);

        this.commitSnarkProof{value: _expectGas + _excessiveGas}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );

        // assert all checkpoints are correctly updated
        for (uint32 _i = 0; _i < chainCnt; _i++) {
            DataTypes.PreCommitCheckpoint storage cp = preCommitCheckpointList[_i];
            assertEq(cp.logicChainId, _i);
            assertEq(cp.l1MessageCnt, 0);
            assertEq(cp.l1LastCommitHash, _stateAfter.l1MessageQueueHash[_i]);
            assertEq(cp.l2LastCommitHash, _stateAfter.l2MessageQueueHash[_i]);
        }
        // assert proper refund
        assertEq(_excessiveGas, operator.balance);
        vm.stopPrank();
    }

    function test_commitSnarkProof_expectFail() public {
        _configureAsPrimary();
        (
            uint256[] memory _instances,
            bytes memory _proof,
            DataTypes.VesselState memory _stateBefore,
            DataTypes.VesselState memory _stateAfter,
            uint256 _batchId,
            uint256 _lastEventId
        ) = _prepareProofCommitForPrimaryChain();

        uint256 _expectGas = 128; // 1 cross-chain confirmation
        uint256 _excessiveGas = 12345;
        vm.deal(operator, _expectGas + _excessiveGas);

        vm.startPrank(operator);
        // case #1: SNARKProof_InstanceNotMatch_StateBefore
        uint _tmpU256 = _instances[12];
        _instances[12] = 0;
        vm.expectRevert(abi.encodeWithSelector(
            SNARKProof_InstanceNotMatch_StateBefore.selector,
            _tmpU256,
            _instances[12]
        ));
        this.commitSnarkProof{value: _expectGas + _excessiveGas}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );
        _instances[12] = _tmpU256;

        // case #2: SNARKProof_InstanceNotMatch_StateAfter
        _tmpU256 = _instances[13];
        _instances[13] = 0;
        vm.expectRevert(abi.encodeWithSelector(
            SNARKProof_InstanceNotMatch_StateAfter.selector,
            _tmpU256,
            _instances[13]
        ));
        this.commitSnarkProof{value: _expectGas + _excessiveGas}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );
        _instances[13] = _tmpU256;

        // case #3: checkpoint not match state before - l1LastCommitHash
        bytes32 _tmpBytes32 = preCommitCheckpointList[0].l1LastCommitHash;
        preCommitCheckpointList[0].l1LastCommitHash = hex"200001";
        vm.expectRevert(SNARKProof_StateNotMatch_L1MsgQueueHashBefore.selector);
        this.commitSnarkProof{value: _expectGas + _excessiveGas}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );
        preCommitCheckpointList[0].l1LastCommitHash = _tmpBytes32;

        // case #4: checkpoint not match state before - l2LastCommitHash
        _tmpBytes32 = preCommitCheckpointList[0].l2LastCommitHash;
        preCommitCheckpointList[0].l2LastCommitHash = hex"200002";
        vm.expectRevert(SNARKProof_StateNotMatch_L2MsgQueueHashBefore.selector);
        this.commitSnarkProof{value: _expectGas + _excessiveGas}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );
        preCommitCheckpointList[0].l2LastCommitHash = _tmpBytes32;

        // case #5: checkpoint not match state after - l1NextCommitHash
        _tmpBytes32 = preCommitCheckpointList[0].l1NextCommitHash;
        preCommitCheckpointList[0].l1NextCommitHash = hex"200003";
        vm.expectRevert(SNARKProof_StateNotMatch_L1MsgQueueHashAfter.selector);
        this.commitSnarkProof{value: _expectGas + _excessiveGas}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );
        preCommitCheckpointList[0].l1NextCommitHash = _tmpBytes32;

        // case #6: cross-chain fee insufficient
        vm.expectRevert(abi.encodeWithSelector(MsgValueInsufficient.selector, _expectGas, _expectGas - 1));
        this.commitSnarkProof{value: _expectGas - 1}(
            _instances,
            _proof,
            _stateBefore,
            _stateAfter,
            _batchId,
            _lastEventId
        );

        vm.stopPrank();
    }

    function test_fastWithdraw_ERC20() public {
        // define args
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _withdrawAmount = _assetAmount - _feeAmount;
        uint256 _nonce = 999_999;

        // exitLp mint and approve ERC20 allowance to vault proxy
        vm.startPrank(lp);
        testToken.mint(_withdrawAmount);
        testToken.approve(address(this), _withdrawAmount);
        vm.stopPrank();

        // calculate expect l1->l2 msgQueue tail
        bytes32 l1Tol2TailHash = keccak256(mqLogic.encodeFastWithdrawL1Message(
            0,
            lp,
            user,
            uint32(ERC20_ASSET_ID),
            uint128(_assetAmount),
            _nonce
        ));

        // expect l1->l2 message quueue update and log emit
        vm.expectEmit();
        emit LogL1ToL2MessageQueueFastWithdraw(lp, user, ERC20_ASSET_ID, _assetAmount, _nonce, l1Tol2TailHash);

        // enforce balance change
        uint256 _userBalanceBefore = testToken.balanceOf(user);
        uint256 _lpBalanceBefore = testToken.balanceOf(lp);
        uint256 _vaultBalanceBefore = testToken.balanceOf(address(this));

        this.fastWithdraw(
            lp,
            user,
            ERC20_ASSET_ID,
            _assetAmount,
            _feeAmount,
            _nonce
        );

        assertEq(_userBalanceBefore + _withdrawAmount, testToken.balanceOf(user));
        assertEq(_lpBalanceBefore - _withdrawAmount, testToken.balanceOf(lp));
        assertEq(_vaultBalanceBefore, testToken.balanceOf(address(this)));
    }

    function test_fastWithdraw_ERC20_expectFail() public {
        // define args
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _withdrawAmount = _assetAmount - _feeAmount;
        uint256 _nonce = 999_999;

        // exitLp mint and approve ERC20 allowance to vault proxy
        vm.startPrank(lp);
        testToken.approve(address(this), _withdrawAmount);
        vm.stopPrank();

        // case #1: lp balance not enough
        // TODO: use expectPartialRevert after forge-std is upgraded
        vm.expectRevert();
        this.fastWithdraw(
            lp,
            user,
            ERC20_ASSET_ID,
            _assetAmount,
            _feeAmount,
            _nonce
        );
    }

    function test_fastWithdraw_native() public {
        // define args
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _withdrawAmount = _assetAmount - _feeAmount;
        uint256 _nonce = 999_999;

        // exitLp mint and approve WETH allowance to vault proxy
        vm.startPrank(lp);
        vm.deal(lp, _withdrawAmount);
        weth.deposit{value: _withdrawAmount}();
        weth.approve(address(this), _withdrawAmount);
        vm.stopPrank();

        // calculate expect l1->l2 msgQueue tail
        bytes32 l1Tol2TailHash = keccak256(mqLogic.encodeFastWithdrawL1Message(
            0,
            lp,
            user,
            uint32(NATIVE_ASSET_ID),
            uint128(_assetAmount),
            _nonce
        ));

        // expect l1->l2 message quueue update and log emit
        vm.expectEmit();
        emit LogL1ToL2MessageQueueFastWithdraw(lp, user, NATIVE_ASSET_ID, _assetAmount, _nonce, l1Tol2TailHash);

        // enforce balance change
        uint256 _userBalanceBefore = user.balance;
        uint256 _lpBalanceBefore = weth.balanceOf(lp);
        uint256 _vaultBalanceBefore = address(this).balance;

        this.fastWithdraw(
            lp,
            user,
            NATIVE_ASSET_ID,
            _assetAmount,
            _feeAmount,
            _nonce
        );

        assertEq(_userBalanceBefore + _withdrawAmount, user.balance);
        assertEq(_lpBalanceBefore - _withdrawAmount, weth.balanceOf(lp));
        assertEq(_vaultBalanceBefore, address(this).balance);
    }

    function test_fastWithdraw_native_expectFail() public {
        // define args
        uint256 _assetAmount = 123_456_789;
        uint256 _feeAmount = 654_321;
        uint256 _withdrawAmount = _assetAmount - _feeAmount;
        uint256 _nonce = 999_999;

        // exitLp mint and approve WETH allowance to vault proxy
        vm.startPrank(lp);
        vm.deal(lp, _withdrawAmount);
        weth.approve(address(this), _withdrawAmount);
        vm.stopPrank();

        // case #1: lp balance not enough
        // use expectPartialRevert after forge-std is upgraded
        vm.expectRevert();
        this.fastWithdraw(
            lp,
            user,
            NATIVE_ASSET_ID,
            _assetAmount,
            _feeAmount,
            _nonce
        );
    }

}
