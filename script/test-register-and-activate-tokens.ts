import yargs from 'yargs'
import { logger } from './lib/logger.js'
import { setDeployerNonce } from './lib/utils.js'
import { registerToken, setAssetActive, TxOrigin } from './lib/update-contract.js'
import { ConfigManager } from './lib/config-manager.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]
  const args = yargs(process.argv.slice(2)).options({ nonce: { type: 'number', default: null } }).parseSync()
  if (args.nonce !== null) {
    await setDeployerNonce(subChainConfig, args.nonce)
  }

  logger.info('========= Register And Activate Token =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Register and Activate Tokens =========')
  for (const token of subChainConfig.TEST.TOKENS) {
    await registerToken(subChainConfig, TxOrigin.Admin, token.ADDRESS, token.ID, token.LIMIT_DIGIT, token.PRECISION_DIGIT, token.DECIMALS)
    await setAssetActive(subChainConfig, TxOrigin.Admin, token.ID)
  }
}

main()
  .then(() => {
    logger.info('Flow finishes successfully')
  })
  .catch(e => {
    logger.error(e)
    process.exit(-1)
  })
