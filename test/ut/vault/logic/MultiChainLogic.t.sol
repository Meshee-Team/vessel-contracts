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
import { MultiChainLogic } from "src/vault/logic/MultiChainLogic.sol";
import { DataTypes } from "src/vault/generic/DataTypes.sol";
import { MockCrossChainPortal } from "test/mocks/MockCrossChainPortal.sol";

contract MultiChainLogicTest is MultiChainLogic, TestBase {
    function setUp() public virtual {
        MockCrossChainPortal portal = new MockCrossChainPortal();
        crossChainPortalContract = portal;
        chainCnt = 2;
        primaryLogicChainId = PRIMARY_CHAIN_ID;
    }

    function _configureAsPrimary() internal {
        logicChainId = PRIMARY_CHAIN_ID;
    }

    function _configureAsSubsidiary() internal {
        logicChainId = SUB_CHAIN_ID;
    }

    function test_sendMessageToPrimary_sameOrigin() public {
        _configureAsPrimary();

        uint256 _l1MessageCnt = 3;
        bytes32 _l1NextCommitHash = hex"123456";
        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: PRIMARY_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1LastCommitHash: l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex],
            l1NextCommitHash: _l1NextCommitHash,
            l2LastCommitHash: l2ToL1MessageQueueCommitHash
        });

        vm.expectEmit();
        emit LogPreCommitCheckpointSent(
            PRIMARY_CHAIN_ID,
            _l1MessageCnt,
            l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex],
            _l1NextCommitHash,
            l2ToL1MessageQueueCommitHash
        );
        vm.expectEmit();
        emit LogPreCommitCheckpointReceived(
            PRIMARY_CHAIN_ID,
            _l1MessageCnt,
            l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex],
            _l1NextCommitHash,
            l2ToL1MessageQueueCommitHash
        );
        uint256 gasCost = this.sendMessageToPrimary(_cp);
        assertEq(gasCost, 0);
    }

    /// gas-not-enough-error and excessive-gas-refund is covered in ManagerApiLogicTest.
    function test_sendMessageToPrimary_crossChain() public {
        _configureAsSubsidiary();

        uint256 _l1MessageCnt = 3;
        bytes32 _l1NextCommitHash = hex"123456";
        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1LastCommitHash: l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex],
            l1NextCommitHash: _l1NextCommitHash,
            l2LastCommitHash: l2ToL1MessageQueueCommitHash
        });

        // calculate payload, quote expect gas
        bytes memory _payload = abi.encode(_cp);
        assertEq(_payload.length, 160); // 5 field * 32
        uint256 _expectGas = crossChainPortalContract.quote(primaryLogicChainId, _payload);

        // expect emit and call
        vm.expectEmit();
        emit LogPreCommitCheckpointSent(
            SUB_CHAIN_ID,
            _l1MessageCnt,
            l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex],
            _l1NextCommitHash,
            l2ToL1MessageQueueCommitHash
        );
        vm.expectEmit();
        emit MockCrossChainPortal.MockCrossChainMsgSent(PRIMARY_CHAIN_ID, _payload, _expectGas);
        uint256 _gasCost = this.sendMessageToPrimary{value: _expectGas}(_cp);
        assertEq(_gasCost, _expectGas);
    }

    function test_sendMessageToSub_sameOrigin() public {
        _configureAsPrimary();

        uint256 _l1MessageCnt = 0;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2NextCommitHash = hex"654321";
        DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
            logicChainId: PRIMARY_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1NextCommitHash: _l1NextCommitHash,
            l2NextCommitHash: _l2NextCommitHash
        });

        vm.expectEmit();
        emit LogPostCommitConfirmationSent(
            PRIMARY_CHAIN_ID,
            _l1MessageCnt,
            _l1NextCommitHash,
            _l2NextCommitHash
        );
        vm.expectEmit();
        emit LogPostCommitConfirmationReceived(
            PRIMARY_CHAIN_ID,
            _l1MessageCnt,
            _l1NextCommitHash,
            _l2NextCommitHash
        );
        uint256 gasCost = this.sendMessageToSub(_c);
        assertEq(gasCost, 0);
    }

    function test_sendMessageToSub_crossChain() public {
        _configureAsPrimary();

        uint256 _l1MessageCnt = 0;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2NextCommitHash = hex"654321";
        DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1NextCommitHash: _l1NextCommitHash,
            l2NextCommitHash: _l2NextCommitHash
        });

        // calculate payload, quote expect gas
        bytes memory _payload = abi.encode(_c);
        assertEq(_payload.length, 128); // 4 field * 32
        uint256 _expectGas = crossChainPortalContract.quote(primaryLogicChainId, _payload);

        // expect emit and call
        vm.expectEmit();
        emit LogPostCommitConfirmationSent(
            SUB_CHAIN_ID,
            _l1MessageCnt,
            _l1NextCommitHash,
            _l2NextCommitHash
        );
        vm.expectEmit();
        emit MockCrossChainPortal.MockCrossChainMsgSent(SUB_CHAIN_ID, _payload, _expectGas);
        uint256 _gasCost = this.sendMessageToSub{value: _expectGas}(_c);
        assertEq(_gasCost, _expectGas);
    }

    function test_receiveMessageFromSub() public {
        _configureAsPrimary();

        uint256 _l1MessageCnt = 3;
        bytes32 _l1LastCommitHash = 0;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2LastCommitHash = 0;
        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1LastCommitHash: _l1LastCommitHash,
            l1NextCommitHash: _l1NextCommitHash,
            l2LastCommitHash: _l2LastCommitHash
        });
        bytes memory _payload = abi.encode(_cp);

        // expect emit and call
        vm.expectEmit();
        emit LogPreCommitCheckpointReceived(
            SUB_CHAIN_ID,
            _l1MessageCnt,
            _l1LastCommitHash,
            _l1NextCommitHash,
            _l2LastCommitHash
        );
        this.receiveMessage(SUB_CHAIN_ID, _payload);
        assertEq(abi.encode(_cp), abi.encode(preCommitCheckpointList[SUB_CHAIN_ID]));
    }

    function test_receiveMessageFromSub_overwrite() public {
        _configureAsPrimary();

        // first cp
        uint256 _l1MessageCnt = 3;
        bytes32 _l1LastCommitHash = 0;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2LastCommitHash = 0;
        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1LastCommitHash: _l1LastCommitHash,
            l1NextCommitHash: _l1NextCommitHash,
            l2LastCommitHash: _l2LastCommitHash
        });
        bytes memory _payload = abi.encode(_cp);
        this.receiveMessage(SUB_CHAIN_ID, _payload);

        // overwrite first cp
        _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt + 1,
            l1LastCommitHash: _l1LastCommitHash,
            l1NextCommitHash: hex"7890",
            l2LastCommitHash: _l2LastCommitHash
        });
        _payload = abi.encode(_cp);

        vm.expectEmit();
        emit LogPreCommitCheckpointReceived(
            SUB_CHAIN_ID,
            _l1MessageCnt + 1,
            _l1LastCommitHash,
            bytes32(hex"7890"),
            _l2LastCommitHash
        );
        this.receiveMessage(SUB_CHAIN_ID, _payload);

        // storage reflects the latest cp
        assertEq(abi.encode(_cp), abi.encode(preCommitCheckpointList[SUB_CHAIN_ID]));
    }

    function test_receiveMessageFromSub_expectFail_invalidOrigin() public {
        _configureAsPrimary();

        uint256 _l1MessageCnt = 3;
        bytes32 _l1LastCommitHash = 0;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2LastCommitHash = 0;
        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1LastCommitHash: _l1LastCommitHash,
            l1NextCommitHash: _l1NextCommitHash,
            l2LastCommitHash: _l2LastCommitHash
        });
        bytes memory _payload = abi.encode(_cp);

        // expect revert and call
        vm.expectRevert(Multi_InvalidMessageOrigin.selector);
        this.receiveMessage(3, _payload);
    }

    function test_receiveMessageFromSub_expectFail_invalidCheckpoint() public {
        _configureAsPrimary();

        uint256 _l1MessageCnt = 3;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2LastCommitHash = 0;
        DataTypes.PreCommitCheckpoint memory _cp = DataTypes.PreCommitCheckpoint({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1LastCommitHash: hex"654321",
            l1NextCommitHash: _l1NextCommitHash,
            l2LastCommitHash: _l2LastCommitHash
        });
        bytes memory _payload = abi.encode(_cp);

        // expect revert and call
        vm.expectRevert(Multi_InvalidCheckpoint.selector);
        this.receiveMessage(SUB_CHAIN_ID, _payload);
    }

    function test_receiveMessageFromPrimary() public {
        _configureAsSubsidiary();

        uint256 _l1MessageCnt = 5;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2NextCommitHash = hex"654321";
        DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1NextCommitHash: _l1NextCommitHash,
            l2NextCommitHash: _l2NextCommitHash
        });
        bytes memory _payload = abi.encode(_c);

        // expect emit and call
        vm.expectEmit();
        emit LogPostCommitConfirmationReceived(
            SUB_CHAIN_ID,
            _l1MessageCnt,
            _l1NextCommitHash,
            _l2NextCommitHash
        );
        this.receiveMessage(PRIMARY_CHAIN_ID, _payload);
        assertEq(abi.encode(_c), abi.encode(postCommitConfirmation));
    }

    function test_receiveMessageFromPrimary_expectFail_invalidOrigin() public {
        _configureAsSubsidiary();

        uint256 _l1MessageCnt = 5;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2NextCommitHash = hex"654321";
        DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1NextCommitHash: _l1NextCommitHash,
            l2NextCommitHash: _l2NextCommitHash
        });
        bytes memory _payload = abi.encode(_c);

        // expect emit and call
        vm.expectRevert(Multi_InvalidMessageOrigin.selector);
        this.receiveMessage(3, _payload);
    }

    function test_receiveMessageFromPrimary_expectFail_invalidChainId() public {
        _configureAsSubsidiary();

        uint256 _l1MessageCnt = 5;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2NextCommitHash = hex"654321";
        DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
            logicChainId: PRIMARY_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1NextCommitHash: _l1NextCommitHash,
            l2NextCommitHash: _l2NextCommitHash
        });
        bytes memory _payload = abi.encode(_c);

        // expect emit and call
        vm.expectRevert(Multi_InvalidLogicChainId.selector);
        this.receiveMessage(PRIMARY_CHAIN_ID, _payload);
    }

    function test_receiveMessageFromPrimary_expectFail_invalidConfirmation() public {
        _configureAsSubsidiary();

        uint256 _l1MessageCnt = 5;
        bytes32 _l1NextCommitHash = hex"123456";
        bytes32 _l2NextCommitHash = hex"654321";
        DataTypes.PostCommitConfirmation memory _c = DataTypes.PostCommitConfirmation({
            logicChainId: SUB_CHAIN_ID,
            l1MessageCnt: _l1MessageCnt,
            l1NextCommitHash: _l1NextCommitHash,
            l2NextCommitHash: _l2NextCommitHash
        });
        bytes memory _payload = abi.encode(_c);

        // expect revert on pending l2 commit
        postCommitConfirmation.l2NextCommitHash = hex"1234"; 
        vm.expectRevert(Multi_InvalidConfirmation.selector);
        this.receiveMessage(PRIMARY_CHAIN_ID, _payload);
        postCommitConfirmation.l2NextCommitHash = 0;

        // expect revert on pending l1 commit
        postCommitConfirmation.l1MessageCnt = 1; 
        vm.expectRevert(Multi_InvalidConfirmation.selector);
        this.receiveMessage(PRIMARY_CHAIN_ID, _payload);
    }
}