// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../structs/Structs.sol";

// Interfaces
import {ISsovV3} from "../interfaces/ISsovV3.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IFeeStrategy} from "../interfaces/IFeeStrategy.sol";
import {IStakingStrategy} from "../interfaces/IStakingStrategy.sol";
import {IOptionPricing} from "../interfaces/IOptionPricing.sol";

contract SimulateV2 is Test {
    using stdStorage for StdStorage;

    ISsovV3 public ssov;

    constructor(ISsovV3 _ssov) {
        ssov = _ssov;
    }

    function deposit(Inputs calldata input)
        public
        returns (Outputs memory output)
    {
        uint256 epoch_ = input.epoch;
        uint256 blockNumber_ = input.blockNumber;
        uint256 strikeIndex_ = input.strikeIndex;
        uint256 amount_ = input.amount;
        uint256 txType_ = input.txType;

        _validate(txType_ == 0, 20);

        setupForkBlockSpecified(blockNumber_);
        _epochNotExpired(ssov, epoch_);

        _valueNotZero(amount_);

        uint256 strike = ssov.getEpochData(epoch_).strikes[strikeIndex_];
        _valueNotZero(strike);

        uint256[] memory rewardDistributionRatios = _updateRewards(
            _getRewards()
        );

        uint256 checkpointIndex = ssov.getEpochStrikeCheckpointsLength(
            epoch_,
            strike
        ) - 1;

        output = Outputs({
            inputs: Inputs({
                epoch: epoch_,
                blockNumber: blockNumber_,
                strikeIndex: strikeIndex_,
                amount: amount_,
                txType: txType_,
                strike: strike
            }),
            writerDetails: WriterDetails({
                checkpointIndex: checkpointIndex,
                collateralTokenWithdrawAmount: 0,
                rewardDistributionRatios: rewardDistributionRatios,
                rewardTokenWithdrawAmounts: new uint256[](0)
            }),
            buyerDetails: BuyerDetails({premium: 0, purchaseFee: 0, netPnl: 0})
        });
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
    function _epochNotExpired(ISsovV3 ssov, uint256 _epoch) private view {
        _validate(!ssov.getEpochData(_epoch).expired, 7);
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
