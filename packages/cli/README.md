# IPO Cross CLI

A command-line interface for interacting with IPO Cross contracts.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy the example environment file and fill in your values:
```bash
cp .env.example .env
```

Required environment variables:
- `CHAIN_ID`: The chain ID (e.g., 11155111 for Sepolia testnet)
- `RPC_URL`: The RPC endpoint URL
- `FACTORY_ADDRESS`: The deployed IPO Cross Factory contract address
- `FACTORY_ABI_PATH`: Path to the factory contract ABI JSON file
- `IPOCROSS_ABI_PATH`: Path to the IPO Cross contract ABI JSON file
- `PLAYER_NAMES`: Comma-separated list of player names
- `PLAYER_PRIVATE_KEYS`: Comma-separated list of player private keys (must match the order of names)

3. Build the project:
```bash
npm run build
```

## Commands

### Create a new IPO Cross

Creates a new IPO Cross contract through the factory:

```bash
npm run create <token_name> <token_symbol> <token_supply> <reserve_price_eth>
```

Example:
```bash
npm run create "Test Token" TEST 1000000 0.1
```

### Submit Random Orders

Submits random orders from all configured players:

```bash
npm run submit-orders <ipocross_address> <num_orders> <min_price_eth> <max_price_eth> <min_quantity> <max_quantity>
```

Example:
```bash
npm run submit-orders 0x... 5 0.1 0.5 100 1000
```

### Get Current Clearing Price

Checks the current clearing price of an IPO Cross:

```bash
npm run get-price <ipocross_address>
```

Example:
```bash
npm run get-price 0x...
```

### Finalize IPO Cross

Finalizes an IPO Cross and distributes tokens:

```bash
npm run finalize <ipocross_address>
```

Example:
```bash
npm run finalize 0x...
```

## Development

The CLI is built with TypeScript and uses the following key dependencies:
- `seismic-viem`: For private state interactions
- `viem`: For Ethereum interactions
- `dotenv`: For environment variable management

To add new commands or modify existing ones, check the `src/commands` directory. 