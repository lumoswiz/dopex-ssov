# SSOV V3 Backtesting

**Dopex SSOV backtesting tool built with Foundry for testing SSOV V3 contracts.**

## Setup

- Install [Foundry](https://github.com/foundry-rs/foundry).
- Configure Foundry for [fork testing](https://book.getfoundry.sh/forge/fork-testing) by ensuring you have a suitable `rpc_endpoint` set up ([guide](https://book.getfoundry.sh/cheatcodes/rpc?highlight=rpc#description)). Two RPC providers: [Alchemy](https://www.alchemy.com/) and [Infura](https://infura.io/).

## Variables implemented

**User input**

- [ ] blockNumber
- [ ] strikeIndex
- [ ] amount
- [ ] epoch

**Simulated**

- [ ] premium
- [ ] purchaseFee
- [ ] pnl
- [ ] settleFee
- [ ] collateralTokenWithdrawn
- [ ] rewardTokenWithdrawAmounts

**State variables**

- [ ] settlementPrice
- [x] volatility
- [x] currentPrice
