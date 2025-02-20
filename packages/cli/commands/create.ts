import { getShieldedContractWithCheck, readContractABI } from '../lib/utils'
import { CONTRACT_DIR } from '../lib/constants'
import { join } from 'path'
import { createShieldedWalletClient } from 'seismic-viem'

export async function createIPO(tokenName: string, tokenSymbol: string) {
  const factoryABI = readContractABI(join(CONTRACT_DIR, process.env.FACTORY_ABI_PATH!))
  const factoryAddress = process.env.FACTORY_ADDRESS as `0x${string}`

  const walletClient = createShieldedWalletClient({
    chainId: Number(process.env.CHAIN_ID),
    rpcUrl: process.env.RPC_URL!,
  })

  const factory = await getShieldedContractWithCheck(factoryABI, factoryAddress, walletClient)
  const tx = await factory.createIPO(tokenName, tokenSymbol)
  console.log(`Transaction hash: ${tx.hash}`)

  const receipt = await tx.wait()
  console.log(`IPO Cross created at address: ${receipt.contractAddress}`)
}