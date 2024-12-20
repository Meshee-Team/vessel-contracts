# Vessel Contract

Vessel smart contracts.

## Script Usage

### Dependencies

1. Install Node.js (>= v20)
   ```
   $ brew install nvm
   $ nvm install --lts
   $ nvm use --lts
   ```
2. Install Foundry compiler
   ```
   $ curl -L https://foundry.paradigm.xyz | bash
   $ foundryup
   ```
3. Install TypeScript and pnpm
   ```sh
   $ npm install -g typescript tsx pnpm
   ```
4. Compile the Solidity cod
   ```sh
   $ pnpm run build
   ```
5. Install script dependencies
   ```sh
   $ cd script
   $ pnpm install
   ```
6. Create a .env file
   ```sh
   $ cp .env.example .env
   ```
7. Create a config file with the name `.config.{NODE_ENV}.json`. For the default `NODE_ENV=local`, it should be:
   ```sh
   $ cp .config.exmaple.json .config.local.json
   ```

### Config

Ensure all **_essential_** configuration variables are correctly filled. These variables are used in both production and
test environments.

- **DEPLOYER_SK**: Private key of deployer EOA.
- **ADMIN_ADDRESS**: Address of the vault admin, eligible to upgrade the vault and SNARK verifier.
- **OPERATOR_ADDRESSES**: List of addresses of vault operators, eligible to manage tokens and users, and commit SNARK
  proofs.
- **GITHUB_TOKEN**: GitHub token used to download the circuit release containing SNARK verifier bytecode.
- **RELEASE_TAG**: GitHub release tag identifying the circuit release.
- **NODE_RPC_URL**: string URL. RPC endpoint of the EVM chain node.
- **CHAIN_ID**: Integer representing the chain ID.
- **MAX_FEE_PER_GAS**: Maximum fee per gas (human-readable number) if ENABLE_1559 is true, or gas price if ENABLE_1559
  is false.
- **MAX_PRIORITY_FEE_PER_GAS**: Maximum priority fee per gas (human-readable number) if ENABLE_1559 is true.
- **ENABLE_1559**: Boolean indicating if EIP-1559 is enabled.
- **ENABLE_MULTISIG_ADMIN**: Boolean indicating if contract upgrades should propose a multi-sig transaction to the SAFE
  API URL instead of directly sending a transaction to the node RPC using ADMIN_SK.
- **SAFE_TX_SERVICE_URL**: SAFE API endpoint, normally requiring the `/api` suffix.
- **VAULT_PROXY_CONTRACT_ADDRESS**: Will be overwritten after running the deploy script.
- **PROXY_ADMIN_CONTRACT_ADDRESS**: Will be overwritten after running the deploy script.
- **OWNER_CONTRACT_ADDRESS**: Will be overwritten after running the deploy script.
- **ADMIN_SK**: Private key of admin EOA, needed only if the admin is an EOA rather than a multi-sig contract, for
  running the script to upgrade the contract.

To test listing token and registering users in the vault, additional **_test_** configuration variables may be used.

Ensure all **_essential_** configuration variables are correctly filled. Initially, set dummy values for
**VAULT_ADDRESS**, **TOKEN_ADDRESS**, and **TOKEN_ASSET_ID**, they will be automatically set after deploying new
contracts.

## Forge Usage

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

Deploy to Anvil:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ pnpm lint
```

### Test

Run the tests:

```sh
$ forge test
```

## Notes

1. Foundry uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to manage dependencies. For
   detailed instructions on working with dependencies, please refer to the
   [guide](https://book.getfoundry.sh/projects/dependencies.html) in the book
2. You don't have to create a `.env` file, but filling in the environment variables may be useful when debugging and
   testing against a fork.

## Related Efforts

- [abigger87/femplate](https://github.com/abigger87/femplate)
- [cleanunicorn/ethereum-smartcontract-template](https://github.com/cleanunicorn/ethereum-smartcontract-template)
- [foundry-rs/forge-template](https://github.com/foundry-rs/forge-template)
- [FrankieIsLost/forge-template](https://github.com/FrankieIsLost/forge-template)

## License

SPDX-License-Identifier: Apache-2.0

Copyright 2024 Vessel Team.
