import { logger } from './lib/logger.js'
import { downloadCircuitRelease } from './lib/utils.js'
import { TxOrigin, updateAllVerifiers } from './lib/update-contract.js'
import { deployVerifierWithBytecode } from './lib/deploy-contract.js'
import { getCircuitVersion } from './lib/read-contract.js'
import { ConfigManager } from './lib/config-manager.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  logger.info('========= Update Snark Verifier =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Download release from github =========')
  const circuitRelease = await downloadCircuitRelease(subChainConfig)
  const curVersion = await getCircuitVersion(subChainConfig)
  if (curVersion === circuitRelease.version) {
    throw new Error(`On-chain circuit version equals with release version ${curVersion}`)
  }
  logger.info(`Current circuit version: ${curVersion}`)
  logger.info(`New circuit version to upgrade: ${circuitRelease.version}`)

  logger.info('========= Step 2: Deploy bytecode of all verifiers =========')
  const SnarkVerifierAddress = await deployVerifierWithBytecode(
    subChainConfig,
    circuitRelease.unifiedBytecode
  )

  logger.info('========= Step 3: Update vault with new version =========')
  await updateAllVerifiers(
    subChainConfig,
    TxOrigin.Admin,
    SnarkVerifierAddress,
    circuitRelease.version
  )
}

main()
  .then(() => {
    logger.info('Flow finishes successfully')
  })
  .catch(e => {
    logger.error(e)
    process.exit(-1)
  })
