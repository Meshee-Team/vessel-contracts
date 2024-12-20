import { logger } from './lib/logger.js'
import { registerExitManager, TxOrigin } from './lib/update-contract.js'
import { ConfigManager } from './lib/config-manager.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  logger.info('========= Add Exit Manager to Vault =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Add Exit Manager to Vault =========')
  const exitManagerAddress = '0x9ee825d20db28393b49840c78707159777dfb38b'
  await registerExitManager(subChainConfig, TxOrigin.Admin, exitManagerAddress)
}

main()
  .then(() => {
    logger.info('Flow finishes successfully')
  })
  .catch(e => {
    logger.error(e)
    process.exit(-1)
  })
