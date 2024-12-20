import { logger } from './lib/logger.js'
import { ConfigManager } from './lib/config-manager.js'
import { setPeer, TxOrigin } from './lib/update-contract.js'
import { TotalGasUsed } from './lib/utils.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  logger.info('========= Configure LayerZeroPortal =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)
  logger.info(`LZ Portal address: ${subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Set Peers for LZ Portal =========')
  if (subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID === subChainConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID) {
    logger.info('This chain is PRIMARY chain. Set peers to all affiliated chain portals.')
    for (const peerConfig of ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS) {
      if (peerConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID !== peerConfig.ESSENTIAL.LOGIC_CHAIN_ID) {
        await setPeer(
          subChainConfig,
          TxOrigin.Admin,
          peerConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID,
          peerConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS
        )
      }
    }
  } else {
    logger.info('This chain is SUBSIDIARY chain. Set peer to primary chain portal.')
    for (const peerConfig of ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS) {
      if (peerConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID === peerConfig.ESSENTIAL.LOGIC_CHAIN_ID) {
        await setPeer(
          subChainConfig,
          TxOrigin.Admin,
          peerConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID,
          peerConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS
        )
      }
    }
  }
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
