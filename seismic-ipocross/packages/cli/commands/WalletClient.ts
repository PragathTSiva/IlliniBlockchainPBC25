import { createShieldedWalletClient, sanvil, seismicDevnet } from 'seismic-viem'
import { http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { config } from 'dotenv'
import { anvil } from 'viem/chains'

config()

// Ensure private key is properly formatted with 0x prefix and 64 characters
const rawKey = process.env.PRIVATE_KEY?.replace('0x', '') || ''
const paddedKey = rawKey.padStart(64, '0')
const privateKey = `0x${paddedKey}` as `0x${string}`

if (!process.env.PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY environment variable is required')
}

// Validate private key format
if (!/^0x[0-9a-fA-F]{64}$/.test(privateKey)) {
  console.log(privateKey)
  throw new Error('Invalid private key format. Must be a 32-byte hex string with 0x prefix')
}

export const walletClient = await createShieldedWalletClient({
  chain: sanvil,
  transport: http(),
  account: privateKeyToAccount(privateKey)
})
