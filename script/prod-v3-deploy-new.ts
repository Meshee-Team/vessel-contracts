import yargs from 'yargs'
import { logger } from './lib/logger.js'
import { ConfigManager } from './lib/config-manager.js'
import {
  ACCESS_ROLE_DEFAULT_ADMIN,
  downloadCircuitRelease,
  getOrNewJsonRpcProvider,
  setDeployerNonce, TotalGasUsed
} from './lib/utils.js'
import {
  deployContractWithName,
  deployLayerZeroPortalImplContract,
  deployLayerZeroPortalProxyContract,
  deployVaultProxyContract, deployVerifierWithBytecode
} from './lib/deploy-contract.js'
import {
  configureLayerZeroPortal,
  configureVault,
  grantRoleToAddressFromDeployer, registerExitManager,
  registerOperator,
  renounceRoleFromDeployer,
  TxOrigin, updateAllVerifiers
} from './lib/update-contract.js'
import { getProxyAdmin } from './lib/read-contract.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  const args = yargs(process.argv.slice(2)).options({ nonce: { type: 'number', default: null } }).parseSync()
  if (args.nonce !== null) {
    await setDeployerNonce(subChainConfig, args.nonce)
    logger.info(`Set deployer nonce to ${args.nonce}`)
  }

  // download circuit release first to avoid gas waste
  const circuitRelease = await downloadCircuitRelease(subChainConfig)

  logger.info('========= Deploy ALL Contracts =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Current Block: ${await getOrNewJsonRpcProvider(subChainConfig).getBlockNumber()}`)

  logger.info('========= Step 1: Deploy VesselOwner Contracts =========')
  subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'VesselOwner')

  logger.info('========= Step 2: Deploy Vault Implementations =========')
  subChainConfig.ESSENTIAL.VAULT_IMPL_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'Vault')
  subChainConfig.ESSENTIAL.MANAGER_API_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'ManagerApiLogic')
  subChainConfig.ESSENTIAL.MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'MessageQueueLogic')
  subChainConfig.ESSENTIAL.MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'MultiChainLogic')
  subChainConfig.ESSENTIAL.TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'TokenManagerLogic')
  subChainConfig.ESSENTIAL.USER_API_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'UserApiLogic')

  logger.info('========= Step 3: Deploy Vault Proxy =========')
  subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS = await deployVaultProxyContract(
    subChainConfig,
    subChainConfig.ESSENTIAL.VAULT_IMPL_CONTRACT_ADDRESS,
    subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS
  )
  subChainConfig.ESSENTIAL.VAULT_PROXY_ADMIN_CONTRACT_ADDRESS = await getProxyAdmin(
    subChainConfig,
    subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  )

  logger.info('========= Step 4: Deploy LayerZeroPortal Implementations =========')
  subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_IMPL_CONTRACT_ADDRESS = await deployLayerZeroPortalImplContract(
    subChainConfig,
    subChainConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_ADDRESS
  )

  logger.info('========= Step 5: Deploy LayerZeroPortal Proxy =========')
  subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS = await deployLayerZeroPortalProxyContract(
    subChainConfig,
    subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_IMPL_CONTRACT_ADDRESS,
    subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS
  )
  subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS = await getProxyAdmin(
    subChainConfig,
    subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS
  )

  logger.info('========= Step 6: Register Operators and Exit Managers =========')
  const SnarkVerifierAddress = await deployVerifierWithBytecode(
    subChainConfig,
    circuitRelease.unifiedBytecode
  )
  await updateAllVerifiers(
    subChainConfig,
    TxOrigin.Deployer,
    SnarkVerifierAddress,
    circuitRelease.version
  )

  logger.info('========= Step 7: Register Operators and Exit Managers =========')
  for (const operatorAddress of subChainConfig.ESSENTIAL.OPERATOR_ADDRESSES) {
    await registerOperator(
      subChainConfig,
      TxOrigin.Deployer,
      operatorAddress
    )
  }
  for (const exitManagerAddress of subChainConfig.ESSENTIAL.EXIT_MANAGER_ADDRESSES) {
    await registerExitManager(
      subChainConfig,
      TxOrigin.Deployer,
      exitManagerAddress
    )
  }

  logger.info('========= Step 8: Configure Vault and LzPortal =========')
  await configureVault(
    subChainConfig,
    TxOrigin.Deployer,
    ConfigManager.getInstance().getConfig().SUB_CHAIN_CNT
  )
  const eidList = []
  for (const it of ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS) {
    eidList.push(it.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID)
  }
  await configureLayerZeroPortal(
    subChainConfig,
    TxOrigin.Deployer,
    subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS,
    eidList
  )

  logger.info('========= Step 9: Transfer VesselOwner DefaultAdminRole from Deployer to Admin =========')
  await grantRoleToAddressFromDeployer(
    subChainConfig,
    ACCESS_ROLE_DEFAULT_ADMIN,
    subChainConfig.ESSENTIAL.ADMIN_ADDRESS
  )
  await renounceRoleFromDeployer(
    subChainConfig,
    ACCESS_ROLE_DEFAULT_ADMIN
  )

  logger.info('========= Step 10: Update Config File =========')
  ConfigManager.getInstance().overwriteConfig()
}

main()
  .then(() => {
    logger.info('Flow finishes successfully')
    logger.info(`Total gas used: ${TotalGasUsed}`)
  })
  .catch(e => {
    logger.error(e)
    process.exit(-1)
  })
