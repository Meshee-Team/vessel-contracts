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

import { console2 } from "forge-std/console2.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import { Origin } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { PacketV1Codec } from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/PacketV1Codec.sol";
import {
    EndpointV2Mock as EndpointV2
} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";
import { LayerZeroPortal } from "src/affiliate/LayerZeroPortal.sol";
import { TestBase } from "test/utils/TestBase.sol";
import { MockVault } from "test/mocks/MockVault.sol";

/// @dev check out examples under lib/devtools/packages/oapp-evm/test/OApp.t.sol
contract LayerZeroPortalTest is TestBase, TestHelperOz5 {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    using PacketV1Codec for bytes;

    error NoPeer(uint32);
    error OwnableUnauthorizedAccount(address);
    error LZ_InsufficientFee(
        uint256 requiredNative,
        uint256 suppliedNative,
        uint256 requiredLzToken,
        uint256 suppliedLzToken
    );

    uint32 internal eidA = 1;
    uint32 internal eidB = 2;
    uint32 internal chainA = 0;
    uint32 internal chainB = 1;
    LayerZeroPortal internal portalA;
    LayerZeroPortal internal portalB;
    MockVault internal vaultA;
    MockVault internal vaultB;
    address internal owner = address(0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC);
    address internal refundAddr = address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd);

    function setUp() public override {
        // 1. setup mock vault
        vaultA = new MockVault();
        vaultB = new MockVault();

        // 2. setup mock endpoints
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // 3. setup portals and wire them together
        portalA = new LayerZeroPortal(endpoints[eidA]);
        portalA.initialize(owner);
        portalB = new LayerZeroPortal(endpoints[eidB]);
        portalB.initialize(owner);

        address[] memory _portals = new address[](2);
        _portals[0] = address(portalA);
        _portals[1] = address(portalB);
        vm.startPrank(owner);
        wireOApps(_portals);

        // 4. configure portals
        uint32[] memory _eidList = new uint32[](2);
        _eidList[0] = eidA;
        _eidList[1] = eidB;
        portalA.configureAll(address(vaultA), _eidList);
        portalA.setConfigured(true);
        portalB.configureAll(address(vaultB), _eidList);
        portalB.setConfigured(true);
        vm.stopPrank();
    }

    function test_getOptionBytes() public {
        bytes memory _expect = hex"00030100110100000000000000000000000000000000";
        bytes memory _actual = portalA.getOptionBytes(0, 0);
        assertEq(_expect, _actual);
    }

    function test_quote() public {
        bytes memory _payload = hex"01020304";
        
        // cross from chain 0 to chain 1
        uint256 _quote = portalA.quote(chainB, _payload);
        console2.log(string.concat("quote:", vm.toString(_quote)));

        // send message from chain 0 to chain 0 will revert
        vm.expectRevert(abi.encodeWithSelector(NoPeer.selector, 1));
        portalA.quote(chainA, _payload);

        // invalid chain id
        vm.expectRevert(abi.encodeWithSelector(LayerZeroPortal.L0Portal_InvalidLogicChainId.selector, 2));
        portalA.quote(2, _payload);
    }

    function test_setConfigured() public {
        // only owner can toggle portal as configured
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        portalA.setConfigured(false);

        // set to un-configured state
        vm.prank(owner);
        portalA.setConfigured(false);

        // send message will revert for un-configured portal
        vm.expectRevert(LayerZeroPortal.L0Portal_NotConfigured.selector);
        vm.prank(address(vaultA));
        portalA.sendMessageCrossChain(chainB, hex"01", payable(address(vaultA)));
    }

    function test_sendMessageCrossChain() public {
        // step #1: quote L0 gas with default config
        bytes memory _payload = hex"01020304";
        uint256 _quote = portalA.quote(chainB, _payload);

        // send message from non-vault will revert
        vm.expectRevert(abi.encodeWithSelector(LayerZeroPortal.L0Portal_NotFromVaultContract.selector, address(this)));
        portalA.sendMessageCrossChain(chainB, _payload, payable(refundAddr));

        // send message without enough gas will revert and not change balance
        vm.deal(address(vaultA), 10 ether);
        uint256 _vaultBalanceBefore = address(vaultA).balance;
        uint256 _refundAddrBalanceBefore = refundAddr.balance;
        uint256 _insufficientL0Gas = 100;
        vm.expectRevert(abi.encodeWithSelector(LZ_InsufficientFee.selector, _quote, _insufficientL0Gas, 0, 0));
        vm.prank(address(vaultA));
        portalA.sendMessageCrossChain{value: _insufficientL0Gas}(chainB, _payload, payable(refundAddr));
        assertEq(_vaultBalanceBefore, address(vaultA).balance);
        assertEq(_refundAddrBalanceBefore, refundAddr.balance);

        // step #2: send message with excessive gas will refund to refundAddr
        uint256 _excessiveL0Gas = _quote + 100;
        vm.prank(address(vaultA));
        vm.expectEmit();
        emit LayerZeroPortal.LogL0MsgSent(chainB, 1, _quote, _payload);
        portalA.sendMessageCrossChain{value: _excessiveL0Gas}(chainB, _payload, payable(refundAddr));
        assertEq(_vaultBalanceBefore - _excessiveL0Gas, address(vaultA).balance);
        assertEq(_refundAddrBalanceBefore + (_excessiveL0Gas - _quote), refundAddr.balance);
        
        // step #3: mock verify the packet received on eid=2(chainId=1)
        bytes32 _dstAddr = _addressToBytes32(address(portalB));
        DoubleEndedQueue.Bytes32Deque storage packetsQueue = packetsQueue[eidB][_dstAddr];
        assertEq(packetsQueue.length(), 1);
        bytes32 _guid = packetsQueue.popBack();
        bytes memory _packetBytes = packets[_guid];
        this.assertGuid(_packetBytes, _guid);
        this.validatePacket(_packetBytes, bytes(""));

        // check and overwrite _gas to avoid OOG
        bytes memory _options = optionsLookup[_guid];
        (uint256 _gas, uint256 _value) = _parseExecutorLzReceiveOption(_options);
        assertEq(_gas, portalA.L0_EXECUTION_GAS_LIMIT());
        assertEq(_value, portalB.L0_EXECUTION_MSG_VALUE());
        vm.expectEmit();
        emit MockVault.MockCrossChainMsgReceived(chainA, _payload);
        vm.expectEmit();
        emit LayerZeroPortal.LogL0MsgReceived(chainA, 1, _payload);
        this._mockLzReceiveOverrideOptions(_packetBytes);
    }

    function test_sendMessageCrossChain_expectFail_invalidOrigin() public {
        // tweak configured chainInfo map
        uint32[] memory _eidList = new uint32[](2);
        _eidList[0] = eidB; // bad eid
        _eidList[1] = eidB;
        vm.prank(owner);
        portalB.configureAll(address(vaultB), _eidList);

        // step #1: quote L0 gas with default config
        bytes memory _payload = hex"01020304";
        uint256 _quote = portalA.quote(chainB, _payload);

        // step #2: send message with excessive gas will refund to refundAddr
        uint256 _excessiveL0Gas = _quote + 100;
        vm.deal(address(vaultA), 10 ether);
        vm.prank(address(vaultA));
        portalA.sendMessageCrossChain{value: _excessiveL0Gas}(chainB, _payload, payable(refundAddr));
        
        // step #3: mock verify the packet received on eid=2(chainId=1)
        bytes32 _dstAddr = _addressToBytes32(address(portalB));
        DoubleEndedQueue.Bytes32Deque storage packetsQueue = packetsQueue[eidB][_dstAddr];
        assertEq(packetsQueue.length(), 1);
        bytes32 _guid = packetsQueue.popBack();
        bytes memory _packetBytes = packets[_guid];
        this.assertGuid(_packetBytes, _guid);
        this.validatePacket(_packetBytes, bytes(""));

        // expect revert due to inconsistent origin
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroPortal.L0Portal_InvalidOrigin.selector,
                eidA,
                _addressToBytes32(address(portalA))
            )
        );
        this._mockLzReceiveOverrideOptions(_packetBytes);
    }

    function test_sendMessageCrossChain_expectFail_invalidNonce() public {
        // step #1: quote L0 gas with default config
        bytes memory _payload = hex"01020304";
        uint256 _quote = portalA.quote(chainB, _payload);

        // step #2: send message TWICE
        uint256 _excessiveL0Gas = _quote + 100;
        vm.deal(address(vaultA), 10 ether);
        vm.startPrank(address(vaultA));
        portalA.sendMessageCrossChain{value: _excessiveL0Gas}(chainB, _payload, payable(refundAddr));
        portalA.sendMessageCrossChain{value: _excessiveL0Gas}(chainB, _payload, payable(refundAddr));
        vm.stopPrank();

        // step #3: mock verify the packet received on eid=2(chainId=1)
        bytes32 _dstAddr = _addressToBytes32(address(portalB));
        DoubleEndedQueue.Bytes32Deque storage packetsQueue = packetsQueue[eidB][_dstAddr];
        assertEq(packetsQueue.length(), 2);

        // validate all packaets and get the last one
        bytes memory _lastPacketBytes;
        for (uint256 _i = 0; _i < 2; _i++) {
            bytes32 _guid = packetsQueue.popBack();
            _lastPacketBytes = packets[_guid];
            this.assertGuid(_lastPacketBytes, _guid);
            this.validatePacket(_lastPacketBytes, bytes(""));

        }

        // expect revert due to invalid nonce
        vm.expectRevert(abi.encodeWithSelector(LayerZeroPortal.L0Portal_InvalidNextNonce.selector, 2));
        this._mockLzReceiveOverrideOptions(_lastPacketBytes);
    }

    // have to use this helper function to convert bytes memory to calldata
    function _mockLzReceiveOverrideOptions(bytes calldata _packetBytes) external {
        // trigger endpoint lzReceive method as mock execution
        EndpointV2 _endpoint = EndpointV2(endpoints[_packetBytes.dstEid()]);
        Origin memory _origin = Origin(_packetBytes.srcEid(), _packetBytes.sender(), _packetBytes.nonce());
        _endpoint.lzReceive{ value: 0 }(
            _origin,
            _packetBytes.receiverB20(),
            _packetBytes.guid(),
            _packetBytes.message(),
            bytes("")
        );
    }
}