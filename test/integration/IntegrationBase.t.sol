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
import {
    TransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TestBase } from "test/utils/TestBase.sol";
import { DataTypes } from "src/vault/generic/DataTypes.sol";
import { WETH } from "lib/solmate/src/tokens/WETH.sol";
import { Token } from "src/misc/Token.sol";
import { Vault } from "src/vault/Vault.sol";
import { ManagerApiLogic } from "src/vault/logic/ManagerApiLogic.sol";
import { MessageQueueLogic } from "src/vault/logic/MessageQueueLogic.sol";
import { MultiChainLogic } from "src/vault/logic/MultiChainLogic.sol";
import { UserApiLogic } from "src/vault/logic/UserApiLogic.sol";
import { TokenManagerLogic } from "src/vault/logic/TokenManagerLogic.sol";
import { MockCrossChainPortal } from "test/mocks/MockCrossChainPortal.sol";
import { MockSnarkVerifier } from "test/mocks/MockSnarkVerifier.sol";

contract IntegrationBase is TestBase {
    MessageQueueLogic internal messageQueueLogic;
    ManagerApiLogic internal managerApiLogic;

    address internal admin = address(100);
    address internal operator = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
    address internal exitManager = address(101);
    address internal lp = address(102);
    WETH internal weth;
    Token internal testToken;
    Vault[2] internal vaults;
    address[10] internal users;
    bytes[10] internal vesselKeys;
    bytes[10] internal registerSigs;

    function deployAndConfigureAll() public {
        console2.log("deploy and configure all components for integration tests.");
        weth = new WETH();
        testToken = new Token(admin, 10 ** 18, 12, "Token12", "T12");

        // create vault contract behind proxy
        for (uint32 _i = 0; _i < 2; _i++) {
            Vault _vaultImpl = new Vault();
            bytes memory _initData = abi.encodeWithSignature("initialize_v2(address)", admin);
            TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(address(_vaultImpl), admin, _initData);
            vaults[_i] = Vault(payable(address(_proxy)));
        }

        // create logic contracts
        managerApiLogic = new ManagerApiLogic();
        messageQueueLogic = new MessageQueueLogic();
        MultiChainLogic _multiChainLogic = new MultiChainLogic();
        UserApiLogic _userApiLogic = new UserApiLogic();
        TokenManagerLogic _tokenManagerLogic = new TokenManagerLogic();

        // create mocks
        MockCrossChainPortal _mockCrossChainPortal = new MockCrossChainPortal();
        MockSnarkVerifier _mockSnarkVerifier = new MockSnarkVerifier();

        for (uint32 _i = 0; _i < 2; _i++) {
            // configure vault
            vm.startPrank(admin);
            vaults[_i].configureAll(
                address(weth),
                address(_userApiLogic),
                address(managerApiLogic),
                address(messageQueueLogic),
                address(_tokenManagerLogic),
                address(_multiChainLogic),
                address(_mockCrossChainPortal),
                _i,
                PRIMARY_CHAIN_ID,
                2,
                new DataTypes.PreCommitCheckpoint[](0)
            );
            vaults[_i].updateSnarkVerifierAddress(address(_mockSnarkVerifier));

            vaults[_i].registerOperator(operator);
            vaults[_i].registerExitManager(exitManager);
            vaults[_i].setConfigured(true);
            vm.stopPrank();

            // register assets and set active
            vm.startPrank(operator);
            vaults[_i].registerNewAsset(address(testToken), 1, 12, 6, testToken.decimals());
            vaults[_i].setAssetActive(0);
            vaults[_i].setAssetActive(1);
            vm.stopPrank();
        }

        // create users
        createUsers();
    }

    function createUsers() public {
        string memory _mnemonic = "test test test test test test test test test test test junk";
        uint32 _offset = 100;
        bytes32 _domainSeparatorValue = hex"f2a4c168be0c2249823a8f04624029d5973614a8b0b2e0473e0eb55224a1d76b";

        for (uint32 _i = 0; _i < 2; _i++) {
            setDomainSeparator(address(vaults[_i]), _domainSeparatorValue);
        }

        for (uint32 _i = 0; _i < 10; _i++) {
            uint256 _sk;
            (users[_i], _sk) = deriveRememberKey({ mnemonic: _mnemonic, index: _i + _offset });
        }

        /* solhint-disable */
        vesselKeys[0] =
            hex"4d12f8f99cf20c54505146f194f7906a970443ad8ffc6ae6ba79323fb15ff228af256753eefdca0c441283499d9d49a0a7409812eed27a1283b2b5370c685a2d";
        vesselKeys[1] =
            hex"afc714f95da0438f17a8599d6e42dce4267124b4a5ceb4b2a3a54d2d73c11e4429ea5fdf2bc71623c6a287846494f337fc5c9b134b67b8c1276366008293377d";
        vesselKeys[2] =
            hex"65ad0fc667ba518c25f2fda675fc3c3a22b01f44917065c5500a29cf11bfa2f8aaf5b2adaec2f9f8ee2522eb7c93d2452fb6b9a93772145ccf1b25edd47bd298";
        vesselKeys[3] =
            hex"0b02cb7be0cf65e0e51bd112b1dc5a228eb9fc44d008bd4ba4a038f2569f3266f5705b84eb3035d805b9372a4683e09bff06a505b0e0fce98ca52479d67f5c40";
        vesselKeys[4] =
            hex"477fdfcfda0af781337b990b37aa2a3a9257194ce491ff307e90966686cb40898a2e7c285cb19ac6c790b384ee712b522592b739defa62d7f72232dbef118525";
        vesselKeys[5] =
            hex"866196f9e06dbea3e3e79da04b933b7fe059f60843cab03ae6fe077ffdbc8645a8d10fc5a84a623e1bf2c3a72d61315299f428e94759eb5fcc4a2e86b06704fc";
        vesselKeys[6] =
            hex"ed7192de943b0a27520ebe3f4c47e9289a1bfbe736d313f1cea00322ccb51c6f276ac49bf2808f98e10696014d6b60504507347cfa6e2b42096df8a65f0d81d1";
        vesselKeys[7] =
            hex"a29c2e2e170818db4a9c86b31ce54e4d20aafffa8b9a3c71fe041c1fe77dbf8aee3e8e299d38811343d754d102a4b5dba6277c7b94672e1a695fac5ba395ba58";
        vesselKeys[8] =
            hex"562bb4aabdedf01fd3304ef99586a56b6099c613f81f657fc8d4d897f5cf8604165d5a25859f847ee3671568664c43e489966e0221cf3b1ee3d2587cae0f8462";
        vesselKeys[9] =
            hex"43e7f1febb50bc670588661984ded7d9450942ef25cc49abaf89652075d0176c84af864e526992156d6132af5547b15bdf53dec37efac8c7635252dc3ee92ae6";

        registerSigs[0] =
            hex"1d17bdf0e8dc919883603f0af2b72c08676a1e5dfec1c0d8b8587ee9ffa4a17745c21e624ced48331586053dbf59cc17f17be2c6878aaacced6d9ad8ca572f471c";
        registerSigs[1] =
            hex"a0570ec85b5d4622385b91a9cf45017fba63cb90860bd94a8decf534fb1eab8a4f0da2848a0c29bf616e6c970b04cc9017f375e9412a296e38b34824662428b91c";
        registerSigs[2] =
            hex"aa9e91ffe75eecd8c474c22799de62d03daad6bf1a155f0af17081ee07e735656b3f3fae05475a729470c4f8f70306325ce94c6b4c21c4409097570be89008db1c";
        registerSigs[3] =
            hex"14264334e4be86ea96d31f89a42a6353a499dc8d65b71853897e9deba26e1907068661972e6e9f10698908b2427c68ee6e1960d0f2fedb0fc4451d4dba8c96bc1b";
        registerSigs[4] =
            hex"31065872c35970d770ea629c05e775075904eaabfb41bdab9204ebb5cf78ea1544e7fad6b281d2b4dc9c17477a05234da67819aa1225dbb99fc5e6bcdd45c0d41b";
        registerSigs[5] =
            hex"12c7939450f0390340601e85db79bf1c96927d6e7bf34c2d16a2868151a1a76a0076f0a20770d143b2c073c916547204536accbf8d9f88e860b7765ad99129da1b";
        registerSigs[6] =
            hex"cc87da0745c4c5e5b4efbde06bac219be19e97d135e40c54dba76d4f76cb4ce6090408d0c63ecf272d59c476e81654c5cab6dac56cf24fde818917046c367daa1c";
        registerSigs[7] =
            hex"08c276abf97a585a050a3e75c3baa97149933b2f038b1701d967bea153a261d06b2e78ed7d2582421733b8b520fea3810b7acf37910adaedf35f436f37c5f1e31c";
        registerSigs[8] =
            hex"b231ba27d2e0efd7c287b414f6de3fa781ff7fe9d11632ee09ff5e084b14e70d599974624b7f40bf0a1daae8c7c9ebdd21d9a66d9b1a289c72a4f59508d22b2c1c";
        registerSigs[9] =
            hex"759ab00504f96991095216c51b71cf41a1010075375733fef3af5d1ff680529369c8194ac000700e7bf850793f9cf6b9f349943f6a1ae9d5b2a8edd9ad827cf81b";
        /* solhint-enable */
    }

    function slice(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        require(start <= end && end <= data.length, "Invalid range");

        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
        return result;
    }

}
