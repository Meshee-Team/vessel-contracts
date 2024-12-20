import {ethers} from "ethers";
import {
  decodeCallExceptionError,
  getOrNewJsonRpcProvider,
  loadAdminWallet,
  loadContract,
  loadContractMetadata, loadDeployerWallet, sendAndWaitTransaction,
  stringify
} from "./utils.js";
import {logger} from "./logger.js";
import {ConfigManager} from "./config-manager.js";
import {PreCommitCheckpoint, quoteCrossChainFee} from "./read-contract.js";

let CONFIG = ConfigManager.getInstance().getConfig()

export async function printVaultProxyState() {
  const subChainConfig = CONFIG.SUB_CHAIN_CONFIGS[0]
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  const vaultProxy = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  logger.info(`Vault proxy: ${await vaultProxy.getAddress()}:`)
  logger.info(`Vault proxy admin contract: ${await provider.getStorage(vaultProxy, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")}`)
  logger.info(`Vault admin: ${await vaultProxy.adminAddress()}`)
  logger.info(`Vault implementation: ${await provider.getStorage(vaultProxy, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")}`)
}

export async function printVaultState() {
  const subChainConfig = CONFIG.SUB_CHAIN_CONFIGS[0]
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  logger.info(`Network: ${JSON.stringify(await provider.getNetwork())}`)
  logger.info(`Block: ${await provider.getBlockNumber()}`)

  const vaultContract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  logger.info(`Vault stats for ${subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS}:`)
  logger.info(`SNARK verifier version: ${await vaultContract.getCircuitVersion()}`)
  logger.info(`WETH address: ${await vaultContract.wethAddress()}`)
  logger.info(`LastCommitEventId: ${await vaultContract.getLastCommitEventId()}`)
  logger.info(`EternalRoot: ${convertToLEHexString(await vaultContract.getEternalTreeRoot())}`)
  logger.info(`EphemeralRoot: ${convertToLEHexString(await vaultContract.getEphemeralTreeRoot())}`)
  const l1ToL2CommitIndex = await vaultContract.getL1ToL2MessageQueueCommitIndex()
  logger.info(`l1->l2 queue commit index: ${l1ToL2CommitIndex}`)
  logger.info(`l1->l2 queue commit hash: ${await vaultContract.getL1ToL2MessageQueueHashAt(l1ToL2CommitIndex)}`)
  // for (let i=0; i<=907; i++) {
  //   logger.info(`l1->l2 msg queue hash at ${i}: ${await vaultContract.getL1ToL2MessageQueueHashAt(i)}`)
  // }
  logger.info(`l2->l1 queue commit hash: ${await vaultContract.getL2ToL1MessageQueueCommitHash()}`)

  // // Retrieve the event logs
  // const logFilter = {
  //   address: vaultAddress,
  //   fromBlock: 	0,
  //   toBlock: 500000,
  //   topics: [
  //     [
  //       ethers.utils.id('LogL1ToL2MessageQueueDeposit(address,uint256,uint256,bytes32)'),
  //       ethers.utils.id('LogL1ToL2MessageQueueRegister(address,bytes,bytes32)'),
  //       // ethers.utils.id('LogDeposit(address,uint256,uint256)'),
  //       // ethers.utils.id('LogVesselKeyRegister(address,bytes)')
  //     ]
  //   ]
  // }
  // provider.getLogs(logFilter).then((logs) => {
  //   for (let i = 0; i < logs.length; i++) {
  //     const parsedLog = vaultContract.interface.parseLog(logs[i])
  //     logger.info(`log ${i+1}: ${parsedLog.name}, ${parsedLog.args}`);
  //   }
  // }).catch((error) => {
  //   logger.error(error);
  // });
}

export async function quoteAndSendCrossChainMsg() {
  const srcChain = 1;
  const dstChain = 0;
  const subChainConfig = CONFIG.SUB_CHAIN_CONFIGS[srcChain]
  const cp: PreCommitCheckpoint = {
    logicChainId: srcChain,
    l1MessageCnt: 5,
    l1LastCommitHash: "0x1234123412341234123412341234123412341234123412341234123412341234",
    l1NextCommitHash: "0x1234123412341234123412341234123412341234123412341234123412341234",
    l2LastCommitHash: "0x1234123412341234123412341234123412341234123412341234123412341234"
  }

  // calculate payload bytes
  const encoder = ethers.AbiCoder.defaultAbiCoder()
  const payload = encoder.encode(
    ['uint32', 'uint256', 'bytes32', 'bytes32', 'bytes32'],
    [cp.logicChainId, cp.l1MessageCnt, cp.l1LastCommitHash, cp.l1NextCommitHash, cp.l2LastCommitHash]
  )
  logger.info(`Payload: ${payload}`)

  // quote fee
  const nativeFee = await quoteCrossChainFee(subChainConfig, dstChain, payload)
  logger.info(`Quoted fee: ${ethers.formatEther(nativeFee)} $ETH`)

  // estimate gas
  let vaultContract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)
  try {
    const result = await vaultContract.preCommitSubChainProgress.estimateGas(
      0,
      {
        from: subChainConfig.ESSENTIAL.ADMIN_ADDRESS,
        value: nativeFee
      }
    );
    logger.info(`Estimate gas result: ${result}`)
  } catch (e) {
    logger.error(`Estimate gas error: ${stringify(e)}`)
    if (ethers.isCallException(e)) {
      await decodeCallExceptionError(e)
    }
  }

  // // send transaction
  // const admin = loadAdminWallet(subChainConfig) // admin is the same as operator in testnet
  // const rawTransaction = await vaultContract.preCommitSubChainProgress.populateTransaction(
  //   0,
  //   {
  //     value: nativeFee
  //   }
  // )
  // await sendAndWaitTransaction(subChainConfig, admin, rawTransaction)
}

// export async function receiveCrossChainMsg() {
//   const dstChain = 0;
//   const subChainConfig = CONFIG.SUB_CHAIN_CONFIGS[dstChain]
//
//   // any EOA can retry L0 msg
//   const deployer = loadDeployerWallet(subChainConfig)
// }

export function decodeExecuteData() {
  // // dump abi contract abi
  // const abi = new ethers.utils.Interface(vaultMetadata.abi);
  // const readableAbi = abi.format(ethers.utils.FormatTypes.minimal);
  // console.log("!!! " + readableAbi)

  // decode transaction
  const contract = loadContractMetadata('Vault')
  const iface = new ethers.Interface(contract.abi)
  const result = iface.decodeFunctionData('updateAll', '0x8fe05a42000000000000000000000000185f38681e3f8f4b403d9265a9e59b8de46501940000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000c76657373656c2d302e312e390000000000000000000000000000000000000000')
  console.log(`Parameters value: ${result}`)
}

export async function simulateCall() {
  const subChainConfig = CONFIG.SUB_CHAIN_CONFIGS[0]
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  logger.info(`Network: ${JSON.stringify(await provider.getNetwork())}`)
  logger.info(`Block: ${await provider.getBlockNumber()}`)

  const vaultContract = loadContract(subChainConfig, "Vault", subChainConfig.ESSENTIAL.VAULT_PROXY_CONTRACT_ADDRESS)

  const tx = {
    to: await vaultContract.getAddress(),
    data: "0x0bf9e23300000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000e3eca9d4e40765c170b56cc4c9ce5669c0469235000000000000000000000000000000000000000000000000000000000000001b98385d3493f2a72952973c9169ea7fe4e18c93184305ccbc117f637df309636d1f2a534d656af260bc3b5e3bf00a218558145ddf07edce23945a1250443a57eb0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000bebc20000000000000000000000000000000000000000000000000000000000000000405adfc85a155cb9594088f7372dc7a8f0605e15e75e9c7954c810969507d475bdb28d24c16cf91c325d1b6118f67a92eeb57881a12b87c45263dec7fe6d1972ad",
  }

  try {
    // Simulate the call
    const result = await provider.call(tx);
    console.log('Call succeeded:', result);
  } catch (error) {
    // Capture and print the error message
    console.error('Call failed:', error);
  }
}

export async function getHistoricalBalance() {
  const subChainConfig = CONFIG.SUB_CHAIN_CONFIGS[0]
  const provider = getOrNewJsonRpcProvider(subChainConfig)
  const lastBlock = await provider.getBlockNumber()
  logger.info(`Network: ${JSON.stringify(await provider.getNetwork())}`)
  logger.info(`Block: ${lastBlock}`)

  const userAddress = "0xAfa8d6FC711a792591A587E1908595747AAd5895"
  const erc20Address = "0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df"

  const ERC20Contract = loadContract(subChainConfig, "ERC20", erc20Address)
  const blockNum = 73

  console.log(`${JSON.stringify(await provider.getFeeData())}`)

  try {
    const ethBalance = await provider.getBalance(userAddress, blockNum)
    const tokenBalance = await ERC20Contract.balanceOf(userAddress, { blockTag: blockNum})
    console.log(`ETH balance: ${ethBalance}. Token balance: ${tokenBalance}`)
  } catch (error) {
    console.error("Error fetching balance:", error);
  }
}

function convertToLEHexString(x: number): string {
  const arr = ethers.toBeArray(x)
  const arrPad = ethers.zeroPadValue(arr, 32)
  const arrLE = ethers.getBytes(arrPad).reverse()
  return ethers.hexlify(arrLE)
}
