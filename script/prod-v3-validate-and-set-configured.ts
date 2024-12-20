import { logger } from './lib/logger.js'
import { ConfigManager } from './lib/config-manager.js'
import {
  checkExitManager,
  checkOperator,
  getAdmin,
  getChainCntFromPortal,
  getChainCntFromVault,
  getCircuitVersion,
  getCrossChainPortalContract,
  getEidByLogicChainId,
  getL1CommitHash,
  getL2CommitHash,
  getLogicChainId,
  getLogicChainIdByEid,
  getManagerApiLogicAddress,
  getMessageQueueLogicAddress,
  getMultiChainLogicAddress,
  getOwner,
  getPeerByEid,
  getPostCommitConfirmation,
  getPreCommitCheckpoint,
  getPrimaryLogicChainId,
  getProxyAdmin,
  getTokenManagerLogicAddress,
  getUserApiLogicAddress,
  getVaultContractFromPortal,
  getWethAddress
} from './lib/read-contract.js'
import { addressToBytes32, hexEqual, stringify, TotalGasUsed } from './lib/utils.js'
import { setLzPortalConfigured, setVaultConfigured, TxOrigin } from './lib/update-contract.js'

async function main (): Promise<void> {
  const subChainConfig = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[0]

  logger.info('========= Validate Deployment and Configuration =========')
  logger.info(`Chain ID: ${subChainConfig.ESSENTIAL.CHAIN_ID}`)
  logger.info(`Node RPC: ${subChainConfig.ESSENTIAL.NODE_RPC_URL}`)
  logger.info(`Vault address: ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}`)

  logger.info('========= Step 1: Validate Vault Configurations =========')
  if (ConfigManager.getInstance().getConfig().SUB_CHAIN_CNT !== await getChainCntFromVault(subChainConfig)) {
    throw new Error(`SUB_CHAIN_CNT not consistent with on-chain value ${await getChainCntFromVault(subChainConfig)}`)
  } else {
    logger.info('SUB_CHAIN_CNT passes validation')
  }

  if (subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID !== await getLogicChainId(subChainConfig)) {
    throw new Error(`LOGIC_CHAIN_ID not consistent with on-chain value ${await getLogicChainId(subChainConfig)}`)
  } else {
    logger.info('LOGIC_CHAIN_ID passes validation')
  }

  if (subChainConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID !== await getPrimaryLogicChainId(subChainConfig)) {
    throw new Error(`PRIMARY_LOGIC_CHAIN_ID not consistent with on-chain value ${await getPrimaryLogicChainId(subChainConfig)}`)
  } else {
    logger.info('PRIMARY_LOGIC_CHAIN_ID passes validation')
  }

  for (const addr of subChainConfig.ESSENTIAL.OPERATOR_ADDRESSES) {
    if (!await checkOperator(subChainConfig, addr)) {
      throw new Error(`OPERATOR_ADDRESSES ${addr} not valid on-chain`)
    }
  }
  logger.info('OPERATOR_ADDRESSES passes validation')

  for (const addr of subChainConfig.ESSENTIAL.EXIT_MANAGER_ADDRESSES) {
    if (!await checkExitManager(subChainConfig, addr)) {
      throw new Error(`EXIT_MANAGER_ADDRESSES ${addr} not valid on-chain`)
    }
  }
  logger.info('EXIT_MANAGER_ADDRESSES passes validation')

  if (subChainConfig.ESSENTIAL.RELEASE_TAG !== await getCircuitVersion(subChainConfig)) {
    throw new Error(`Circuit version not consistent with on-chain value ${await getCircuitVersion(subChainConfig)}`)
  } else {
    logger.info('Circuit version passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.WETH_CONTRACT_ADDRESS, await getWethAddress(subChainConfig))) {
    throw new Error(`WETH_CONTRACT_ADDRESS not consistent with on-chain value ${await getWethAddress(subChainConfig)}`)
  } else {
    logger.info('WETH_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.MANAGER_API_LOGIC_CONTRACT_ADDRESS, await getManagerApiLogicAddress(subChainConfig))) {
    throw new Error(`MANAGER_API_LOGIC_CONTRACT_ADDRESS not consistent with on-chain value ${await getManagerApiLogicAddress(subChainConfig)}`)
  } else {
    logger.info('MANAGER_API_LOGIC_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS, await getMessageQueueLogicAddress(subChainConfig))) {
    throw new Error(`MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS not consistent with on-chain value ${await getMessageQueueLogicAddress(subChainConfig)}`)
  } else {
    logger.info('MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS, await getMultiChainLogicAddress(subChainConfig))) {
    throw new Error(`MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS not consistent with on-chain value ${await getMultiChainLogicAddress(subChainConfig)}`)
  } else {
    logger.info('MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS, await getTokenManagerLogicAddress(subChainConfig))) {
    throw new Error(`TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS not consistent with on-chain value ${await getTokenManagerLogicAddress(subChainConfig)}`)
  } else {
    logger.info('TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.USER_API_LOGIC_CONTRACT_ADDRESS, await getUserApiLogicAddress(subChainConfig))) {
    throw new Error(`USER_API_LOGIC_CONTRACT_ADDRESS not consistent with on-chain value ${await getUserApiLogicAddress(subChainConfig)}`)
  } else {
    logger.info('USER_API_LOGIC_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS, await getAdmin(subChainConfig))) {
    throw new Error(`VAULT admin(owner) not consistent with on-chain value ${await getAdmin(subChainConfig)}`)
  } else {
    logger.info('Vault admin passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS, await getCrossChainPortalContract(subChainConfig))) {
    throw new Error(`L0 portal address not consistent with on-chain value ${await getCrossChainPortalContract(subChainConfig)}`)
  } else {
    logger.info('L0 portal passes validation')
  }

  // pre-commit cp conforms to given value in config
  for (const cp of subChainConfig.ESSENTIAL.PRE_COMMIT_CHECKPOINT) {
    const actual = await getPreCommitCheckpoint(subChainConfig, cp.LOGIC_CHAIN_ID)
    if (
      cp.LOGIC_CHAIN_ID !== actual.logicChainId ||
      actual.l1MessageCnt !== 0 ||
      !hexEqual(cp.L1_LAST_COMMIT_HASH, actual.l1LastCommitHash) ||
      !hexEqual(cp.L1_LAST_COMMIT_HASH, actual.l1NextCommitHash) ||
      !hexEqual(cp.L2_LAST_COMMIT_HASH, actual.l2LastCommitHash)
    ) {
      throw new Error(`PRE_COMMIT_CHECKPOINT not consistent with on-chain value ${stringify(actual)}`)
    }
  }
  logger.info('PRE_COMMIT_CHECKPOINT passes validation')

  // post-commit c conforms to on-chain mq values
  const c = await getPostCommitConfirmation(subChainConfig)
  if (
    c.l1MessageCnt !== 0 ||
    !hexEqual(c.l1NextCommitHash, await getL1CommitHash(subChainConfig)) ||
    !hexEqual(c.l2NextCommitHash, await getL2CommitHash(subChainConfig))
  ) {
    throw new Error(`POST_COMMIT_CONFIRMATION not consistent with on-chain value ${stringify(c)}`)
  }
  logger.info('POST_COMMIT_CONFIRMATION passes validation')

  logger.info('========= Step 2: Validate Vault Proxy =========')
  if (!hexEqual(
    subChainConfig.ESSENTIAL.VAULT_PROXY_ADMIN_CONTRACT_ADDRESS,
    await getProxyAdmin(subChainConfig, subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  )) {
    throw new Error(`VAULT_PROXY_ADMIN_CONTRACT_ADDRESS not consistent with on-chain value ${await getProxyAdmin(subChainConfig, subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)}`)
  } else {
    logger.info('VAULT_PROXY_ADMIN_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(
    subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS,
    await getOwner(subChainConfig, subChainConfig.ESSENTIAL.VAULT_PROXY_ADMIN_CONTRACT_ADDRESS)
  )) {
    throw new Error(`VAULT_PROXY_ADMIN_CONTRACT_ADDRESS owner not consistent with on-chain value ${await getOwner(subChainConfig, subChainConfig.ESSENTIAL.VAULT_PROXY_ADMIN_CONTRACT_ADDRESS)}`)
  } else {
    logger.info('VAULT_PROXY_ADMIN_CONTRACT_ADDRESS owner passes validation')
  }

  logger.info('========= Step 3: Validate LZPortal Configurations =========')
  if (ConfigManager.getInstance().getConfig().SUB_CHAIN_CNT !== await getChainCntFromPortal(subChainConfig)) {
    throw new Error(`SUB_CHAIN_CNT not consistent with on-chain value ${await getChainCntFromPortal(subChainConfig)}`)
  } else {
    logger.info('SUB_CHAIN_CNT passes validation')
  }

  if (!hexEqual(subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS, await getVaultContractFromPortal(subChainConfig))) {
    throw new Error(`Vault address not consistent with on-chain value ${await getVaultContractFromPortal(subChainConfig)}`)
  } else {
    logger.info('Vault address passes validation')
  }

  for (let i = 0; i < ConfigManager.getInstance().getConfig().SUB_CHAIN_CNT; i++) {
    const expectEid = ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS[i].ESSENTIAL.LAYER_ZERO_ENDPOINT_EID
    if (expectEid !== await getEidByLogicChainId(subChainConfig, i)) {
      throw new Error(`logicChainIdToEid mapping ${i} not consistent with on-chain value ${await getEidByLogicChainId(subChainConfig, i)}`)
    }
    if (i !== await getLogicChainIdByEid(subChainConfig, expectEid)) {
      throw new Error(`eidToLogicChainId mapping ${i} not consistent with on-chain value ${await getLogicChainIdByEid(subChainConfig, expectEid)}`)
    }
  }
  logger.info('Eid and LogicChainId mapping passes validation')

  if (subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID === subChainConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID) {
    // primary chain is paired with all other chains
    for (const peerConfig of ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS) {
      if (peerConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID !== peerConfig.ESSENTIAL.LOGIC_CHAIN_ID) {
        if (!hexEqual(addressToBytes32(peerConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS),
          await getPeerByEid(subChainConfig, peerConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID))) {
          throw new Error(`peer address by EID not consistent with on-chain value ${await getPeerByEid(subChainConfig, peerConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID)}`)
        }
      }
    }
  } else {
    // subsidiary chain is only paired with primary chain
    for (const peerConfig of ConfigManager.getInstance().getConfig().SUB_CHAIN_CONFIGS) {
      if (peerConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID === peerConfig.ESSENTIAL.LOGIC_CHAIN_ID) {
        if (!hexEqual(addressToBytes32(peerConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS),
          await getPeerByEid(subChainConfig, peerConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID))) {
          throw new Error(`peer address by EID not consistent with on-chain value ${await getPeerByEid(subChainConfig, peerConfig.ESSENTIAL.LAYER_ZERO_ENDPOINT_EID)}`)
        }
      }
    }
  }
  logger.info('Peer by EID passes validation')

  logger.info('========= Step 4: Validate LZPortal Proxy =========')
  if (!hexEqual(
    subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS,
    await getProxyAdmin(subChainConfig, subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  )) {
    throw new Error(`LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS not consistent with on-chain value ${await getProxyAdmin(subChainConfig, subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)}`)
  } else {
    logger.info('LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS passes validation')
  }

  if (!hexEqual(
    subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS,
    await getOwner(subChainConfig, subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS)
  )) {
    throw new Error(`LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS owner not consistent with on-chain value ${await getOwner(subChainConfig, subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS)}`)
  } else {
    logger.info('LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS owner passes validation')
  }

  logger.info('========= Step 5: Enable Vault and LzPortal as Configured =========')
  await setVaultConfigured(subChainConfig, TxOrigin.Admin, true)
  await setLzPortalConfigured(subChainConfig, TxOrigin.Admin, true)
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
