import yargs from 'yargs'
import { logger } from './lib/logger.js'
import { setDeployerNonce } from './lib/utils.js'
import { ConfigManager } from './lib/config-manager.js'
import { deployContractWithName } from './lib/deploy-contract.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]
  const args = yargs(process.argv.slice(2)).options({ nonce: { type: 'number', default: null } }).parseSync()
  if (args.nonce !== null) {
    await setDeployerNonce(subChainConfig, args.nonce)
  }

  logger.info('========= Deploy WETH Token contract =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Deploy WETH Token contract =========')
  subChainConfig.ESSENTIAL.WETH_CONTRACT_ADDRESS = await deployContractWithName(subChainConfig, 'WETH')
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
