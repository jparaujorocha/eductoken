// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";

/**
 * @title EducVesting
 * @dev Contract for managing token vesting schedules for EducToken
 * Supports multiple vesting schedules with different terms
 */
contract EducVesting is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Vesting types
    enum VestingType {
        Linear,     // Steady release over time
        Cliff,      // Nothing until a point, then everything
        Milestone,  // Release based on specific education milestones
        Hybrid      // Combination of cliff and linear
    }

    // Vesting schedule structure
    struct VestingSchedule {
        address beneficiary;        // Address receiving tokens
        uint256 totalAmount;        // Total tokens allocated
        uint256 released;           // Tokens already released
        uint256 startTime;          // Schedule start timestamp
        uint256 duration;           // Duration in seconds
        uint256 cliffDuration;      // Duration of cliff period (if applicable)
        uint32 milestoneCount;      // Number of milestones (if applicable)
        uint32 milestonesReached;   // Number of reached milestones (if applicable)
        bool revocable;             // Whether the schedule can be revoked
        bool revoked;               // Whether the schedule was revoked
        VestingType vestingType;    // Type of vesting schedule
        bytes32 metadata;           // Additional schedule details
    }

    // Storage
    IERC20 public token;             // EducToken address
    address public treasury;         // Treasury address for revoked tokens

    // Vesting tracking
    uint256 public vestingSchedulesCount;
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public holdersVestingCount;
    mapping(address => mapping(uint256 => bytes32)) public holderVestingSchedules;

    // Events
    event VestingScheduleCreated(
        bytes32 vestingScheduleId,
        address beneficiary,
        uint256 amount,
        VestingType vestingType,
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

    /**
     * @dev Constructor initializes the vesting contract
     * @param _token Address of the EducToken
     * @param _treasury Address where revoked tokens go
     * @param _admin Admin address
     */
    constructor(address _token, address _treasury, address _admin) {
        require(_token != address(0), "EducVesting: Token cannot be zero address");
        require(_treasury != address(0), "EducVesting: Treasury cannot be zero address");
        require(_admin != address(0), "EducVesting: Admin cannot be zero address");

        token = IERC20(_token);
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EducRoles.ADMIN_ROLE, _admin);
        _grantRole(EducRoles.PAUSER_ROLE, _admin);
    }

    /**
     * @dev Creates a linear vesting schedule
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
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32)
    {
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            0,
            0,
            0,
            _revocable,
            VestingType.Linear,
            _metadata
        );
    }

    /**
     * @dev Creates a cliff vesting schedule
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
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32)
    {
        // For cliff vesting, total duration equals cliff duration
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _cliffDuration,
            0,
            0,
            _revocable,
            VestingType.Cliff,
            _metadata
        );
    }

    /**
     * @dev Creates a hybrid vesting schedule with cliff and linear components
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
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32)
    {
        require(_cliffDuration < _duration, "EducVesting: Cliff must be shorter than duration");
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            _cliffDuration,
            0,
            0,
            _revocable,
            VestingType.Hybrid,
            _metadata
        );
    }

    /**
     * @dev Creates a milestone-based vesting schedule
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
    )
        external
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32)
    {
        require(_milestoneCount > 0, "EducVesting: Milestone count must be positive");
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            0,
            _milestoneCount,
            0,
            _revocable,
            VestingType.Milestone,
            _metadata
        );
    }

    /**
     * @dev Internal function to create a vesting schedule
     * @return vestingScheduleId The ID of the created schedule
     */
    function _createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliffDuration,
        uint32 _milestoneCount,
        uint32 _milestonesReached,
        bool _revocable,
        VestingType _vestingType,
        bytes32 _metadata
    )
        internal
        returns (bytes32)
    {
        require(_beneficiary != address(0), "EducVesting: Beneficiary cannot be zero address");
        require(_totalAmount > 0, "EducVesting: Amount must be greater than zero");
        require(_duration > 0, "EducVesting: Duration must be greater than zero");
        
        // For future schedules, start time must be in the future
        if (_startTime == 0) {
            _startTime = block.timestamp;
        } else {
            require(_startTime >= block.timestamp, "EducVesting: Start time must be in the future");
        }

        // Create schedule ID
        bytes32 vestingScheduleId = keccak256(
            abi.encodePacked(
                _beneficiary,
                _totalAmount,
                _startTime,
                _duration,
                _cliffDuration,
                _vestingType,
                vestingSchedulesCount
            )
        );

        // Store the schedule
        vestingSchedules[vestingScheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            released: 0,
            startTime: _startTime,
            duration: _duration,
            cliffDuration: _cliffDuration,
            milestoneCount: _milestoneCount,
            milestonesReached: _milestonesReached,
            revocable: _revocable,
            revoked: false,
            vestingType: _vestingType,
            metadata: _metadata
        });

        // Track schedules by holder
        uint256 holderVestingCount = holdersVestingCount[_beneficiary];
        holderVestingSchedules[_beneficiary][holderVestingCount] = vestingScheduleId;
        holdersVestingCount[_beneficiary] = holderVestingCount + 1;
        vestingSchedulesCount++;

        // Transfer tokens to this contract
        token.safeTransferFrom(msg.sender, address(this), _totalAmount);

        emit VestingScheduleCreated(
            vestingScheduleId,
            _beneficiary,
            _totalAmount,
            _vestingType,
            _startTime,
            _duration
        );

        return vestingScheduleId;
    }

    /**
     * @dev Releases vested tokens for the caller
     * @param vestingScheduleId The vesting schedule ID
     */
    function release(bytes32 vestingScheduleId) 
        external
        nonReentrant
        whenNotPaused
    {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(schedule.beneficiary == msg.sender, "EducVesting: Only beneficiary can release");
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        
        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable > 0, "EducVesting: No tokens are due for release");
        
        schedule.released += releasable;
        
        token.safeTransfer(schedule.beneficiary, releasable);
        
        emit VestingScheduleReleased(
            vestingScheduleId,
            schedule.beneficiary,
            releasable
        );
    }

    /**
     * @dev Admin function to release vested tokens to a beneficiary
     * @param vestingScheduleId The vesting schedule ID
     */
    function adminRelease(bytes32 vestingScheduleId) 
        external
        nonReentrant
        whenNotPaused
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        
        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable > 0, "EducVesting: No tokens are due for release");
        
        schedule.released += releasable;
        
        token.safeTransfer(schedule.beneficiary, releasable);
        
        emit VestingScheduleReleased(
            vestingScheduleId,
            schedule.beneficiary,
            releasable
        );
    }

    /**
     * @dev Revokes a vesting schedule
     * @param vestingScheduleId The vesting schedule ID
     */
    function revoke(bytes32 vestingScheduleId) 
        external
        nonReentrant
        whenNotPaused
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(schedule.revocable, "EducVesting: Schedule is not revocable");
        require(!schedule.revoked, "EducVesting: Schedule already revoked");
        
        uint256 releasable = _computeReleasableAmount(schedule);
        uint256 unreleased = schedule.totalAmount - schedule.released - releasable;
        
        // Mark as revoked
        schedule.revoked = true;
        
        // Transfer releasable tokens to beneficiary
        if (releasable > 0) {
            schedule.released += releasable;
            token.safeTransfer(schedule.beneficiary, releasable);
            
            emit VestingScheduleReleased(
                vestingScheduleId,
                schedule.beneficiary,
                releasable
            );
        }
        
        // Transfer unreleased tokens to treasury
        if (unreleased > 0) {
            token.safeTransfer(treasury, unreleased);
            
            emit VestingScheduleRevoked(
                vestingScheduleId,
                schedule.beneficiary,
                unreleased
            );
        }
    }

    /**
     * @dev Completes a milestone for milestone-based vesting
     * @param vestingScheduleId The vesting schedule ID
     */
    function completeMilestone(bytes32 vestingScheduleId) 
        external
        nonReentrant
        whenNotPaused
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(schedule.vestingType == VestingType.Milestone, "EducVesting: Not a milestone schedule");
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        require(schedule.milestonesReached < schedule.milestoneCount, "EducVesting: All milestones completed");
        
        // Increment milestone count
        schedule.milestonesReached++;
        
        // Calculate release amount per milestone
        uint256 amountPerMilestone = schedule.totalAmount / schedule.milestoneCount;
        
        // Release tokens
        schedule.released += amountPerMilestone;
        
        token.safeTransfer(schedule.beneficiary, amountPerMilestone);
        
        emit MilestoneCompleted(
            vestingScheduleId,
            schedule.beneficiary,
            schedule.milestonesReached,
            amountPerMilestone
        );
    }

    /**
     * @dev Sets a new treasury address
     * @param _treasury New treasury address
     */
    function setTreasury(address _treasury) 
        external
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(_treasury != address(0), "EducVesting: Treasury cannot be zero address");
        
        address oldTreasury = treasury;
        treasury = _treasury;
        
        emit TreasuryUpdated(oldTreasury, _treasury);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Computes the releasable amount for a vesting schedule
     * @param _schedule The vesting schedule
     * @return The releasable amount
     */
    function _computeReleasableAmount(VestingSchedule memory _schedule)
        internal
        view
        returns (uint256)
    {
        if (_schedule.revoked) {
            return 0;
        }
        
        uint256 currentTime = block.timestamp;
        
        if (currentTime < _schedule.startTime) {
            return 0;
        }
        
        uint256 vestedAmount;
        
        if (_schedule.vestingType == VestingType.Linear) {
            // Linear vesting calculation
            if (currentTime >= _schedule.startTime + _schedule.duration) {
                vestedAmount = _schedule.totalAmount;
            } else {
                vestedAmount = _schedule.totalAmount * (currentTime - _schedule.startTime) / _schedule.duration;
            }
        } else if (_schedule.vestingType == VestingType.Cliff) {
            // Cliff vesting calculation
            if (currentTime >= _schedule.startTime + _schedule.cliffDuration) {
                vestedAmount = _schedule.totalAmount;
            } else {
                vestedAmount = 0;
            }
        } else if (_schedule.vestingType == VestingType.Hybrid) {
            // Hybrid vesting calculation (cliff + linear)
            if (currentTime < _schedule.startTime + _schedule.cliffDuration) {
                vestedAmount = 0;
            } else if (currentTime >= _schedule.startTime + _schedule.duration) {
                vestedAmount = _schedule.totalAmount;
            } else {
                uint256 timeAfterCliff = currentTime - (_schedule.startTime + _schedule.cliffDuration);
                uint256 linearDuration = _schedule.duration - _schedule.cliffDuration;
                vestedAmount = _schedule.totalAmount * timeAfterCliff / linearDuration;
            }
        } else if (_schedule.vestingType == VestingType.Milestone) {
            // Milestone vesting calculation
            vestedAmount = _schedule.totalAmount * _schedule.milestonesReached / _schedule.milestoneCount;
        }
        
        return vestedAmount - _schedule.released;
    }

    /**
 * @dev Gets the vesting schedule info
 * @param vestingScheduleId The vesting schedule ID
 * @return beneficiary Address of the beneficiary
 * @return totalAmount Total amount of tokens in the schedule
 * @return released Amount of tokens already released
 * @return startTime Start time of the vesting schedule
 * @return duration Duration of the vesting schedule in seconds
 * @return cliffDuration Duration of the cliff period in seconds
 * @return milestoneCount Number of milestones (if applicable)
 * @return milestonesReached Number of milestones reached (if applicable)
 * @return revocable Whether the schedule is revocable
 * @return revoked Whether the schedule has been revoked
 * @return vestingType Type of vesting schedule
 * @return metadata Additional metadata for the schedule
 */
function getVestingSchedule(bytes32 vestingScheduleId) 
    external 
    view 
    returns (
        address beneficiary,
        uint256 totalAmount,
        uint256 released,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        uint32 milestoneCount,
        uint32 milestonesReached,
        bool revocable,
        bool revoked,
        VestingType vestingType,
        bytes32 metadata
    ) 
{
    VestingSchedule memory schedule = vestingSchedules[vestingScheduleId];
    
    return (
        schedule.beneficiary,
        schedule.totalAmount,
        schedule.released,
        schedule.startTime,
        schedule.duration,
        schedule.cliffDuration,
        schedule.milestoneCount,
        schedule.milestonesReached,
        schedule.revocable,
        schedule.revoked,
        schedule.vestingType,
        schedule.metadata
    );
}

    /**
     * @dev Gets the releasable amount for a vesting schedule
     * @param vestingScheduleId The vesting schedule ID
     * @return The releasable amount
     */
    function getReleasableAmount(bytes32 vestingScheduleId) 
        external 
        view 
        returns (uint256) 
    {
        VestingSchedule memory schedule = vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(schedule);
    }

    /**
     * @dev Gets vesting schedules for a beneficiary
     * @param _beneficiary The beneficiary address
     * @return vestingScheduleIds The vesting schedule IDs
     */
    function getVestingSchedulesForBeneficiary(address _beneficiary)
        external
        view
        returns (bytes32[] memory)
    {
        uint256 count = holdersVestingCount[_beneficiary];
        bytes32[] memory ids = new bytes32[](count);
        
        for (uint256 i = 0; i < count; i++) {
            ids[i] = holderVestingSchedules[_beneficiary][i];
        }
        
        return ids;
    }

    /**
     * @dev Gets vesting schedule details by index
     * @param _beneficiary The beneficiary address
     * @param _index The schedule index
     * @return The vesting schedule ID
     */
    function getVestingScheduleByAddressAndIndex(address _beneficiary, uint256 _index)
        external
        view
        returns (bytes32)
    {
        require(_index < holdersVestingCount[_beneficiary], "EducVesting: Index out of bounds");
        return holderVestingSchedules[_beneficiary][_index];
    }
}