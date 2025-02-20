import {
  type ShieldedContract,
  type ShieldedWalletClient,
  createShieldedWalletClient,
} from 'seismic-viem'
import { Abi, Address, Chain, http, parseEther, formatEther } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { getShieldedContractWithCheck } from '../lib/utils'

interface IPOCrossConfig {
  players: Array<{
    name: string
    privateKey: string
  }>
  wallet: {
    chain: Chain
    rpcUrl: string
  }
  contracts: {
    factory: {
      abi: Abi
      address: Address
    }
    ipoCross: {
      abi: Abi
    }
  }
}

export class IPOCrossApp {
  private config: IPOCrossConfig
  private playerClients: Map<string, ShieldedWalletClient> = new Map()
  private factoryContracts: Map<string, ShieldedContract> = new Map()
  private ipoCrossContracts: Map<Address, Map<string, ShieldedContract>> = new Map()

  constructor(config: IPOCrossConfig) {
    this.config = config
  }

  async init() {
    for (const player of this.config.players) {
      const walletClient = await createShieldedWalletClient({
        chain: this.config.wallet.chain,
        transport: http(this.config.wallet.rpcUrl),
        account: privateKeyToAccount(player.privateKey as `0x${string}`),
      })
      this.playerClients.set(player.name, walletClient)

      const factoryContract = await getShieldedContractWithCheck(
        walletClient,
        this.config.contracts.factory.abi,
        this.config.contracts.factory.address
      )
      this.factoryContracts.set(player.name, factoryContract)
    }
  }

  private getPlayerFactoryContract(playerName: string): ShieldedContract {
    const contract = this.factoryContracts.get(playerName)
    if (!contract) {
      throw new Error(`Factory contract for player ${playerName} not found`)
    }
    return contract
  }

  private async getOrCreateIPOCrossContract(
    playerName: string,
    ipoCrossAddress: Address
  ): Promise<ShieldedContract> {
    const playerContracts = this.ipoCrossContracts.get(ipoCrossAddress)
    if (playerContracts?.has(playerName)) {
      return playerContracts.get(playerName)!
    }

    const walletClient = this.playerClients.get(playerName)
    if (!walletClient) {
      throw new Error(`Wallet client for player ${playerName} not found`)
    }

    const contract = await getShieldedContractWithCheck(
      walletClient,
      this.config.contracts.ipoCross.abi,
      ipoCrossAddress
    )

    if (!this.ipoCrossContracts.has(ipoCrossAddress)) {
      this.ipoCrossContracts.set(ipoCrossAddress, new Map())
    }
    this.ipoCrossContracts.get(ipoCrossAddress)!.set(playerName, contract)
    return contract
  }

  async createIPOCross(
    playerName: string,
    tokenName: string,
    tokenSymbol: string,
    tokenSupply: bigint,
    reservePrice: bigint
  ): Promise<Address> {
    console.log(`- Player ${playerName} creating new IPO Cross`)
    const contract = this.getPlayerFactoryContract(playerName)
    
    const tx = await contract.write.createIPOCross([
      tokenName,
      tokenSymbol,
      tokenSupply,
      reservePrice
    ])

    // Get the created IPO Cross address from events
    const receipt = await tx.wait()
    const event = receipt.logs.find(
      log => log.topics[0] === contract.abi.getEvent('IPOCrossCreated').id
    )
    if (!event) {
      throw new Error('IPO Cross creation event not found')
    }

    const ipoCrossAddress = event.topics[1] as Address
    console.log(`- Created IPO Cross at address: ${ipoCrossAddress}`)
    return ipoCrossAddress
  }

  async submitRandomOrders(
    playerName: string,
    ipoCrossAddress: Address,
    numOrders: number,
    minPrice: bigint,
    maxPrice: bigint,
    minQuantity: bigint,
    maxQuantity: bigint
  ) {
    console.log(`- Player ${playerName} submitting ${numOrders} random orders`)
    const contract = await this.getOrCreateIPOCrossContract(playerName, ipoCrossAddress)

    for (let i = 0; i < numOrders; i++) {
      const price = minPrice + BigInt(Math.floor(Math.random() * Number(maxPrice - minPrice)))
      const quantity = minQuantity + BigInt(Math.floor(Math.random() * Number(maxQuantity - minQuantity)))
      
      await contract.write.submitOrder([price, quantity])
      console.log(`  - Submitted order: ${formatEther(price)} ETH for ${quantity} tokens`)
    }
  }

  async getClearingPrice(playerName: string, ipoCrossAddress: Address): Promise<bigint> {
    console.log(`- Player ${playerName} checking clearing price`)
    const contract = await this.getOrCreateIPOCrossContract(playerName, ipoCrossAddress)
    
    const price = await contract.read.getCurrentClearingPrice()
    console.log(`- Current clearing price: ${formatEther(price)} ETH`)
    return price
  }

  async finalizeIPOCross(playerName: string, ipoCrossAddress: Address) {
    console.log(`- Player ${playerName} finalizing IPO Cross`)
    const contract = await this.getOrCreateIPOCrossContract(playerName, ipoCrossAddress)
    
    await contract.write.finalize()
    console.log('- IPO Cross finalized')

    // Get final distribution stats
    const finalPrice = await contract.read.getClearingPrice()
    const totalTokens = await contract.read.getTotalTokensDistributed()
    const totalValue = await contract.read.getTotalValueRaised()

    console.log(`- Final clearing price: ${formatEther(finalPrice)} ETH`)
    console.log(`- Total tokens distributed: ${totalTokens}`)
    console.log(`- Total value raised: ${formatEther(totalValue)} ETH`)
  }
} 