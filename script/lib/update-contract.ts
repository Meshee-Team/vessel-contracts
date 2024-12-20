import {ethers} from "ethers";
import {logger} from "./logger.js";
import {
  ACCESS_ROLE_DEFAULT_ADMIN, addressToBytes32,
  loadAdminWallet, loadContract,
  loadDeployerWallet,
  sendAndWaitTransaction, stringify
} from "./utils.js";
import {SubChainConfig} from "./config-manager.js";
import {getProxyAdmin} from "./read-contract.js";

export enum TxOrigin {
  Deployer,
  Admin,
}

async function sendToOwnerForExecution(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  targetContractAddress:string,
  functionData:string
) {
  // adminEOA either has role in VesselOwner or be part of multi-sig owners
  const vesselOwnerAddress = subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS

  // populate transaction sent to vessel owner contract for execution
  const vesselOwner: ethers.Contract = loadContract(subChainConfig, "VesselOwner", vesselOwnerAddress)
  let rawTransaction = await vesselOwner.execute.populateTransaction(targetContractAddress, 0, functionData, ACCESS_ROLE_DEFAULT_ADMIN) // value = 0

  // choose different execution way depending on txOrigin
  switch (txOrigin) {
    case TxOrigin.Admin:
      if (subChainConfig.ESSENTIAL.ENABLE_MULTISIG_ADMIN) {
        logger.info("================================================================")
        logger.info("SAFE transaction created, propose in SAFE UI using admin wallet")
        logger.info(`to: ${await vesselOwner.getAddress()}`)
        logger.info(`data: ${rawTransaction.data}`)
        logger.info(`value: 0`)
        logger.info("================================================================")
      } else {
        const adminWallet = loadAdminWallet(subChainConfig)
        await sendAndWaitTransaction(subChainConfig, adminWallet, rawTransaction)
      }
      return
    case TxOrigin.Deployer:
      const deployerWallet = loadDeployerWallet(subChainConfig)
      await sendAndWaitTransaction(subChainConfig, deployerWallet, rawTransaction)
      return
    default:
      logger.error(`Unknown tx origin ${txOrigin}`)
  }
}

/****************
 * Update Vault *
 ****************/

export async function updateAllVerifiers(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  snarkVerifierAddress: string,
  circuitVersion: string
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", vaultAddress)

  // send transaction to update the new version
  const functionData = contract.interface.encodeFunctionData(
    "updateAll",
    [snarkVerifierAddress, circuitVersion]
  )
  logger.info("Send transaction to update new circuit version")
  logger.info(`Vault contract address: ${vaultAddress}`)
  logger.info(`Snark verifier address: ${snarkVerifierAddress}`)
  logger.info(`Circuit version: ${circuitVersion}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

export async function registerToken(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  tokenAddress: string,
  tokenAssetId: number,
  limitDigit: number,
  precisionDigit: number,
  decimals: number
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig,"Vault", vaultAddress)

  // send transaction to register token
  const functionData = contract.interface.encodeFunctionData(
    "registerNewAsset",
    [tokenAddress, tokenAssetId, limitDigit, precisionDigit, decimals]
  )
  logger.info(`Send transaction to register token.`)
  logger.info(`Vault contract address: ${vaultAddress}`)
  logger.info(`TokenAddress: ${tokenAddress}`)
  logger.info(`Asset ID: ${tokenAssetId}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

export async function setAssetActive(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  assetId: number
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig,"Vault", vaultAddress)

  // send transaction to set asset active
  const functionData = contract.interface.encodeFunctionData(
    "setAssetActive",
    [assetId]
  )
  logger.info(`Send transaction to set asset active.`)
  logger.info(`Vault contract address: ${vaultAddress}`)
  logger.info(`Asset ID: ${assetId}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

export async function registerOperator(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  operatorAddress: string
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", vaultAddress)

  // send transaction to add operator
  const functionData = contract.interface.encodeFunctionData(
    "registerOperator",
    [operatorAddress]
  )
  logger.info(`Send transaction to add operator`)
  logger.info(`Vault contract address: ${vaultAddress}`)
  logger.info(`Operator address: ${operatorAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

export async function registerExitManager(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  exitManagerAddress: string
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", vaultAddress)

  // send transaction to add operator
  const functionData = contract.interface.encodeFunctionData(
    "registerExitManager",
    [exitManagerAddress]
  )
  logger.info(`Send transaction to add exitManager`)
  logger.info(`Vault contract address: ${vaultAddress}`)
  logger.info(`ExitManager address: ${exitManagerAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

export async function configureVault(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  chainCnt: number
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", vaultAddress)

  const cps = []
  for (const cp of subChainConfig.ESSENTIAL.PRE_COMMIT_CHECKPOINT) {
    cps.push({
      logicChainId: cp.LOGIC_CHAIN_ID,
      l1MessageCnt: 0,
      l1LastCommitHash: cp.L1_LAST_COMMIT_HASH,
      l1NextCommitHash: cp.L1_LAST_COMMIT_HASH,
      l2LastCommitHash: cp.L2_LAST_COMMIT_HASH,
    })
  }

  // send transaction configure vault
  const functionData = contract.interface.encodeFunctionData(
    "configureAll",
    [
      subChainConfig.ESSENTIAL.WETH_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.USER_API_LOGIC_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.MANAGER_API_LOGIC_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS,
      subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID,
      subChainConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID,
      chainCnt,
      cps
    ]
  )
  logger.info(`Send transaction to configure vault`)
  logger.info(`Vault contract address: ${vaultAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

export async function setVaultConfigured(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  configured: boolean
) {
  const vaultAddress = subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", vaultAddress)

  // send transaction to add operator
  const functionData = contract.interface.encodeFunctionData(
    "setConfigured",
    [configured]
  )
  logger.info(`Send transaction to set Vault Configured to ${ configured }`)
  logger.info(`Vault contract address: ${vaultAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, vaultAddress, functionData)
}

/**************************
 * Update LayerZeroPortal *
 **************************/

export async function setPeer(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  eid: number,
  peerAddress: string
) {
  const lzPortalAddress = subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", lzPortalAddress)

  // send tx to set peer
  const functionData = contract.interface.encodeFunctionData(
    "setPeer",
    [eid, addressToBytes32(peerAddress)]
  )
  logger.info(`Send transaction to set peer for lzPortal`)
  logger.info(`LayerZeroPortal contract address: ${lzPortalAddress}`)
  logger.info(`Peer info: EID ${eid}, address ${lzPortalAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, lzPortalAddress, functionData)
}

export async function configureLayerZeroPortal(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  vaultAddress: string,
  eidList: number[]
) {
  const lzPortalAddress = subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", lzPortalAddress)

  // send tx to configureAll
  const functionData = contract.interface.encodeFunctionData(
    "configureAll",
    [vaultAddress, eidList]
  )
  logger.info(`Send transaction to configure lzPortal`)
  logger.info(`LayerZeroPortal contract address: ${lzPortalAddress}`)
  logger.info(`Vault proxy address: ${vaultAddress}`)
  logger.info(`EidList: ${stringify(eidList)}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, lzPortalAddress, functionData)
}

export async function setLzPortalConfigured(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  configured: boolean
) {
  const lzPortalAddress = subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", lzPortalAddress)

  // send transaction to add operator
  const functionData = contract.interface.encodeFunctionData(
    "setConfigured",
    [configured]
  )
  logger.info(`Send transaction to set LzPortal Configured to ${ configured }`)
  logger.info(`LzPortal contract address: ${lzPortalAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, lzPortalAddress, functionData)
}

/*********************
 * Update ProxyAdmin *
 *********************/

export async function upgradeProxyImpl(
  subChainConfig: SubChainConfig,
  txOrigin: TxOrigin,
  proxyAddress: string,
  implAddress: string
) {
  const proxyAdminAddress = await getProxyAdmin(subChainConfig, proxyAddress)
  const contract: ethers.Contract = loadContract(subChainConfig,"ProxyAdmin", proxyAdminAddress)

  // send transaction to upgrade proxy implementation
  const functionData = contract.interface.encodeFunctionData(
    "upgrade",
    [proxyAddress, implAddress]
  )
  logger.info(`Send transaction to upgrade proxy implementation`)
  logger.info(`Proxy address: ${proxyAddress}`)
  logger.info(`Implementation address: ${implAddress}`)
  await sendToOwnerForExecution(subChainConfig, txOrigin, proxyAdminAddress, functionData)
}

/***********************************
 * Update Owner (through deployer) *
 ***********************************/

export async function grantRoleToAddressFromDeployer(
  subChainConfig: SubChainConfig,
  role: string,
  targetAddress: string
) {
  const vesselOwnerAddress = subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig,"VesselOwner", vesselOwnerAddress)
  const deployer = loadDeployerWallet(subChainConfig)

  // send transaction to grant role
  let rawTransaction = await contract.grantRole.populateTransaction(role, targetAddress)
  logger.info(`Send transaction to grant role`)
  logger.info(`Owner contract: ${vesselOwnerAddress}`)
  logger.info(`Role: ${role}`)
  logger.info(`Target address: ${targetAddress}`)
  await sendAndWaitTransaction(subChainConfig, deployer, rawTransaction)
}

export async function renounceRoleFromDeployer(
  subChainConfig: SubChainConfig,
  role: string
) {
  const vesselOwnerAddress = subChainConfig.ESSENTIAL.OWNER_CONTRACT_ADDRESS
  const contract: ethers.Contract = loadContract(subChainConfig,"VesselOwner", vesselOwnerAddress)
  const deployer = loadDeployerWallet(subChainConfig)

  // send transaction to grant role
  let rawTransaction = await contract.renounceRole.populateTransaction(role, deployer.address)
  logger.info(`Send transaction to renounce role`)
  logger.info(`Owner contract: ${vesselOwnerAddress}`)
  logger.info(`Role: ${role}`)
  logger.info(`Target address: ${deployer}`)
  await sendAndWaitTransaction(subChainConfig, deployer, rawTransaction)
}
