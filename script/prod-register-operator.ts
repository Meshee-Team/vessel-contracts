import { logger } from './lib/logger.js'
import { registerOperator, TxOrigin } from './lib/update-contract.js'
import { ConfigManager } from './lib/config-manager.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  logger.info('========= Add Operator Vault =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Add Operator to Vault =========')
  const operatorAddress = '0x570b2C710445091C95a2859cE282D16D4Cf1A257'
  await registerOperator(subChainConfig, TxOrigin.Admin, operatorAddress)
}

main()
  .then(() => {
    logger.info('Flow finishes successfully')
  })
  .catch(e => {
    logger.error(e)
    process.exit(-1)
  })
