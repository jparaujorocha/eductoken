// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/roles/EducRoles.sol";
import "../config/constants/SystemConstants.sol";
import "../interfaces/IEducVesting.sol";
import "./VestingEvents.sol";
import "./types/VestingTypes.sol";

/**
 * @title EducVestingCloneable
 * @dev Cloneable implementation of the vesting contract for gas-efficient deployments
 * This version supports minimal proxy pattern (EIP-1167) for cheap deployments
 */
contract EducVestingCloneable is AccessControl, Pausable, ReentrancyGuard, Initializable, IEducVesting {
    using SafeERC20 for IERC20;

    // Storage
    IERC20 public token;                                    // Token to be vested
    address public treasury;                                // Treasury address for revoked tokens
    uint256 public vestingSchedulesCount;                   // Count of vesting schedules
    mapping(bytes32 => VestingTypes.VestingSchedule) public vestingSchedules;     // Schedule ID to schedule
    mapping(address => uint256) public holdersVestingCount;                       // Count of schedules per holder
    mapping(address => mapping(uint256 => bytes32)) public holderVestingSchedules; // Holder's schedule IDs

    /**
     * @dev Empty constructor as this is a cloneable contract
     */
    constructor() {
        // No initialization here, use initialize() instead
    }
    
    /**
     * @dev Initializes the contract (replaces constructor for clones)
     * @param _token Address of the token to be vested
     * @param _treasury Address where revoked tokens will be sent
     * @param _admin Admin address
     */
    function initialize(address _token, address _treasury, address _admin)
        external
        initializer
    {
        require(_token != address(0), "EducVesting: Token cannot be zero address");
        require(_treasury != address(0), "EducVesting: Treasury cannot be zero address");
        require(_admin != address(0), "EducVesting: Admin cannot be zero address");

        token = IERC20(_token);
        treasury = _treasury;
        vestingSchedulesCount = 0;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EducRoles.ADMIN_ROLE, _admin);
        _grantRole(EducRoles.PAUSER_ROLE, _admin);
    }

    /**
     * @dev Creates a linear vesting schedule with structured parameters
     * @param params Linear vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createLinearVesting(VestingTypes.LinearVestingParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        return _createVestingSchedule(
            params.beneficiary,
            params.totalAmount,
            params.startTime,
            params.duration,
            0, // No cliff for linear vesting
            0, // No milestones for linear vesting
            0, // No milestones reached yet
            params.revocable,
            VestingTypes.VestingType.Linear,
            params.metadata
        );
    }
    
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
    )
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            0, // No cliff for linear vesting
            0, // No milestones for linear vesting
            0, // No milestones reached yet
            _revocable,
            VestingTypes.VestingType.Linear,
            _metadata
        );
    }
    
    /**
     * @dev Creates a cliff vesting schedule with structured parameters
     * @param params Cliff vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createCliffVesting(VestingTypes.CliffVestingParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        // For cliff vesting, total duration equals cliff duration
        return _createVestingSchedule(
            params.beneficiary,
            params.totalAmount,
            params.startTime,
            params.cliffDuration, // Duration is same as cliff for cliff vesting
            params.cliffDuration,
            0, // No milestones for cliff vesting
            0, // No milestones reached yet
            params.revocable,
            VestingTypes.VestingType.Cliff,
            params.metadata
        );
    }
    
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
    )
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        // For cliff vesting, total duration equals cliff duration
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration, // Duration is same as cliff for cliff vesting
            _cliffDuration,
            0, // No milestones for cliff vesting
            0, // No milestones reached yet
            _revocable,
            VestingTypes.VestingType.Cliff,
            _metadata
        );
    }
    
    /**
     * @dev Creates a hybrid vesting schedule with structured parameters
     * @param params Hybrid vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createHybridVesting(VestingTypes.HybridVestingParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        require(params.cliffDuration < params.duration, "EducVesting: Cliff must be shorter than duration");
        
        return _createVestingSchedule(
            params.beneficiary,
            params.totalAmount,
            params.startTime,
            params.duration,
            params.cliffDuration,
            0, // No milestones for hybrid vesting
            0, // No milestones reached yet
            params.revocable,
            VestingTypes.VestingType.Hybrid,
            params.metadata
        );
    }
    
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
    )
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        require(_cliffDuration < _duration, "EducVesting: Cliff must be shorter than duration");
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            _cliffDuration,
            0, // No milestones for hybrid vesting
            0, // No milestones reached yet
            _revocable,
            VestingTypes.VestingType.Hybrid,
            _metadata
        );
    }
    
    /**
     * @dev Creates a milestone-based vesting schedule with structured parameters
     * @param params Milestone vesting parameters
     * @return vestingScheduleId The ID of the created schedule
     */
    function createMilestoneVesting(VestingTypes.MilestoneVestingParams calldata params)
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        require(params.milestoneCount > 0, "EducVesting: Milestone count must be positive");
        
        return _createVestingSchedule(
            params.beneficiary,
            params.totalAmount,
            params.startTime,
            params.duration,
            0, // No cliff for milestone vesting
            params.milestoneCount,
            0, // No milestones reached yet
            params.revocable,
            VestingTypes.VestingType.Milestone,
            params.metadata
        );
    }
    
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
    )
        external
        override
        onlyRole(EducRoles.ADMIN_ROLE)
        whenNotPaused
        nonReentrant
        returns (bytes32 vestingScheduleId)
    {
        require(_milestoneCount > 0, "EducVesting: Milestone count must be positive");
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            0, // No cliff for milestone vesting
            _milestoneCount,
            0, // No milestones reached yet
            _revocable,
            VestingTypes.VestingType.Milestone,
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
        VestingTypes.VestingType _vestingType,
        bytes32 _metadata
    )
        internal
        returns (bytes32 vestingScheduleId)
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
        vestingScheduleId = keccak256(
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
        vestingSchedules[vestingScheduleId] = VestingTypes.VestingSchedule({
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

        emit VestingEvents.VestingScheduleCreated(
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
        override
        nonReentrant
        whenNotPaused
    {
        VestingTypes.VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(schedule.beneficiary == msg.sender, "EducVesting: Only beneficiary can release");
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        
        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable > 0, "EducVesting: No tokens are due for release");
        
        schedule.released += releasable;
        
        token.safeTransfer(schedule.beneficiary, releasable);
        
        emit VestingEvents.VestingScheduleReleased(
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
        override
        nonReentrant
        whenNotPaused
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        VestingTypes.VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        
        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable > 0, "EducVesting: No tokens are due for release");
        
        schedule.released += releasable;
        
        token.safeTransfer(schedule.beneficiary, releasable);
        
        emit VestingEvents.VestingScheduleReleased(
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
        override
        nonReentrant
        whenNotPaused
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        VestingTypes.VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
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
            
            emit VestingEvents.VestingScheduleReleased(
                vestingScheduleId,
                schedule.beneficiary,
                releasable
            );
        }
        
        // Transfer unreleased tokens to treasury
        if (unreleased > 0) {
            token.safeTransfer(treasury, unreleased);
            
            emit VestingEvents.VestingScheduleRevoked(
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
        override
        nonReentrant
        whenNotPaused
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        VestingTypes.VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        require(schedule.vestingType == VestingTypes.VestingType.Milestone, "EducVesting: Not a milestone schedule");
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        require(schedule.milestonesReached < schedule.milestoneCount, "EducVesting: All milestones completed");
        
        // Increment milestone count
        schedule.milestonesReached++;
        
        // Calculate release amount per milestone
        uint256 amountPerMilestone = schedule.totalAmount / schedule.milestoneCount;
        
        // Release tokens
        schedule.released += amountPerMilestone;
        
        token.safeTransfer(schedule.beneficiary, amountPerMilestone);
        
        emit VestingEvents.MilestoneCompleted(
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
        override
        onlyRole(EducRoles.ADMIN_ROLE)
    {
        require(_treasury != address(0), "EducVesting: Treasury cannot be zero address");
        
        address oldTreasury = treasury;
        treasury = _treasury;
        
        emit VestingEvents.TreasuryUpdated(oldTreasury, _treasury);
    }
    
    /**
     * @dev Transfers a vesting schedule to a new beneficiary
     * @param vestingScheduleId The vesting schedule ID
     * @param newBeneficiary New beneficiary address
     */
    function transferVestingSchedule(bytes32 vestingScheduleId, address newBeneficiary)
        external
        override
        nonReentrant
        whenNotPaused
    {
        require(newBeneficiary != address(0), "EducVesting: New beneficiary cannot be zero address");
        
        VestingTypes.VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        require(schedule.beneficiary == msg.sender, "EducVesting: Only beneficiary can transfer");
        require(!schedule.revoked, "EducVesting: Schedule has been revoked");
        
        address previousBeneficiary = schedule.beneficiary;
        schedule.beneficiary = newBeneficiary;
        
        // Update holder tracking
        uint256 holderVestingCount = holdersVestingCount[newBeneficiary];
        holderVestingSchedules[newBeneficiary][holderVestingCount] = vestingScheduleId;
        holdersVestingCount[newBeneficiary] = holderVestingCount + 1;
        
        // Note: We don't remove from the previous beneficiary's mapping,
        // as this would require extensive remapping. The schedule ID remains
        // valid, but beneficiary is updated.
        
        emit VestingEvents.VestingScheduleTransferred(
            vestingScheduleId,
            previousBeneficiary,
            newBeneficiary
        );
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
    function _computeReleasableAmount(VestingTypes.VestingSchedule memory _schedule)
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
        
        if (_schedule.vestingType == VestingTypes.VestingType.Linear) {
            // Linear vesting calculation
            if (currentTime >= _schedule.startTime + _schedule.duration) {
                vestedAmount = _schedule.totalAmount;
            } else {
                vestedAmount = _schedule.totalAmount * (currentTime - _schedule.startTime) / _schedule.duration;
            }
        } else if (_schedule.vestingType == VestingTypes.VestingType.Cliff) {
            // Cliff vesting calculation
            if (currentTime >= _schedule.startTime + _schedule.cliffDuration) {
                vestedAmount = _schedule.totalAmount;
            } else {
                vestedAmount = 0;
            }
        } else if (_schedule.vestingType == VestingTypes.VestingType.Hybrid) {
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
        } else if (_schedule.vestingType == VestingTypes.VestingType.Milestone) {
            // Milestone vesting calculation
            vestedAmount = _schedule.totalAmount * _schedule.milestonesReached / _schedule.milestoneCount;
        }
        
        return vestedAmount - _schedule.released;
    }

    /**
     * @dev Gets the vesting schedule info
     * @param vestingScheduleId The vesting schedule ID
     * @return schedule The vesting schedule details
     */
    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        override
        returns (VestingTypes.VestingSchedule memory schedule)
    {
        return vestingSchedules[vestingScheduleId];
    }
    
    /**
     * @dev Gets the releasable amount for a vesting schedule
     * @param vestingScheduleId The vesting schedule ID
     * @return releasable The releasable amount
     */
    function getReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        override
        returns (uint256 releasable)
    {
        VestingTypes.VestingSchedule memory schedule = vestingSchedules[vestingScheduleId];
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
        override
        returns (bytes32[] memory vestingScheduleIds)
    {
        uint256 count = holdersVestingCount[_beneficiary];
        vestingScheduleIds = new bytes32[](count);
        
        for (uint256 i = 0; i < count; i++) {
            vestingScheduleIds[i] = holderVestingSchedules[_beneficiary][i];
        }
        
        return vestingScheduleIds;
    }
    
    /**
     * @dev Gets the number of vesting schedules
     * @return count The total number of vesting schedules
     */
    function getVestingSchedulesCount()
        external
        view
        override
        returns (uint256 count)
    {
        return vestingSchedulesCount;
    }
    
    /**
     * @dev Gets the token used for vesting
     * @return tokenAddress The token address
     */
    function getToken()
        external
        view
        override
        returns (address tokenAddress)
    {
        return address(token);
    }
    
    /**
     * @dev Gets the treasury address
     * @return treasuryAddress The treasury address
     */
    function getTreasury()
        external
        view
        override
        returns (address treasuryAddress)
    {
        return treasury;
    }
}