# SSOV V3 Backtesting

**Dopex SSOV backtesting tool built with Foundry for testing SSOV V3 contracts.**

## Setup

- Install [Foundry](https://github.com/foundry-rs/foundry).
- Configure Foundry for [fork testing](https://book.getfoundry.sh/forge/fork-testing) by ensuring you have a suitable `rpc_endpoint` set up ([guide](https://book.getfoundry.sh/cheatcodes/rpc?highlight=rpc#description)). Two RPC providers: [Alchemy](https://www.alchemy.com/) and [Infura](https://infura.io/).

## Backtests

This project is an extension of [this](https://github.com/lumoswiz/DopexSsovBacktesting) project where I aimed to simplify the process for running backtests. The process to run a collection of backtests now involves:

- Prepare a CSV containing transaction details (`epoch`, `blockNumber`, `strikeIndex`, `amount` and `txType`), save it to the analysis folder [here](./analysis/). **Note:** deposit and purchase transactions set via `txType` equal to 0 and 1, respectively.
- In the command line, run:

```sh
forge test --match-test test_runStrategies --ffi
```

- This requires the use of the Foundry ffi cheatcode. Read about it [here](https://book.getfoundry.sh/cheatcodes/ffi).
- After successfully running the test, the simulated ouptuts are saved in an `output.csv` file in the [analysis](./analysis/) folder. [Here](./analysis/example_output.csv) is an example output file.

## Error Plots

The error rate of this tool was assessed by comparing real SSOV transactions against simulated ones. This was conducted for:

- DPX weekly calls SSOV V3 (contract: `0x10FD85ec522C245a63239b9FC64434F58520bd1f`).
- Epochs: 1-9.
- Writer transactions (deposit -> withdraw).

Results for the collateral token withdrawn and amount of DPX rewards are summarised in diagrams below.

![Collateral token withdrawn](/analysis/img/collateral_error.pdf)
![DPX reward amounts](/analysis/img/dpx_withdraw_error.pdf)
