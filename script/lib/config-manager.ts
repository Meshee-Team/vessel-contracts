import * as dotenv from "dotenv";
import process from "process";
import fs from "fs";
import path from "path";
import { logger } from "./logger.js";

/**
 * config singleton
 * */
export class ConfigManager {
  private static instance: ConfigManager;
  private readonly configFilePath: string
  private readonly config: Config
  private constructor() {
    dotenv.config()
    const nodeEnv = process.env.NODE_ENV || "local"
    this.configFilePath = `.config.${nodeEnv}.json`

    // Copy the config file to the backup directory
    if (fs.existsSync(this.configFilePath)) {
      const backupDir = path.join('config-backup');
      if (!fs.existsSync(backupDir)) {
        fs.mkdirSync(backupDir, { recursive: true });
      }
      const backupFileName = `${path.basename(this.configFilePath, '.json')}-${new Date().toISOString()}.json`;
      const backupFilePath = path.join(backupDir, backupFileName);
      fs.copyFileSync(this.configFilePath, backupFilePath);
      logger.info(`Backup created for ${this.configFilePath} at ${backupFilePath}`);
    } else {
      logger.error(`Config file ${this.configFilePath} does not exist.`);
      process.exit(-1)
    }

    // Load config from file and validate its content
    const data = fs.readFileSync(this.configFilePath, "utf8")
    this.config = JSON.parse(data)
    logger.info(`load config from ${ this.configFilePath }`)
    this.validateConfig()
  }

  static getInstance() {
    if (!ConfigManager.instance) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  getConfig() {
    return this.config;
  }

  validateConfig() {
    const subChainCnt = this.config.SUB_CHAIN_CNT
    const primaryLogicChainId = this.config.SUB_CHAIN_CONFIGS[0].ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID

    if (this.config.SUB_CHAIN_CONFIGS.length != subChainCnt) {
      throw new Error(`SUB_CHAIN_CNT not match SUB_CHAIN_CONFIGS`)
    }

    for (let i = 0; i < subChainCnt; i++) {
      const subChainConfig = this.config.SUB_CHAIN_CONFIGS[i]
      if (subChainConfig.ESSENTIAL.PRIMARY_LOGIC_CHAIN_ID != primaryLogicChainId) {
        throw new Error(`PRIMARY_LOGIC_CHAIN_ID of chain ${i} invalid`)
      }
      if (subChainConfig.ESSENTIAL.LOGIC_CHAIN_ID != i) {
        throw new Error(`LOGIC_CHAIN_ID of chain ${i} invalid`)
      }
    }
  }

  overwriteConfig() {
    const data = JSON.stringify(this.config, null, 2)
    fs.writeFileSync(this.configFilePath, data)
  }
}

/**
 * load json config file
 */
export interface SubChainCheckpoint {
  LOGIC_CHAIN_ID: number
  L1_LAST_COMMIT_HASH: string,
  L2_LAST_COMMIT_HASH: string
}

export interface EssentialConfig {
  NODE_RPC_URL: string,
  CHAIN_ID: number,
  LOGIC_CHAIN_ID: number,
  PRIMARY_LOGIC_CHAIN_ID: number,
  DEPLOYER_SK: string,
  MAX_FEE_PER_GAS: number,
  MAX_PRIORITY_FEE_PER_GAS: number,
  ENABLE_1559: boolean,
  ADMIN_SK: string,
  ADMIN_ADDRESS: string,
  ENABLE_MULTISIG_ADMIN: boolean,
  OPERATOR_ADDRESSES: string[],
  EXIT_MANAGER_ADDRESSES: string[],
  GITHUB_TOKEN: string,
  RELEASE_TAG: string,
  WETH_CONTRACT_ADDRESS: string,
  OWNER_CONTRACT_ADDRESS: string,

  VAULT_PROXY_CONTRACT_ADDRESS: string,
  VAULT_PROXY_ADMIN_CONTRACT_ADDRESS: string,
  VAULT_IMPL_CONTRACT_ADDRESS: string,
  MANAGER_API_LOGIC_CONTRACT_ADDRESS: string,
  MESSAGE_QUEUE_LOGIC_CONTRACT_ADDRESS: string,
  MULTI_CHAIN_LOGIC_CONTRACT_ADDRESS: string,
  TOKEN_MANAGER_LOGIC_CONTRACT_ADDRESS: string,
  USER_API_LOGIC_CONTRACT_ADDRESS: string,
  PRE_COMMIT_CHECKPOINT: SubChainCheckpoint[],

  LAYER_ZERO_PORTAL_PROXY_CONTRACT_ADDRESS: string,
  LAYER_ZERO_PORTAL_PROXY_ADMIN_CONTRACT_ADDRESS: string,
  LAYER_ZERO_PORTAL_IMPL_CONTRACT_ADDRESS: string,
  LAYER_ZERO_ENDPOINT_ADDRESS: string,
  LAYER_ZERO_ENDPOINT_EID: number
}

export interface TokenInfo {
  ID: number
  SYMBOL: string
  ADDRESS: string
  DECIMALS: number
  LIMIT_DIGIT: number
  PRECISION_DIGIT: number
}

export interface TestConfig {
  TOKENS: TokenInfo[]
}

export interface SubChainConfig {
  ESSENTIAL: EssentialConfig
  TEST: TestConfig
}

export interface Config {
  SUB_CHAIN_CNT: number
  SUB_CHAIN_CONFIGS: SubChainConfig[]
}
