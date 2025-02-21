# Initial Public Offering System

To build ABIs for a smart contract: `sforge build`

To bring up the validator: `sanvil`

To deploy contracts and mint USDC for sample purposes, run: `bun packages/cli/src/cli.ts setup`

To create the new IPO Cross, run: `bun packages/cli/src/cli.ts create`

To get the current clearing price, run: `bun packages/cli/src/cli.ts get-price <IPO Cross address>`

To submit orders, run: `bun packages/cli/src/cli.ts submit-orders <IPO Cross address>`

To finalize the auction, run: `bun packages/cli/src/cli.ts finalize <IPO Cross address>`
