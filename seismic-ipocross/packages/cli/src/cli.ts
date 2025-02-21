import { join } from 'path'
import { writeFileSync, readFileSync, existsSync } from 'fs'
import { walletClient } from '../commands/WalletClient'
import { CONTRACT_DIR } from '../lib/constants'
import { getShieldedContractWithCheck } from '../lib/utils'
import { readContractABI } from '../lib/utils'
import { createShieldedWalletClient, sanvil } from 'seismic-viem'
import { http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

if (process.argv.length < 3) {
  console.error(
    'Please provide a command. Possible commands: setup, create, finalize, get-price, submit-orders'
  )
  process.exit(1)
}

const decision = process.argv[2]
const CONFIG_PATH = join(process.cwd(), 'contract-config.json')

let factoryAddress: `0x${string}`
let usdcAddress: `0x${string}`

// Load config if exists
if (existsSync(CONFIG_PATH)) {
  const config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'))
  factoryAddress = config.factoryAddress
  usdcAddress = config.usdcAddress
}

const factoryABI = readContractABI(
  join(CONTRACT_DIR, process.env.FACTORY_ABI_PATH!)
)
const ipoCrossABI = readContractABI(
  join(CONTRACT_DIR, process.env.IPOCROSS_ABI_PATH!)
)
const erc20ABI = readContractABI(
  join(CONTRACT_DIR, process.env.ERC20_ABI_PATH!)
)

if (decision === 'setup') {
  // Deploy USDC contract
  const usdcContract = JSON.parse(readFileSync(join(CONTRACT_DIR, process.env.ERC20_ABI_PATH!), 'utf8'))
  const usdcDeployHash = await walletClient.deployContract({
    abi: erc20ABI,
    bytecode: usdcContract.bytecode.object as `0x${string}`,
    args: ['USDC', 'USDC']
  })
  const usdcReceipt = await walletClient.waitForTransactionReceipt({ hash: usdcDeployHash })
  usdcAddress = usdcReceipt.contractAddress!

  // Deploy Factory contract
  const factoryContract = JSON.parse(readFileSync(join(CONTRACT_DIR, process.env.FACTORY_ABI_PATH!), 'utf8'))
  const factoryDeployHash = await walletClient.deployContract({
    abi: factoryABI,
    bytecode: factoryContract.bytecode.object as `0x${string}`,
    args: []
  })
  const factoryReceipt = await walletClient.waitForTransactionReceipt({ hash: factoryDeployHash })
  factoryAddress = factoryReceipt.contractAddress!

  const factory = await getShieldedContractWithCheck(factoryABI, factoryAddress, walletClient)
  await factory.write.setUSDC([usdcAddress])

  // Get USDC contract instance
  const usdc = await getShieldedContractWithCheck(erc20ABI, usdcAddress, walletClient)

  // Mint USDC to each private key address
  const playerPrivateKeys = process.env.PLAYER_PRIVATE_KEYS!.split(',')
  for (const privateKey of playerPrivateKeys) {
    const account = privateKeyToAccount(privateKey as `0x${string}`)
    await usdc.write.mint([account.address, BigInt(200_000_000) * BigInt(1e18)])
  }

  // Save addresses to config file
  writeFileSync(CONFIG_PATH, JSON.stringify({
    factoryAddress,
    usdcAddress
  }, null, 2))

  console.log('Setup complete!')
  console.log(`Factory deployed at: ${factoryAddress}`)
  console.log(`USDC deployed at: ${usdcAddress}`)
} else {
  try {
    const config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'))
    factoryAddress = config.factoryAddress as `0x${string}`
    usdcAddress = config.usdcAddress as `0x${string}`
  } catch (e) {
    console.error('Please run setup first')
    process.exit(1)
  }

  const factory = await getShieldedContractWithCheck(
    factoryABI,
    factoryAddress,
    walletClient
  )

  // Create IPO Cross
  if (decision === 'create') {
    const { result, request } = await factory.simulate.createIPO([process.argv[3], process.argv[4]])
    const tx = await walletClient.writeContract(request)
    console.log(`Transaction hash: ${tx}`)
    const receipt = await walletClient.waitForTransactionReceipt({ hash: tx })
    console.log(`IPO Cross created at address: ${result}`)
  }
  // Finalize IPO Cross
  else if (decision === 'finalize') {
    if (process.argv.length < 4) {
      console.error('Please provide the IPO Cross address')
      process.exit(1)
    }
    const ipoCrossAddress = process.argv[3] as `0x${string}`
    const ipoCross = await getShieldedContractWithCheck(
      ipoCrossABI,
      ipoCrossAddress,
      walletClient
    )
    const tx = await ipoCross.write.finalizeAuction()
    console.log(`Finalize transaction hash: ${tx}`)
    const receipt = await walletClient.waitForTransactionReceipt({ hash: tx })
    console.log(`IPO Cross finalized, tokens distributed`)
  }
  else if (decision === 'get-price') {
    if (process.argv.length < 4) {
      console.error('Please provide the IPO Cross address')
      process.exit(1)
    }
    const ipoCrossAddress = process.argv[3] as `0x${string}`
    const ipoCross = await getShieldedContractWithCheck(
      ipoCrossABI,
      ipoCrossAddress,
      walletClient
    )
    const { result } = await ipoCross.simulate.calculateWeightedAveragePrice()
    const usdcPrice = Number(result) / 1e18
    console.log(`Current clearing price: ${usdcPrice} USDC`)
  } else if (decision === 'submit-orders') {
    if (process.argv.length < 4) {
      console.error('Please provide the IPO Cross address')
      process.exit(1)
    }
    const ipoCrossAddress = process.argv[3] as `0x${string}`
    const playerPrivateKeys = process.env.PLAYER_PRIVATE_KEYS!.split(',')
    
    // Submit 3 orders, one per private key
    for (let i = 0; i < 3; i++) {
      const privateKey = playerPrivateKeys[i]
      
      // Create wallet client for this private key
      const orderWalletClient = await createShieldedWalletClient({
        chain: sanvil,
        transport: http(),
        account: privateKeyToAccount(privateKey as `0x${string}`)
      })

      const orderIpoCross = await getShieldedContractWithCheck(
        ipoCrossABI, 
        ipoCrossAddress,
        orderWalletClient
      )

      const usdc = await getShieldedContractWithCheck(
        erc20ABI,
        usdcAddress,
        orderWalletClient
      )

      // Generate random price between 100-10000 USDC (in wei)
      const price = BigInt(Math.floor(Math.random() * (10000 - 100 + 1) + 100)) * BigInt(1e18)

      // Generate random quantity between 10M-100M tokens (in wei) 
      const quantity = BigInt(100) * BigInt(1e18)

      // Calculate and approve USDC amount
      const usdcAmount = price * quantity / BigInt(1e18)
      await usdc.write.approve([ipoCrossAddress, usdcAmount])

      const tx = await orderIpoCross.write.placeBuyOrder([price, quantity])
      console.log(`Transaction hash: ${tx}`)
      const receipt = await orderWalletClient.waitForTransactionReceipt({ hash: tx })
      console.log(`Order placed with price ${price} and quantity ${quantity}, tx hash: ${tx}`)
    }
  } else {
    throw new Error(`Invalid command: ${decision}`)
  }
}