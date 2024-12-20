import { logger } from './lib/logger.js'
import { TxOrigin, upgradeProxyImpl } from './lib/update-contract.js'
import { ConfigManager } from './lib/config-manager.js'
import { deployContractWithName } from './lib/deploy-contract.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  logger.info('========= Update Vault Implementation =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Deploy New Vault Implementations =========')
  subChainConfig.ESSENTIAL.VAULT_IMPL_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'Vault')
  subChainConfig.ESSENTIAL.MANAGER_API_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'ManagerApiLogic')
  subChainConfig.ESSENTIAL.MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'MessageQueueLogic')
  subChainConfig.ESSENTIAL.MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'MultiChainLogic')
  subChainConfig.ESSENTIAL.TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'TokenManagerLogic')
  subChainConfig.ESSENTIAL.USER_API_LOGIC_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'UserApiLogic')

  logger.info('========= Step 2: Upgrade Vault proxy implementation =========')
  await upgradeProxyImpl(
    subChainConfig,
    TxOrigin.Admin,
    subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS,
    subChainConfig.ESSENTIAL.VAULT_IMPL_CONTRACT_ADDRESS
  )
  ConfigManager.getInstance().overwriteConfig()
}

main()
  .then(() => {
    logger.info('Flow finishes successfully')
  })
  .catch(e => {
    logger.error(e)
    process.exit(-1)
  })
