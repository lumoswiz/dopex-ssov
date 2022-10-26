// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct Outputs {
    Inputs inputs;
    WriterDetails writerDetails;
    BuyerDetails buyerDetails;
}

struct Inputs {
    uint256 epoch;
    uint256 blockNumber;
    uint256 strikeIndex;
    uint256 amount;
    uint256 txType; // 0 -> deposit, 1 -> purchase
}

struct WriterDetails {
    uint256 checkpointIndex;
    uint256 collateralTokenWithdrawAmount;
    uint256[] rewardDistributionRatios;
    uint256[] rewardTokenWithdrawAmounts;
}

struct BuyerDetails {
    uint256 premium;
    uint256 purchaseFee;
    uint256 netPnl;
}
