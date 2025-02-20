import { getShieldedContractWithCheck, readContractABI } from '../../lib/utils' 
import { CONTRACT_DIR } from '../../lib/constants'
import { join } from 'path'

export async function finalizeIPO(ipoCrossAddress: `0x${string}`) {
  const ipoCrossABI = readContractABI(join(CONTRACT_DIR, process.env.IPOCROSS_ABI_PATH!))
  const walletClient = await getShieldedContractWithCheck(ipoCrossABI, ipoCrossAddress)

  const tx = await walletClient.finalizeAuction()
  console.log(`Finalize transaction hash: ${tx.hash}`)
  
  const receipt = await tx.wait()
  console.log(`IPO Cross finalized, tokens distributed`)
}