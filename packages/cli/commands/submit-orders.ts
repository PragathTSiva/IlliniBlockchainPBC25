import { getShieldedContractWithCheck, readContractABI } from '../../lib/utils'
import { CONTRACT_DIR } from '../../lib/constants'
import { join } from 'path'
import { suint256 } from 'seismic-viem'

export async function submitOrders(
  ipoCrossAddress: `0x${string}`, 
  numOrders: number,
  minPriceEth: number, 
  maxPriceEth: number,
  minQuantity: number,
  maxQuantity: number
) {
  const ipoCrossABI = readContractABI(join(CONTRACT_DIR, process.env.IPOCROSS_ABI_PATH!))
  const walletClient = await getShieldedContractWithCheck(ipoCrossABI, ipoCrossAddress)

  const playerNames = process.env.PLAYER_NAMES!.split(',')
  const playerPrivateKeys = process.env.PLAYER_PRIVATE_KEYS!.split(',')

  for (let i = 0; i < numOrders; i++) {
    const playerIndex = Math.floor(Math.random() * playerNames.length)
    const price = suint256(Math.floor(Math.random() * (maxPriceEth - minPriceEth + 1) + minPriceEth) * 1e18)
    const quantity = suint256(Math.floor(Math.random() * (maxQuantity - minQuantity + 1) + minQuantity) * 1e18)

    const tx = await walletClient.placeBuyOrder(price, quantity, {
      account: playerPrivateKeys[playerIndex]
    })
    console.log(`Order placed by ${playerNames[playerIndex]}, tx hash: ${tx.hash}`)
  }
}