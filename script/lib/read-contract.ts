import {ethers} from "ethers";
import {bytes32ToAddress, getOrNewJsonRpcProvider, loadContract} from "./utils.js";
import {SubChainConfig} from "./config-manager.js";

/**************
 * Read Vault *
 **************/

export async function getCircuitVersion(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.circuitVersion()
}

export async function getAdmin(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.admin()
}

export async function checkOperator(subChainConfig: SubChainConfig, addr: string): Promise<boolean> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.operators(addr)
}

export async function checkExitManager(subChainConfig: SubChainConfig, addr: string): Promise<boolean> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.exitManagers(addr)
}

export async function getUserApiLogicAddress(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.userApiLogicAddress()
}

export async function getManagerApiLogicAddress(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.managerApiLogicAddress()
}

export async function getMessageQueueLogicAddress(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.messageQueueLogicAddress()
}

export async function getTokenManagerLogicAddress(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.tokenManagerLogicAddress()
}

export async function getMultiChainLogicAddress(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.multiChainLogicAddress()
}

export async function getCrossChainPortalContract(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.crossChainPortalContract()
}

export async function getLogicChainId(subChainConfig: SubChainConfig): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.logicChainId()
}

export async function getPrimaryLogicChainId(subChainConfig: SubChainConfig): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.primaryLogicChainId()
}

export async function getChainCntFromVault(subChainConfig: SubChainConfig): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.chainCnt()
}

export async function getWethAddress(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.wethAddress()
}

export type PostCommitConfirmation = {
  logicChainId: number
  l1MessageCnt: number
  l1NextCommitHash: string
  l2NextCommitHash: string
}

export async function getPostCommitConfirmation(subChainConfig: SubChainConfig): Promise<PostCommitConfirmation> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  const result = await contract.postCommitConfirmation()
  return {
    logicChainId: result.logicChainId,
    l1MessageCnt: result.l1MessageCnt,
    l1NextCommitHash: result.l1NextCommitHash,
    l2NextCommitHash: result.l2NextCommitHash
  }
}

export type PreCommitCheckpoint = {
  logicChainId: number
  l1MessageCnt: number
  l1LastCommitHash: string
  l1NextCommitHash: string
  l2LastCommitHash: string
}

export async function getPreCommitCheckpoint(subChainConfig: SubChainConfig, logicChainId: number): Promise<PreCommitCheckpoint> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  const result = await contract.preCommitCheckpointList(logicChainId)
  return {
    logicChainId: result.logicChainId,
    l1MessageCnt: result.l1MessageCnt,
    l1LastCommitHash: result.l1LastCommitHash,
    l1NextCommitHash: result.l1NextCommitHash,
    l2LastCommitHash: result.l2LastCommitHash
  }
}

export async function getL1CommitIndex(subChainConfig: SubChainConfig): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.l1ToL2MessageQueueCommitIndex()
}

export async function getL1CommitHash(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.l1ToL2MessageQueueHash(await getL1CommitIndex(subChainConfig))
}

export async function getL2CommitHash(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  return contract.l2ToL1MessageQueueCommitHash()
}

/*****************
 * Read LzPortal *
 *****************/

export async function getChainCntFromPortal(subChainConfig: SubChainConfig): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  return contract.chainCnt()
}

export async function getVaultContractFromPortal(subChainConfig: SubChainConfig): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  return contract.vaultContract()
}

export async function getEidByLogicChainId(subChainConfig: SubChainConfig, logicChainId: number): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  return contract.logicChainIdToEid(logicChainId)
}

export async function getLogicChainIdByEid(subChainConfig: SubChainConfig, eid: number): Promise<number> {
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  return contract.eidToLogicChainId(eid)
}

export async function getPeerByEid(subChainConfig: SubChainConfig, eid: number): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  return contract.peers(eid)
}

export async function quoteCrossChainFee(subChainConfig: SubChainConfig, dstLogicChainId: number, payload: string): Promise<bigint> {
  const contract: ethers.Contract = loadContract(subChainConfig, "LayerZeroPortal", subChainConfig.ESSENTIAL.LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS)
  return contract.quote(dstLogicChainId, payload)
}

/**************
 * Read Proxy *
 **************/

export async function getProxyAdmin(subChainConfig: SubChainConfig, proxyAddr: string): Promise<string> {
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  const adminStorageValue = await provider.getStorage(proxyAddr, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")
  return bytes32ToAddress(adminStorageValue)
}

/*******************
 * Read ProxyAdmin *
 *******************/

export async function getOwner(subChainConfig: SubChainConfig, ownableAddr: string): Promise<string> {
  const contract: ethers.Contract = loadContract(subChainConfig, "ProxyAdmin", ownableAddr)
  return contract.owner()
}
