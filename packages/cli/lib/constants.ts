import { join } from 'path'

export const CONTRACT_DIR = join(__dirname, '../../contracts')
export const USDC_ADDRESS = process.env.USDC_ADDRESS as `0x${string}`