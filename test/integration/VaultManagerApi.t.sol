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

import { IntegrationBase } from "test/integration/IntegrationBase.t.sol";
import { MockCrossChainPortal } from "test/mocks/MockCrossChainPortal.sol"; 
import { Constants } from "src/vault/generic/Constants.sol";
import { DataTypes } from "src/vault/generic/DataTypes.sol";
import { Configuration } from "src/vault/Configuration.sol";
import { Governance } from "src/vault/Governance.sol";
import { ManagerApiLogic } from "src/vault/logic/ManagerApiLogic.sol";
import { MultiChainLogic } from "src/vault/logic/MultiChainLogic.sol";

contract VaultManagerApi is IntegrationBase {
    function setUp() public virtual {
        deployAndConfigureAll();
    }

    function test_accessControl() public {
        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        vaults[0].preCommitSubChainProgress(0);
        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        vaults[0].finalizePostCommitConfirmation(new bytes[](0));
        vm.expectRevert(Configuration.Config_NotFromCrossChainPortal.selector);
        vaults[0].receiveMessageCrossChain(0, hex"");
        vm.expectRevert(Governance.Gov_CallerNotOperator.selector);
        DataTypes.VesselState memory _emptyState;
        vaults[0].commitSnarkProof(new uint256[](0), hex"", _emptyState, _emptyState, 0, 0);
        vm.expectRevert(Governance.Gov_CallerNotExitManager.selector);
        vaults[0].fastWithdraw(address(0), address(0), address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_configure() public {
        vm.prank(admin);
        vaults[0].setConfigured(false);

        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].preCommitSubChainProgress(0);
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].finalizePostCommitConfirmation(new bytes[](0));
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].receiveMessageCrossChain(0, hex"");
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        DataTypes.VesselState memory _emptyState;
        vaults[0].commitSnarkProof(new uint256[](0), hex"", _emptyState, _emptyState, 0, 0);
        vm.expectRevert(Configuration.Config_VaultNotConfigured.selector);
        vaults[0].fastWithdraw(address(0), address(0), address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function _performUserActions()
        internal
        returns
        (bytes[] memory _l2MessagesVault0, bytes[] memory _l2MessagesVault1)
    {
        uint256 _amount = 120_000_000_000;

        vm.startPrank(users[0]);
        vm.deal(users[0], 2 * _amount);
        testToken.mint(_amount);
        testToken.approve(address(vaults[1]), _amount);
        vaults[0].registerUser(
            vesselKeys[0],
            operator,
            uint8(registerSigs[0][64]),
            bytes32(slice(registerSigs[0], 0, 32)),
            bytes32(slice(registerSigs[0], 32, 64))
        );
        vaults[0].depositNative{value: _amount}();
        assertEq(vaults[0].l1ToL2MessageQueueTailIndex(), 2);

        vaults[1].registerAndDepositNative{value: _amount}(
            vesselKeys[0],
            operator,
            uint8(registerSigs[0][64]),
            bytes32(slice(registerSigs[0], 0, 32)),
            bytes32(slice(registerSigs[0], 32, 64))
        );
        vaults[1].depositERC20(ERC20_ASSET_ID, _amount);
        assertEq(vaults[1].l1ToL2MessageQueueTailIndex(), 3);
        vm.stopPrank();

        _l2MessagesVault0 = new bytes[](2);
        // #0: withdraw: ${user[1]} withdraw ${_amount} ${NATIVE_ASSET}
        _l2MessagesVault0[0] = messageQueueLogic.encodeWithdrawMessage(
            0,
            users[1],
            uint32(NATIVE_ASSET_ID),
            uint128(_amount)
        );
        // #1: amm pool create
        _l2MessagesVault0[1] = messageQueueLogic.encodeAmmPoolCreateMessage(
            keccak256(_l2MessagesVault0[0]),
            0,
            0,
            1,
            10000,
            20000,
            30000,
            10000
        );

        _l2MessagesVault1 = new bytes[](1);
        // #0: backfill: backfill ${_amount} ${NATIVE_ASSET} to LP
        _l2MessagesVault1[0] = messageQueueLogic.encodeFastWithdrawL2Message(
            0,
            lp,
            uint32(NATIVE_ASSET_ID),
            uint128(_amount)
        );
    }

    function _preCommit() internal {
        // step #1: precommit progress of chain 0 and chain 1.
        // Precommit chain 0 will not incur cross-chain msg.
        // Precommit chain 1 will incur cross-chain smg.
        DataTypes.PreCommitCheckpoint memory _expectCp0 = DataTypes.PreCommitCheckpoint({
            logicChainId: 0,
            l1MessageCnt: 2,
            l1LastCommitHash: 0,
            l1NextCommitHash: vaults[0].l1ToL2MessageQueueHash(2),
            l2LastCommitHash: 0
        });
        vm.expectEmit();
        emit MultiChainLogic.LogPreCommitCheckpointReceived(
            _expectCp0.logicChainId,
            _expectCp0.l1MessageCnt,
            _expectCp0.l1LastCommitHash,
            _expectCp0.l1NextCommitHash,
            _expectCp0.l2LastCommitHash
        );
        vm.prank(operator);
        vaults[0].preCommitSubChainProgress(2);

        DataTypes.PreCommitCheckpoint memory _expectCp1 = DataTypes.PreCommitCheckpoint({
            logicChainId: 1,
            l1MessageCnt: 3,
            l1LastCommitHash: 0,
            l1NextCommitHash: vaults[1].l1ToL2MessageQueueHash(3),
            l2LastCommitHash: 0
        });
        bytes memory _payload = abi.encode(_expectCp1);
        uint256 _crossChainFee = vaults[1].crossChainPortalContract().quote(0, _payload);
        vm.expectEmit();
        emit MockCrossChainPortal.MockCrossChainMsgSent(0, _payload, _crossChainFee);
        vm.prank(operator);
        vaults[1].preCommitSubChainProgress{value: operator.balance}(3);
        
        // step #2: manually receive cross-chain precommit msg sent from 1 to 0.
        vm.expectEmit();
        emit MultiChainLogic.LogPreCommitCheckpointReceived(
            _expectCp1.logicChainId,
            _expectCp1.l1MessageCnt,
            _expectCp1.l1LastCommitHash,
            _expectCp1.l1NextCommitHash,
            _expectCp1.l2LastCommitHash
        );
        vm.prank(address(vaults[0].crossChainPortalContract()));
        vaults[0].receiveMessageCrossChain(1, _payload);
    }

    function _commit(bytes32 _l2MsgQueueHashVault0, bytes32 _l2MsgQueueHashVault1) internal {
        // step #3: commit SNARK proof matches the precommit progress
        // Will incur 1 cross-chain msg from 0 to 1.
        DataTypes.VesselState memory _stateBefore = DataTypes.VesselState({
            eternalTreeRoot: 0,
            ephemeralTreeRoot: 0,
            l1MessageQueueHash: new bytes32[](2),
            l2MessageQueueHash: new bytes32[](2)
        });
        DataTypes.VesselState memory _stateAfter = DataTypes.VesselState({
            eternalTreeRoot: 123456,
            ephemeralTreeRoot: 654321,
            l1MessageQueueHash: new bytes32[](2),
            l2MessageQueueHash: new bytes32[](2)
        });
        _stateAfter.l1MessageQueueHash[0] = vaults[0].l1ToL2MessageQueueHash(2);
        _stateAfter.l1MessageQueueHash[1] = vaults[1].l1ToL2MessageQueueHash(3);
        _stateAfter.l2MessageQueueHash[0] = _l2MsgQueueHashVault0;
        _stateAfter.l2MessageQueueHash[1] = _l2MsgQueueHashVault1;
        uint256[] memory _instances = new uint256[](14);
        _instances[12] = uint256(managerApiLogic.calculateStateHash(_stateBefore)) % Constants.Q;
        _instances[13] = uint256(managerApiLogic.calculateStateHash(_stateAfter)) % Constants.Q;

        // intra-chain confirmation
        DataTypes.PostCommitConfirmation memory _expectC0 = DataTypes.PostCommitConfirmation({
            logicChainId: 0,
            l1MessageCnt: 2,
            l1NextCommitHash: _stateAfter.l1MessageQueueHash[0],
            l2NextCommitHash: _stateAfter.l2MessageQueueHash[0]
        });

        // inter-chain confirmation
        DataTypes.PostCommitConfirmation memory _expectC1 = DataTypes.PostCommitConfirmation({
            logicChainId: 1,
            l1MessageCnt: 3,
            l1NextCommitHash: _stateAfter.l1MessageQueueHash[1],
            l2NextCommitHash: _stateAfter.l2MessageQueueHash[1]
        });
        bytes memory _payload = abi.encode(_expectC1);
        uint256 _crossChainFee = vaults[0].crossChainPortalContract().quote(0, _payload);

        vm.expectEmit();
        emit MultiChainLogic.LogPostCommitConfirmationReceived(
            _expectC0.logicChainId,
            _expectC0.l1MessageCnt,
            _expectC0.l1NextCommitHash,
            _expectC0.l2NextCommitHash
        );
        vm.expectEmit();
        emit MockCrossChainPortal.MockCrossChainMsgSent(1, _payload, _crossChainFee);
        vm.expectEmit();
        emit ManagerApiLogic.LogProofCommitted(123, 45);
        vm.prank(operator);
        vaults[0].commitSnarkProof{value: _crossChainFee}(
            _instances,
            hex"",
            _stateBefore,
            _stateAfter,
            123,
            45
        );

        // step #4: manually receive cross-chain postcommit msg sent from 0 to 1.
        vm.expectEmit();
        emit MultiChainLogic.LogPostCommitConfirmationReceived(
            _expectC1.logicChainId,
            _expectC1.l1MessageCnt,
            _expectC1.l1NextCommitHash,
            _expectC1.l2NextCommitHash
        );
        vm.prank(address(vaults[1].crossChainPortalContract()));
        vaults[1].receiveMessageCrossChain(0, _payload);
    }

    function _postCommit(bytes[] memory _l2MessagesVault0, bytes[] memory _l2MessagesVault1) internal {
        // step #5: finalizePostCommitConfirmation for chain 0 and 1.
        vm.expectEmit();
        emit ManagerApiLogic.LogL1ToL2MessageQueueUpdate(2);
        vm.expectEmit();
        emit ManagerApiLogic.LogL2ToL1MessageQueueUpdate(keccak256(_l2MessagesVault0[1]));
        vm.prank(operator);
        vaults[0].finalizePostCommitConfirmation(_l2MessagesVault0);

        vm.expectEmit();
        emit ManagerApiLogic.LogL1ToL2MessageQueueUpdate(3);
        vm.expectEmit();
        emit ManagerApiLogic.LogL2ToL1MessageQueueUpdate(keccak256(_l2MessagesVault1[0]));
        vm.prank(operator);
        vaults[1].finalizePostCommitConfirmation(_l2MessagesVault1);
    }

    function test_commitFlow() public {
        vm.deal(operator, 1 ether);
        (
            bytes[] memory _l2MessagesVault0,
            bytes[] memory _l2MessagesVault1
        ) = _performUserActions();
        _preCommit();
        _commit(keccak256(_l2MessagesVault0[1]), keccak256(_l2MessagesVault1[0]));
        _postCommit(_l2MessagesVault0, _l2MessagesVault1);
    }
}