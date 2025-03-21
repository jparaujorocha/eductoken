// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../vesting/types/VestingTypes.sol";

/**
 * @title IEducVesting
 * @dev Interface for the EducVesting contract
 */
interface IEducVesting {
    /**
     * @dev Creates a linear vesting schedule with structured parameters
     * @param params Linear vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createLinearVesting(VestingTypes.LinearVestingParams calldata params) 
        external 
        returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Legacy method for compatibility - creates a linear vesting schedule
     * @param _beneficiary Recipient of vested tokens
     * @param _totalAmount Total amount of tokens
     * @param _startTime Schedule start time
     * @param _duration Duration in seconds
     * @param _revocable Whether the schedule can be revoked
     * @param _metadata Additional metadata hash
     * @return vestingScheduleId The ID of the created schedule
     */
    function createLinearVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        bool _revocable,
        bytes32 _metadata
    ) external returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Creates a cliff vesting schedule with structured parameters
     * @param params Cliff vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createCliffVesting(VestingTypes.CliffVestingParams calldata params)
        external
        returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Legacy method for compatibility - creates a cliff vesting schedule
     * @param _beneficiary Recipient of vested tokens
     * @param _totalAmount Total amount of tokens
     * @param _startTime Schedule start time
     * @param _cliffDuration Cliff duration in seconds
     * @param _revocable Whether the schedule can be revoked
     * @param _metadata Additional metadata hash
     * @return vestingScheduleId The ID of the created schedule
     */
    function createCliffVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        bool _revocable,
        bytes32 _metadata
    ) external returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Creates a hybrid vesting schedule with structured parameters
     * @param params Hybrid vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createHybridVesting(VestingTypes.HybridVestingParams calldata params)
        external
        returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Legacy method for compatibility - creates a hybrid vesting schedule
     * @param _beneficiary Recipient of vested tokens
     * @param _totalAmount Total amount of tokens
     * @param _startTime Schedule start time
     * @param _duration Total duration in seconds
     * @param _cliffDuration Cliff duration in seconds
     * @param _revocable Whether the schedule can be revoked
     * @param _metadata Additional metadata hash
     * @return vestingScheduleId The ID of the created schedule
     */
    function createHybridVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliffDuration,
        bool _revocable,
        bytes32 _metadata
    ) external returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Creates a milestone-based vesting schedule with structured parameters
     * @param params Milestone vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createMilestoneVesting(VestingTypes.MilestoneVestingParams calldata params)
        external
        returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Legacy method for compatibility - creates a milestone-based vesting schedule
     * @param _beneficiary Recipient of vested tokens
     * @param _totalAmount Total amount of tokens
     * @param _startTime Schedule start time
     * @param _duration Maximum duration in seconds
     * @param _milestoneCount Number of required milestones
     * @param _revocable Whether the schedule can be revoked
     * @param _metadata Additional metadata hash
     * @return vestingScheduleId The ID of the created schedule
     */
    function createMilestoneVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint32 _milestoneCount,
        bool _revocable,
        bytes32 _metadata
    ) external returns (bytes32 vestingScheduleId);
    
    /**
     * @dev Releases vested tokens for the caller
     * @param vestingScheduleId The vesting schedule ID
     */
    function release(bytes32 vestingScheduleId) external;
    
    /**
     * @dev Admin function to release vested tokens to a beneficiary
     * @param vestingScheduleId The vesting schedule ID
     */
    function adminRelease(bytes32 vestingScheduleId) external;
    
    /**
     * @dev Revokes a vesting schedule
     * @param vestingScheduleId The vesting schedule ID
     */
    function revoke(bytes32 vestingScheduleId) external;
    
    /**
     * @dev Completes a milestone for milestone-based vesting
     * @param vestingScheduleId The vesting schedule ID
     */
    function completeMilestone(bytes32 vestingScheduleId) external;
    
    /**
     * @dev Sets a new treasury address
     * @param _treasury New treasury address
     */
    function setTreasury(address _treasury) external;
    
    /**
     * @dev Transfers a vesting schedule to a new beneficiary
     * @param vestingScheduleId The vesting schedule ID
     * @param newBeneficiary New beneficiary address
     */
    function transferVestingSchedule(bytes32 vestingScheduleId, address newBeneficiary) external;
    
    /**
     * @dev Gets the vesting schedule info
     * @param vestingScheduleId The vesting schedule ID
     * @return schedule The vesting schedule details
     */
    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        returns (VestingTypes.VestingSchedule memory schedule);
    
    /**
     * @dev Gets the releasable amount for a vesting schedule
     * @param vestingScheduleId The vesting schedule ID
     * @return releasable The releasable amount
     */
    function getReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        returns (uint256 releasable);
    
    /**
     * @dev Gets vesting schedules for a beneficiary
     * @param _beneficiary The beneficiary address
     * @return vestingScheduleIds The vesting schedule IDs
     */
    function getVestingSchedulesForBeneficiary(address _beneficiary)
        external
        view
        returns (bytes32[] memory vestingScheduleIds);
    
    /**
     * @dev Gets the number of vesting schedules
     * @return count The total number of vesting schedules
     */
    function getVestingSchedulesCount() external view returns (uint256 count);
    
    /**
     * @dev Gets the token used for vesting
     * @return tokenAddress The token address
     */
    function getToken() external view returns (address tokenAddress);
    
    /**
     * @dev Gets the treasury address
     * @return treasuryAddress The treasury address
     */
    function getTreasury() external view returns (address treasuryAddress);
}