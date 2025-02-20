import { getShieldedContractWithCheck, readContractABI } from '../../lib/utils'
import { CONTRACT_DIR } from '../../lib/constants'
import { join } from 'path'

export async function getClearingPrice(ipoCrossAddress: `0x${string}`) {
  const ipoCrossABI = readContractABI(join(CONTRACT_DIR, process.env.IPOCROSS_ABI_PATH!))
  const walletClient = await getShieldedContractWithCheck(ipoCrossABI, ipoCrossAddress)

  const clearingPrice = await walletClient.calculateWeightedAveragePrice()
  console.log(`Current clearing price: ${clearingPrice}`)
}