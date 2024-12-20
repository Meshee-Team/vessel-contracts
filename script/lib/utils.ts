import axios from "axios";
import * as fs from "fs";
import {
  BaseWallet,
  CallExceptionError,
  ethers,
  FeeData,
  JsonRpcProvider,
  TransactionReceipt,
  TransactionRequest
} from "ethers";
import {logger} from "./logger.js";
import {ConfigManager, SubChainConfig} from "./config-manager.js";

/**
 * Constants
 */
export let ACCESS_ROLE_DEFAULT_ADMIN = ethers.zeroPadValue(ethers.toBeArray(0), 32)

/**
 * types and functions to load contract ABI and bytecode
 */
interface Bytecode {
  object: string
  sourceMap: string
}

interface ContractMetadata {
  abi: string[]
  bytecode: Bytecode
}

export function loadContractMetadata(name: string): ContractMetadata {
  try {
    const data = fs.readFileSync(`../abi/${name}.sol/${name}.json`, "utf8")
    return JSON.parse(data) as ContractMetadata
  } catch (err) {
    logger.error(`Error loading contract ${name} metadata.`)
    throw err
  }
}

export function loadContract(subChainConfig: SubChainConfig, name: string, address: string): ethers.Contract {
  const metadata = loadContractMetadata(name)
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  return new ethers.Contract(address, metadata.abi, provider)
}

export function loadContractInterfaceMetadata(folderName: string, fileName: string): ContractMetadata {
  try {
    const data = fs.readFileSync(`../abi/${folderName}.sol/${fileName}.json`, "utf8")
    return JSON.parse(data) as ContractMetadata
  } catch (err) {
    logger.error(`Error loading contract ${fileName} metadata.`)
    throw err
  }
}

export function loadContractInterface(subChainConfig: SubChainConfig, folderName: string, fileName: string, address: string): ethers.Contract {
  const metadata = loadContractInterfaceMetadata(folderName, fileName)
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  return new ethers.Contract(address, metadata.abi, provider)
}

export async function decodeCallExceptionError(e: CallExceptionError) {
  const sourceContract = [
    "Vault",
    "ManagerApiLogic",
    "MessageQueueLogic",
    "MultiChainLogic",
    "TokenManagerLogic",
    "UserApiLogic"
  ]
  const combinedAbi = []
  for (const name of sourceContract) {
    const contractMetadata = loadContractMetadata(name)
    combinedAbi.push(...contractMetadata.abi)
  }

  const iface = new ethers.Interface(combinedAbi)
  try {
    const decodedError = iface.parseError(e.data!)
    logger.error(`Error Name: ${decodedError!.name}`)
    logger.error(`Error arg: ${decodedError!.args}`)
  } catch (err) {
    logger.error(`Fail to decode: ${stringify(err)}`)
  }
}

/**
 * functions to load admin / operator / fake user wallets from secret key and connect to node RPC provider
 */
const providers = new Map<number, JsonRpcProvider>;
export function getOrNewJsonRpcProvider(subChainConfig: SubChainConfig): JsonRpcProvider {
  if (!providers.has(subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID)) {
    providers.set(subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID, new JsonRpcProvider(subChainConfig.ESSENTIAL.NODE_RPC_URL))
  }
  return providers.get(subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID)!
}

// Admin wallet is either used as EOA to directly sends transaction to VesselOwner, or as a proposer of a multi-sig txn.
// Depending on config.essential.ENABLE_MULTISIG_ADMIN
export function loadAdminWallet(subChainConfig: SubChainConfig): ethers.Wallet {
  return new ethers.Wallet(subChainConfig.ESSENTIAL.ADMIN_SK)
    .connect(getOrNewJsonRpcProvider(subChainConfig))
}

export function loadDeployerWallet(subChainConfig: SubChainConfig): ethers.Wallet {
  return new ethers.Wallet(subChainConfig.ESSENTIAL.DEPLOYER_SK)
    .connect(getOrNewJsonRpcProvider(subChainConfig))
}

/**
 * send transaction and wait it to be mined
 */

export let TotalGasUsed: bigint = BigInt(0)

export async function sendAndWaitTransaction(
  subChainConfig: SubChainConfig,
  signer: ethers.Signer,
  rawTransaction: TransactionRequest
): Promise<TransactionReceipt> {
  // estimate and set the gas limit
  try {
    const gasEstimate = await signer.estimateGas(rawTransaction)
    logger.debug(`Gas estimation to send transaction: ${gasEstimate}.`)
    rawTransaction.gasLimit = gasEstimate * BigInt(12) / BigInt(10)
  } catch (e) {
    logger.error(`Failed to estimate gas for transaction: ${stringify(e)}`)
    if (ethers.isCallException(e)) {
      await decodeCallExceptionError(e)
    }
    throw e
  }

  // check and set the gas price
  let feeData:FeeData
  try {
    feeData = await signer.provider!.getFeeData() // provider cannot be null
  } catch (e) {
    throw new Error(`Failed to get fee data: ${stringify(e)}`)
  }
  if (subChainConfig.ESSENTIAL.ENABLE_1559) {
    if (feeData.maxFeePerGas != null && feeData.maxFeePerGas > ethers.parseUnits(subChainConfig.ESSENTIAL.MAX_FEE_PER_GAS.toString(), "gwei")) {
      throw new Error(`Current fee exceeds max price accepted: ${feeData.maxFeePerGas} > ${ethers.parseUnits(subChainConfig.ESSENTIAL.MAX_FEE_PER_GAS.toString(), "gwei")}`)
    }
    rawTransaction.maxFeePerGas = feeData.maxFeePerGas
    rawTransaction.maxPriorityFeePerGas = ethers.parseUnits(subChainConfig.ESSENTIAL.MAX_PRIORITY_FEE_PER_GAS.toString(), "gwei")
  } else {
    if (feeData.gasPrice != null && feeData.gasPrice > ethers.parseUnits(subChainConfig.ESSENTIAL.MAX_FEE_PER_GAS.toString(), "gwei")) {
      throw new Error(`Current gas price exceeds max price accepted: ${feeData.gasPrice} > ${ethers.parseUnits(subChainConfig.ESSENTIAL.MAX_FEE_PER_GAS.toString(), "gwei")}`)
    }
    rawTransaction.gasPrice = feeData.gasPrice
  }

  // send transaction and wait it to be mined
  let receipt:ethers.TransactionReceipt
  try {
    const txResponse = await signer.sendTransaction(rawTransaction);
    logger.debug(`Transaction response: ${JSON.stringify(txResponse)}`)
    receipt = (await txResponse.wait())!; // receipt cannot be null when no timeout is set
  } catch (e) {
    logger.error(`Failed to submit transaction: ${stringify(e)}`)
    if (ethers.isCallException(e)) {
      await decodeCallExceptionError(e)
    }
    throw e
  }

  // check transaction receipt
  if (receipt.status !== 1) {
    logger.error("transaction reverted. receipt:")
    logger.error(stringify(receipt));
    throw new Error("Transaction reverted")
  } else {
    TotalGasUsed += receipt.gasUsed
    logger.info(`Transaction confirmed. Gas used: ${receipt.gasUsed}. Gas price: ${receipt.gasPrice}`)
    logger.info("================================================================")
  }

  return receipt
}

/**
 * download github release by tag
 */
interface CircuitRelease {
  version: string
  unifiedBytecode: string
}

export async function downloadCircuitRelease(subChainConfig: SubChainConfig): Promise<CircuitRelease> {
  logger.info(`Inspect release with tag ${subChainConfig.ESSENTIAL.RELEASE_TAG}.`)
  const response = await fetch(`https://api.github.com/repos/Meshee-Team/meex-circuits/releases/tags/${subChainConfig.ESSENTIAL.RELEASE_TAG}`, {
    headers: {
      'Authorization': `token ${subChainConfig.ESSENTIAL.GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github.v3+json'
    }
  });
  if (!response.ok) {
    throw new Error('Network error when fetching release info.');
  }
  const releaseData = await response.json()
  logger.debug(`Release data for ${subChainConfig.ESSENTIAL.RELEASE_TAG}: ${JSON.stringify(releaseData)}`)

  let circuitRelease = {} as CircuitRelease
  circuitRelease.version = subChainConfig.ESSENTIAL.RELEASE_TAG
  for (let asset of releaseData.assets) {
    switch (asset.name) {
      case 'vessel.hex':
        circuitRelease.unifiedBytecode = maybeAdd0xPrefix(await downloadReleaseAsset(subChainConfig, asset.id))
        break
    }
  }

  logger.debug(`Download and parse circuitRelease: ${JSON.stringify(circuitRelease)}.`)
  return circuitRelease
}

async function downloadReleaseAsset(subChainConfig: SubChainConfig, assetId: number) {
  logger.info(`Download release asset ${assetId}`)
  const response = await axios({
    method: 'GET',
    url: `https://api.github.com/repos/Meshee-Team/meex-circuits/releases/assets/${assetId}`,
    responseType: 'arraybuffer',
    headers: {
      'Authorization': `token ${subChainConfig.ESSENTIAL.GITHUB_TOKEN}`,
      'Accept': 'application/octet-stream'
    }
  });
  return response.data.toString()
}

/**
 * Set nonce of deployer
 */
export async function setDeployerNonce(subChainConfig: SubChainConfig, nonce: number) {
  const deployer = loadDeployerWallet(subChainConfig)
  const nonceHex = nonce.toString(16)
  const rpcProvider = getOrNewJsonRpcProvider(subChainConfig)
  await rpcProvider.send("anvil_setNonce", [deployer.address, "0x"+nonceHex])

  const newNonce = await rpcProvider.getTransactionCount(deployer.address)
  if (newNonce !== nonce) {
    logger.error(`Failed to set nonce to ${nonce}. Actual: ${newNonce}.`)
    throw new Error("Failed to set nonce")
  } else {
    logger.info(`Set deployer nonce to ${nonce}`)
  }
}

export function maybeAdd0xPrefix(hex: string): string {
  if (hex.startsWith("0x")) {
    return hex;
  }
  return "0x" + hex;
}

export function maybeRemove0xPrefix(hex: string): string {
  if (hex.startsWith("0x")) {
    return hex.substring(2)
  }
  return hex
}
export function addressToBytes32(addressHex: string): string {
  const hex = maybeRemove0xPrefix(addressHex)
  if (hex.length != 40) {
    throw new Error(`Invalid address ${addressHex}`)
  }
  return maybeAdd0xPrefix(hex.padStart(64, '0'))
}

export function bytes32ToAddress(b: string): string {
  const hex = maybeRemove0xPrefix(b)
  if (hex.length != 64) {
    throw new Error(`Invalid bytes32 ${b}`)
  }
  return maybeAdd0xPrefix(hex.substring(24))
}

export function stringify(obj: any): string {
  return JSON.stringify(
    obj,
    (key, value) => typeof value === 'bigint' ? value.toString() : value
  );
}

export function hexEqual(a: string, b: string): boolean {
  return maybeAdd0xPrefix(a.toLowerCase()) == maybeAdd0xPrefix(b.toLowerCase())
}
