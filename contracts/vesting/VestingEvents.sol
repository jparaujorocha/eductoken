// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./types/VestingTypes.sol";

library VestingEvents {
    event VestingScheduleCreated(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 amount,
        VestingTypes.VestingType vestingType,
        uint256 startTime,
        uint256 duration
    );

    event VestingScheduleReleased(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 unreleasedAmount
    );

    event MilestoneCompleted(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint32 milestoneNumber,
        uint256 releaseAmount
    );

    event TreasuryUpdated(
        address previousTreasury,
        address newTreasury
    );
    
    event VestingScheduleTransferred(
        bytes32 vestingScheduleId,
        address previousBeneficiary,
        address newBeneficiary
    );
    
    event VestingContractCreated(
        address indexed vestingContract,
        address indexed creator,
        address indexed token
    );
}