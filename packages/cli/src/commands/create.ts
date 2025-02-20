import { parseEther } from 'viem'
import { IPOCrossApp } from '../ipocross'
import { loadConfig } from '../config'

async function main() {
  const args = process.argv.slice(2)
  if (args.length !== 4) {
    console.error('Usage: create <token_name> <token_symbol> <token_supply> <reserve_price_eth>')
    process.exit(1)
  }

  const [tokenName, tokenSymbol, tokenSupplyStr, reservePriceEthStr] = args
  const tokenSupply = BigInt(tokenSupplyStr)
  const reservePrice = parseEther(reservePriceEthStr)

  const config = await loadConfig()
  const app = new IPOCrossApp(config)
  await app.init()

  // Use the first player as the creator
  const creator = config.players[0].name
  const ipoCrossAddress = await app.createIPOCross(
    creator,
    tokenName,
    tokenSymbol,
    tokenSupply,
    reservePrice
  )

  console.log('\nIPO Cross created successfully!')
  console.log('Address:', ipoCrossAddress)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
}) 