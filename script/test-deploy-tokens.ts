import yargs from 'yargs'
import { logger } from './lib/logger.js'
import { setDeployerNonce } from './lib/utils.js'
import { deployTokenContract } from './lib/deploy-contract.js'
import { ConfigManager } from './lib/config-manager.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]
  const args = yargs(process.argv.slice(2)).options({ nonce: { type: 'number', default: null } }).parseSync()
  if (args.nonce !== null) {
    await setDeployerNonce(subChainConfig, args.nonce)
  }

  logger.info('========= Deploy Test Tokens =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Deploy ERC20 Token Contract =========')
  const tokenAddresses: string[] = []
  for (const token of subChainConfig.TEST.TOKENS) {
    const tokenAddress = await deployTokenContract(subChainConfig, token)
    tokenAddresses.push(tokenAddress)
    token.ADDRESS = tokenAddress
  }

  for (let i = 0; i < tokenAddresses.length; i++) {
    logger.info(`ERC20 Token ${i + 1} is deployed to: ${tokenAddresses[i]}.`)
  }
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
