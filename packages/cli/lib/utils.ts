import fs from 'fs'
import { type ShieldedWalletClient, getShieldedContract } from 'seismic-viem'
import { Abi, Address } from 'viem'


export async function getShieldedContractWithCheck(
  abi: Abi,
  address: Address,
  walletClient: ShieldedWalletClient
) {
  const contract = getShieldedContract({
    abi: abi,
    address: address,
    client: walletClient,
  })

  const code = await walletClient.getCode({
    address: address,
  })
  if (!code) {
    throw new Error('Please deploy contract before running this script.')
  }

  return contract
}

export function readContractABI(path: string): Abi {
  const abiJson = fs.readFileSync(path, 'utf-8')
  return JSON.parse(abiJson) as Abi
}
