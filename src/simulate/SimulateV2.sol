// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../structs/Structs.sol";
import "./Key.sol";

// Interfaces
import {ISsovV3} from "../interfaces/ISsovV3.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IFeeStrategy} from "../interfaces/IFeeStrategy.sol";
import {IStakingStrategy} from "../interfaces/IStakingStrategy.sol";
import {IOptionPricing} from "../interfaces/IOptionPricing.sol";

contract SimulateV2 is Test {
    using stdStorage for StdStorage;
    using Key for Inputs;

    ISsovV3 public ssov;

    uint256 internal constant OPTIONS_PRECISION = 1e18;
    uint256 internal constant DEFAULT_PRECISION = 1e8;
    uint256 internal constant REWARD_PRECISION = 1e18;

    mapping(bytes32 => Outputs) public buys;
    mapping(bytes32 => Outputs) public writes;

    constructor(ISsovV3 _ssov) {
        ssov = _ssov;
    }

    function deposit(Inputs calldata input) public {
        _validate(input.txType == 0, 20);
        setupForkBlockSpecified(input.blockNumber);
        _epochNotExpired(input.epoch);
        _valueNotZero(input.amount);
        _valueNotZero(input.strike);

        bytes32 key = input.compute();

        uint256[] memory rewardDistributionRatios = _updateRewards(
            _getRewards()
        );

        uint256 checkpointIndex = ssov.getEpochStrikeCheckpointsLength(
            input.epoch,
            input.strike
        ) - 1;

        writes[key].inputs = input;
        writes[key].writerDetails.checkpointIndex = checkpointIndex;
        writes[key]
            .writerDetails
            .rewardDistributionRatios = rewardDistributionRatios;
    }

    function purchase(Inputs calldata input) public {
        _validate(input.txType == 1, 21);

        setupForkBlockSpecified(input.blockNumber);
        _epochNotExpired(input.epoch);
        _valueNotZero(input.amount);
        _valueNotZero(input.strike);

        bytes32 key = input.compute();

        uint256 premium = _calculatePremium(
            input.epoch,
            input.strike,
            input.amount
        );
        uint256 purchaseFee = _calculatePurchaseFees(
            input.strike,
            input.amount
        );

        buys[key].inputs = input;
        buys[key].buyerDetails.premium = premium;
        buys[key].buyerDetails.purchaseFee = purchaseFee;
    }

    function settle(Outputs calldata output) public {
        _validate(output.inputs.txType == 1, 21);

        setupFork();
        _epochExpired(output.inputs.epoch);
        _valueNotZero(output.inputs.amount);
        _valueNotZero(output.inputs.strike);

        bytes32 key = output.inputs.compute();

        uint256 settlementPrice = ssov
            .getEpochData(output.inputs.epoch)
            .settlementPrice;

        uint256 pnl = _calculatePnl(
            settlementPrice,
            output.inputs.strike,
            output.inputs.amount,
            ssov
                .getEpochData(output.inputs.epoch)
                .settlementCollateralExchangeRate
        );

        uint256 settlementFee = _calculateSettlementFees(pnl);

        uint256 netPnl;

        if (pnl == 0) {
            netPnl = 0;
        } else {
            netPnl = pnl - settlementFee;
        }

        buys[key].buyerDetails.netPnl = netPnl;
    }

    function withdraw(Outputs calldata output) public {
        _validate(output.inputs.txType == 0, 20);

        setupFork();
        _epochExpired(output.inputs.epoch);
        _valueNotZero(output.inputs.amount);
        _valueNotZero(output.inputs.strike);

        bytes32 key = output.inputs.compute();

        uint256 extractedAmount;
        uint256 calculatedAccruedPremium;
        uint256 pointer = output.writerDetails.checkpointIndex;

        while (
            (extractedAmount < output.inputs.amount) &&
            (pointer <
                ssov.getEpochStrikeCheckpointsLength(
                    output.inputs.epoch,
                    output.inputs.strike
                ))
        ) {
            uint256 _remainingRequired = output.inputs.amount - extractedAmount;

            if (
                ssov
                    .checkpoints(
                        output.inputs.epoch,
                        output.inputs.strike,
                        pointer
                    )
                    .activeCollateral >= _remainingRequired
            ) {
                extractedAmount += _remainingRequired;
                calculatedAccruedPremium +=
                    (((output.inputs.amount * DEFAULT_PRECISION) /
                        ssov
                            .checkpoints(
                                output.inputs.epoch,
                                output.inputs.strike,
                                pointer
                            )
                            .activeCollateral) *
                        ssov
                            .checkpoints(
                                output.inputs.epoch,
                                output.inputs.strike,
                                pointer
                            )
                            .accruedPremium) /
                    DEFAULT_PRECISION;
            } else {
                extractedAmount += ssov
                    .checkpoints(
                        output.inputs.epoch,
                        output.inputs.strike,
                        pointer
                    )
                    .activeCollateral;
                calculatedAccruedPremium += ssov
                    .checkpoints(
                        output.inputs.epoch,
                        output.inputs.strike,
                        pointer
                    )
                    .accruedPremium;
                pointer += 1;
            }
        }

        uint256 accruedPremium = ((ssov
            .checkpoints(
                output.inputs.epoch,
                output.inputs.strike,
                output.writerDetails.checkpointIndex
            )
            .accruedPremium + calculatedAccruedPremium) *
            output.inputs.amount) /
            ssov
                .checkpoints(
                    output.inputs.epoch,
                    output.inputs.strike,
                    output.writerDetails.checkpointIndex
                )
                .totalCollateral;

        uint256 collateralTokenWithdrawAmount = ((ssov
            .checkpoints(
                output.inputs.epoch,
                output.inputs.strike,
                output.writerDetails.checkpointIndex
            )
            .totalCollateral -
            _calculatePnl(
                ssov.getEpochData(output.inputs.epoch).settlementPrice,
                output.inputs.strike,
                output.inputs.amount,
                ssov
                    .getEpochData(output.inputs.epoch)
                    .settlementCollateralExchangeRate
            )) * output.inputs.amount) /
            ssov
                .checkpoints(
                    output.inputs.epoch,
                    output.inputs.strike,
                    output.writerDetails.checkpointIndex
                )
                .totalCollateral;

        // Add premiums
        collateralTokenWithdrawAmount += accruedPremium;

        uint256[] memory rewardTokenWithdrawAmounts = getUintArray(
            ssov
                .getEpochData(output.inputs.epoch)
                .rewardTokensToDistribute
                .length
        );

        // Calculate rewards
        for (uint256 i; i < rewardTokenWithdrawAmounts.length; ) {
            rewardTokenWithdrawAmounts[i] +=
                ((ssov
                    .getEpochData(output.inputs.epoch)
                    .rewardDistributionRatios[i] -
                    output.writerDetails.rewardDistributionRatios[i]) *
                    output.inputs.amount) /
                ssov.collateralPrecision();

            if (
                ssov
                    .getEpochStrikeData(
                        output.inputs.epoch,
                        output.inputs.strike
                    )
                    .totalPremiums > 0
            )
                rewardTokenWithdrawAmounts[i] +=
                    (accruedPremium *
                        ssov
                            .getEpochStrikeData(
                                output.inputs.epoch,
                                output.inputs.strike
                            )
                            .rewardStoredForPremiums[i]) /
                    ssov
                        .getEpochStrikeData(
                            output.inputs.epoch,
                            output.inputs.strike
                        )
                        .totalPremiums;

            unchecked {
                ++i;
            }
        }

        writes[key]
            .writerDetails
            .collateralTokenWithdrawAmount = collateralTokenWithdrawAmount;
        writes[key]
            .writerDetails
            .rewardTokenWithdrawAmounts = rewardTokenWithdrawAmounts;
    }

    /// -----------------------------------------------------------------------
    /// Helper functions: deposit
    /// -----------------------------------------------------------------------

    function _getRewards()
        public
        returns (uint256[] memory rewardTokenAmounts)
    {
        uint256 epoch = ssov.currentEpoch();
        uint256 startTime = ssov.getEpochData(epoch).startTime;
        uint256 expiry = ssov.getEpochData(epoch).expiry;

        // Slot finder logic
        uint256 mappingSlot = 1;
        uint256 elementSize = 1;
        uint256 mapUint = getMapLocation(mappingSlot, epoch);

        uint256 rewardTokenLengths = IStakingStrategy(
            ssov.addresses().stakingStrategy
        ).getRewardTokens().length;

        rewardTokenAmounts = new uint256[](rewardTokenLengths);

        for (uint256 i = 0; i < rewardTokenLengths; ) {
            uint256 rewardsPerEpoch = uint256(
                vm.load(
                    ssov.addresses().stakingStrategy,
                    bytes32(getArrayLocation(mapUint, i, elementSize))
                )
            );

            rewardTokenAmounts[i] =
                (rewardsPerEpoch / (expiry - startTime)) *
                (block.timestamp - startTime);

            unchecked {
                ++i;
            }
        }
    }

    function _updateRewards(uint256[] memory totalRewardsArray)
        public
        view
        returns (uint256[] memory rewardsDistributionRatios)
    {
        rewardsDistributionRatios = getUintArray(totalRewardsArray.length);
        uint256 newRewardsCollected;

        uint256 epoch = ssov.currentEpoch();

        for (uint256 i = 0; i < totalRewardsArray.length; ) {
            // Calculate the new rewards accrued
            newRewardsCollected =
                totalRewardsArray[i] -
                ssov.getEpochData(epoch).totalRewardsCollected[i];

            // Calculate the reward distribution ratios for new rewards accrued
            if (ssov.getEpochData(epoch).totalCollateralBalance == 0) {
                rewardsDistributionRatios[i] = 0;
            } else {
                rewardsDistributionRatios[i] =
                    (newRewardsCollected * ssov.collateralPrecision()) /
                    ssov.getEpochData(epoch).totalCollateralBalance;
            }

            rewardsDistributionRatios[i] += ssov
                .getEpochData(epoch)
                .rewardDistributionRatios[i];

            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Helper functions: purchase
    /// -----------------------------------------------------------------------

    function _calculatePremium(
        uint256 epoch,
        uint256 strike,
        uint256 amount
    ) public view returns (uint256 premium) {
        (, uint256 expiry) = ssov.getEpochTimes(epoch);

        premium =
            IOptionPricing(ssov.addresses().optionPricing).getOptionPrice(
                ssov.isPut(),
                expiry,
                strike,
                ssov.getUnderlyingPrice(),
                ssov.getVolatility(strike)
            ) *
            amount;

        premium =
            (premium * ssov.collateralPrecision()) /
            (ssov.getCollateralPrice() * OPTIONS_PRECISION);
    }

    function _calculatePurchaseFees(uint256 strike, uint256 amount)
        public
        returns (uint256 fee)
    {
        uint256 purchaseFeePercentage = stdstore
            .target(ssov.addresses().feeStrategy)
            .sig("ssovFeeStructures(address)")
            .with_key(address(ssov))
            .read_uint();

        fee =
            ((purchaseFeePercentage * amount * ssov.getUnderlyingPrice()) /
                1e10) /
            1e18;

        if (ssov.getUnderlyingPrice() < strike) {
            uint256 feeMultiplier = ((strike * 100) /
                (ssov.getUnderlyingPrice()) -
                100) + 100;
            fee = (feeMultiplier * fee) / 100;
        }

        return ((fee * ssov.collateralPrecision()) / ssov.getCollateralPrice());
    }

    /// -----------------------------------------------------------------------
    /// Helper functions: settle
    /// -----------------------------------------------------------------------

    function _calculatePnl(
        uint256 price,
        uint256 strike,
        uint256 amount,
        uint256 collateralExchangeRate
    ) public view returns (uint256) {
        if (ssov.isPut())
            return
                strike > price
                    ? ((strike - price) *
                        amount *
                        ssov.collateralPrecision() *
                        collateralExchangeRate) /
                        (OPTIONS_PRECISION *
                            DEFAULT_PRECISION *
                            DEFAULT_PRECISION)
                    : 0;
        return
            price > strike
                ? (((price - strike) *
                    amount *
                    ssov.collateralPrecision() *
                    collateralExchangeRate) / price) /
                    (OPTIONS_PRECISION * DEFAULT_PRECISION)
                : 0;
    }

    function _calculateSettlementFees(uint256 pnl)
        public
        returns (uint256 fee)
    {
        uint256 settlementFeePercentage = stdstore
            .target(ssov.addresses().feeStrategy)
            .sig("ssovFeeStructures(address)")
            .with_key(address(ssov))
            .depth(1)
            .read_uint();

        fee = (settlementFeePercentage * pnl) / 1e10;
    }

    /// -----------------------------------------------------------------------
    /// View functions
    /// -----------------------------------------------------------------------
    function getBuy(bytes32 key) public view returns (Outputs memory output) {
        return buys[key];
    }

    function getWrite(bytes32 key) public view returns (Outputs memory output) {
        return writes[key];
    }

    /// -----------------------------------------------------------------------
    /// Private functions for reverts
    /// -----------------------------------------------------------------------

    /// @dev Internal function to validate a condition
    /// @param _condition boolean condition
    /// @param _errorCode error code to revert with
    function _validate(bool _condition, uint256 _errorCode) private pure {
        if (!_condition) revert SsovV3Error(_errorCode);
    }

    /// @dev Internal function to check if the value passed is not zero. Revert if 0.
    /// @param _value the value
    function _valueNotZero(uint256 _value) private pure {
        _validate(!valueGreaterThanZero(_value), 8);
    }

    /// @dev Internal function to check if the epoch passed is not expired. Revert if expired.
    /// @param _epoch the epoch
    function _epochNotExpired(uint256 _epoch) private view {
        _validate(!ssov.getEpochData(_epoch).expired, 7);
    }

    /// @dev Internal function to check if the epoch passed is expired. Revert if not expired.
    /// @param _epoch the epoch
    function _epochExpired(uint256 _epoch) private view {
        _validate(ssov.getEpochData(_epoch).expired, 9);
    }

    /// -----------------------------------------------------------------------
    /// Pure functions
    /// -----------------------------------------------------------------------

    function valueGreaterThanZero(uint256 _value)
        public
        pure
        returns (bool result)
    {
        assembly {
            result := iszero(_value)
        }
    }

    function getMapLocation(uint256 slot, uint256 key)
        public
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(key, slot)));
    }

    function getUintArray(uint256 _arrayLength)
        public
        pure
        returns (uint256[] memory result)
    {
        result = new uint256[](_arrayLength);
    }

    function getArrayLocation(
        uint256 slot,
        uint256 index,
        uint256 elementSize
    ) public pure returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(slot))) + (index * elementSize);
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    error SsovV3Error(uint256);

    /// -----------------------------------------------------------------------
    /// Helper Functions: Fork
    /// -----------------------------------------------------------------------

    /// @notice Creates and selects a new arbitrum mainnet fork.
    function setupFork() public returns (uint256 id) {
        id = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        assertEq(vm.activeFork(), id);
    }

    /// @notice Creates and selects a new arbitrum mainnet fork at a specified block.
    function setupForkBlockSpecified(uint256 blk) public returns (uint256 id) {
        id = vm.createSelectFork(vm.rpcUrl("arbitrum"), blk);
        assertEq(vm.activeFork(), id);
    }
}
