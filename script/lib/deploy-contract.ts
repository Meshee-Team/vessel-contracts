import { ethers } from "ethers";
import {
  loadContractMetadata,
  loadDeployerWallet,
  sendAndWaitTransaction
} from "./utils.js";
import { logger } from "./logger.js";
import {SubChainConfig, TokenInfo} from "./config-manager.js";

async function deployBytecode(
  subChainConfig: SubChainConfig,
  bytecodeHex: string,
  encodeArgsHex: string
): Promise<string> {
  const deployer = loadDeployerWallet(subChainConfig)

  // Define the deployment transaction
  const rawTransaction: ethers.TransactionRequest = {
    data: bytecodeHex + encodeArgsHex.substring(2)
  };

  // Send the deployment transaction and wait
  const txReceipt = await sendAndWaitTransaction(subChainConfig, deployer, rawTransaction)
  if (txReceipt.contractAddress == null) {
    throw new Error(`Deployment transaction returns null address ${txReceipt}`)
  } else {
    return txReceipt.contractAddress
  }
}

async function deployContractWithNameAndArgs(
  subChainConfig: SubChainConfig,
  name: string,
  encodeArgs: string
): Promise<string> {
  const contractMetadata = loadContractMetadata(name)

  logger.info(`Sending transaction to deploy ${name} contract.`)
  const deployedAddr = await deployBytecode(subChainConfig, contractMetadata.bytecode.object, encodeArgs)
  logger.info(`${name} contract deployed at ${deployedAddr}`)
  return deployedAddr
}

export async function deployContractWithName(
  subChainConfig: SubChainConfig,
  name: string,
): Promise<string> {
  return deployContractWithNameAndArgs(subChainConfig, name, "")
}

async function deployTransparentProxyContract(subChainConfig: SubChainConfig, encodeArgs: string): Promise<string> {
  return deployContractWithNameAndArgs(subChainConfig, "TransparentUpgradeableProxy", encodeArgs)
}

export async function deployVaultProxyContract(
  subChainConfig: SubChainConfig,
  vaultImplAddress: string,
  ownerAddress: string
): Promise<string> {
  const initAbi = ["function initialize_v2(address)"]
  const initInterface = new ethers.Interface(initAbi)
  const initData = initInterface.encodeFunctionData("initialize_v2", [ownerAddress])
  const encodeArgs = ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "bytes"],
    [vaultImplAddress, ownerAddress, initData])

  return deployTransparentProxyContract(subChainConfig, encodeArgs)
}

export async function deployLayerZeroPortalProxyContract(
  subChainConfig: SubChainConfig,
  layerZeroPortalImplAddress: string,
  ownerAddress: string
): Promise<string> {
  const initAbi = ["function initialize(address)"]
  const initInterface = new ethers.Interface(initAbi)
  const initData = initInterface.encodeFunctionData("initialize", [ownerAddress])
  const encodeArgs = ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "bytes"],
    [layerZeroPortalImplAddress, ownerAddress, initData])

  return deployTransparentProxyContract(subChainConfig, encodeArgs)
}

export async function deployLayerZeroPortalImplContract(
  subChainConfig: SubChainConfig,
  endpointAddress: string
): Promise<string> {
  const encodeArgs = ethers.AbiCoder.defaultAbiCoder().encode(
    ["address"],
    [endpointAddress]
  )

  return deployContractWithNameAndArgs(subChainConfig, "LayerZeroPortal", encodeArgs)
}

export async function deployTokenContract(subChainConfig: SubChainConfig, token: TokenInfo): Promise<string> {
  const deployer = loadDeployerWallet(subChainConfig)
  const encodeArgs = ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "uint256", "uint8", "string", "string"],
    [deployer.address, ethers.parseUnits("1000000000000000000000000000000", token.DECIMALS), token.DECIMALS, token.SYMBOL, token.SYMBOL])

  return deployContractWithNameAndArgs(subChainConfig, "Token", encodeArgs)
}

export async function deployVerifierWithBytecode(subChainConfig: SubChainConfig, verifierBytecode: string): Promise<string> {
  logger.info(`Sending transaction to deploy SnarkVerifier bytecode`)
  const deployedAddr = await deployBytecode(subChainConfig, verifierBytecode, "")
  logger.info(`SnarkVerifier bytecode deployed at ${deployedAddr}`)
  return deployedAddr
}
