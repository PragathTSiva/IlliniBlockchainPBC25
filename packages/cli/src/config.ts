import { Chain } from 'viem'
import { readContractABI } from '../lib/utils'
import dotenv from 'dotenv'

dotenv.config()

export async function loadConfig() {
  // Validate required environment variables
  const requiredEnvVars = [
    'CHAIN_ID',
    'RPC_URL',
    'FACTORY_ADDRESS',
    'FACTORY_ABI_PATH',
    'IPOCROSS_ABI_PATH',
    'PLAYER_NAMES',
    'PLAYER_PRIVATE_KEYS'
  ]

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      throw new Error(`Missing required environment variable: ${envVar}`)
    }
  }

  // Load player information
  const playerNames = process.env.PLAYER_NAMES!.split(',')
  const privateKeys = process.env.PLAYER_PRIVATE_KEYS!.split(',')

  if (playerNames.length !== privateKeys.length) {
    throw new Error('Number of player names must match number of private keys')
  }

  const players = playerNames.map((name, i) => ({
    name: name.trim(),
    privateKey: privateKeys[i].trim()
  }))

  // Load contract ABIs
  const factoryABI = await readContractABI(process.env.FACTORY_ABI_PATH!)
  const ipoCrossABI = await readContractABI(process.env.IPOCROSS_ABI_PATH!)

  return {
    players,
    wallet: {
      chain: {
        id: Number(process.env.CHAIN_ID),
      } as Chain,
      rpcUrl: process.env.RPC_URL!,
    },
    contracts: {
      factory: {
        abi: factoryABI,
        address: process.env.FACTORY_ADDRESS as `0x${string}`,
      },
      ipoCross: {
        abi: ipoCrossABI,
      },
    },
  }
} 