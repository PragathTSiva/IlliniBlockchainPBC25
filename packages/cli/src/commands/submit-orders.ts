import { parseEther } from 'viem'
import { IPOCrossApp } from '../ipocross'
import { loadConfig } from '../config'

async function main() {
  const args = process.argv.slice(2)
  if (args.length !== 6) {
    console.error('Usage: submit-orders <ipocross_address> <num_orders> <min_price_eth> <max_price_eth> <min_quantity> <max_quantity>')
    process.exit(1)
  }

  const [
    ipoCrossAddress,
    numOrdersStr,
    minPriceEthStr,
    maxPriceEthStr,
    minQuantityStr,
    maxQuantityStr
  ] = args

  const numOrders = parseInt(numOrdersStr)
  const minPrice = parseEther(minPriceEthStr)
  const maxPrice = parseEther(maxPriceEthStr)
  const minQuantity = BigInt(minQuantityStr)
  const maxQuantity = BigInt(maxQuantityStr)

  const config = await loadConfig()
  const app = new IPOCrossApp(config)
  await app.init()

  // Submit orders from all players
  for (const player of config.players) {
    await app.submitRandomOrders(
      player.name,
      ipoCrossAddress as `0x${string}`,
      numOrders,
      minPrice,
      maxPrice,
      minQuantity,
      maxQuantity
    )
  }

  console.log('\nAll orders submitted successfully!')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
}) 