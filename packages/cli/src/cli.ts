import { program } from 'commander'
import { createIPO } from './commands/create'
import { submitOrders } from './commands/submit-orders'
import { getClearingPrice } from './commands/get-price'
import { finalizeIPO } from './commands/finalize'

program
  .command('create')
  .description('Create a new IPO Cross contract')
  .argument('<token_name>', 'Name of the token')
  .argument('<token_symbol>', 'Symbol of the token')
  .action(createIPO)

program
  .command('submit-orders')
  .description('Submit random orders to an IPO Cross contract')
  .argument('<ipocross_address>', 'Address of the IPO Cross contract')
  .argument('<num_orders>', 'Number of orders to submit', parseInt)
  .argument('<min_price_eth>', 'Minimum price in ETH', parseFloat)
  .argument('<max_price_eth>', 'Maximum price in ETH', parseFloat)
  .argument('<min_quantity>', 'Minimum quantity', parseInt)
  .argument('<max_quantity>', 'Maximum quantity', parseInt)
  .action(submitOrders)

program
  .command('get-price')
  .description('Get the current clearing price of an IPO Cross contract')
  .argument('<ipocross_address>', 'Address of the IPO Cross contract')
  .action(getClearingPrice)

program
  .command('finalize')
  .description('Finalize an IPO Cross contract and distribute tokens')
  .argument('<ipocross_address>', 'Address of the IPO Cross contract')
  .action(finalizeIPO)

program.parse(process.argv)

console.log("Hello from the IPO Cross CLI"); 