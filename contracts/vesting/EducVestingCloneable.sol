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
        _validateInitializeParams(_token, _treasury, _admin);

        token = IERC20(_token);
        treasury = _treasury;
        vestingSchedulesCount = 0;

        _setupInitialRoles(_admin);
    }

    /**
     * @dev Validates initialize parameters
     */
    function _validateInitializeParams(address _token, address _treasury, address _admin) private pure {
        require(_token != address(0), "EducVesting: Token cannot be zero address");
        require(_treasury != address(0), "EducVesting: Treasury cannot be zero address");
        require(_admin != address(0), "EducVesting: Admin cannot be zero address");
    }

    /**
     * @dev Sets up initial roles for the contract
     */
    function _setupInitialRoles(address _admin) private {
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
        _validateHybridVestingParams(params.cliffDuration, params.duration);
        
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
        _validateHybridVestingParams(_cliffDuration, _duration);
        
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
     * @dev Validates hybrid vesting parameters
     */
    function _validateHybridVestingParams(uint256 _cliffDuration, uint256 _duration) private pure {
        require(_cliffDuration < _duration, "EducVesting: Cliff must be shorter than duration");
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
        _validateMilestoneParams(params.milestoneCount);
        
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
        _validateMilestoneParams(_milestoneCount);
        
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
     * @dev Validates milestone parameters
     */
    function _validateMilestoneParams(uint32 _milestoneCount) private pure {
        require(_milestoneCount > 0, "EducVesting: Milestone count must be positive");
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
        _validateVestingScheduleParams(_beneficiary, _totalAmount, _duration);
        _startTime = _validateAndNormalizeStartTime(_startTime);

        // Create schedule ID
        vestingScheduleId = _generateScheduleId(
            _beneficiary, 
            _totalAmount, 
            _startTime, 
            _duration,
            _cliffDuration, 
            _vestingType
        );

        // Store the schedule
        _storeVestingSchedule(
            vestingScheduleId,
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            _cliffDuration,
            _milestoneCount,
            _milestonesReached,
            _revocable,
            _vestingType,
            _metadata
        );

        // Track schedules by holder
        _trackScheduleForHolder(_beneficiary, vestingScheduleId);

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
     * @dev Validates basic vesting schedule parameters
     */
    function _validateVestingScheduleParams(
        address _beneficiary, 
        uint256 _totalAmount, 
        uint256 _duration
    ) private pure {
        require(_beneficiary != address(0), "EducVesting: Beneficiary cannot be zero address");
        require(_totalAmount > 0, "EducVesting: Amount must be greater than zero");
        require(_duration > 0, "EducVesting: Duration must be greater than zero");
    }

    /**
     * @dev Validates and normalizes start time
     */
    function _validateAndNormalizeStartTime(uint256 _startTime) private view returns (uint256) {
        // For future schedules, start time must be in the future
        if (_startTime == 0) {
            return block.timestamp;
        } else {
            require(_startTime >= block.timestamp, "EducVesting: Start time must be in the future");
            return _startTime;
        }
    }

    /**
     * @dev Generates a unique schedule ID
     */
    function _generateScheduleId(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliffDuration,
        VestingTypes.VestingType _vestingType
    ) private view returns (bytes32) {
        return keccak256(
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
    }

    /**
     * @dev Stores a vesting schedule
     */
    function _storeVestingSchedule(
        bytes32 _vestingScheduleId,
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
    ) private {
        vestingSchedules[_vestingScheduleId] = VestingTypes.VestingSchedule({
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
    }

    /**
     * @dev Tracks a schedule for a holder
     */
    function _trackScheduleForHolder(address _beneficiary, bytes32 _vestingScheduleId) private {
        uint256 holderVestingCount = holdersVestingCount[_beneficiary];
        holderVestingSchedules[_beneficiary][holderVestingCount] = _vestingScheduleId;
        holdersVestingCount[_beneficiary] = holderVestingCount + 1;
        vestingSchedulesCount++;
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
        
        _validateCallerIsBeneficiary(schedule.beneficiary);
        _validateScheduleNotRevoked(schedule);
        
        _releaseTokens(vestingScheduleId, schedule);
    }

    /**
     * @dev Validates that caller is the beneficiary
     */
    function _validateCallerIsBeneficiary(address _beneficiary) private view {
        require(_beneficiary == msg.sender, "EducVesting: Only beneficiary can release");
    }

    /**
     * @dev Validates that schedule is not revoked
     */
    function _validateScheduleNotRevoked(VestingTypes.VestingSchedule storage _schedule) private view {
        require(!_schedule.revoked, "EducVesting: Schedule has been revoked");
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
        
        _validateScheduleNotRevoked(schedule);
        
        _releaseTokens(vestingScheduleId, schedule);
    }

    /**
     * @dev Releases tokens for a schedule
     */
    function _releaseTokens(bytes32 _vestingScheduleId, VestingTypes.VestingSchedule storage _schedule) private {
        uint256 releasable = _computeReleasableAmount(_schedule);
        require(releasable > 0, "EducVesting: No tokens are due for release");
        
        _schedule.released += releasable;
        
        token.safeTransfer(_schedule.beneficiary, releasable);
        
        emit VestingEvents.VestingScheduleReleased(
            _vestingScheduleId,
            _schedule.beneficiary,
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
        
        _validateScheduleRevocable(schedule);
        _validateScheduleNotRevoked(schedule);
        
        _performRevocation(vestingScheduleId, schedule);
    }

    /**
     * @dev Validates that schedule is revocable
     */
    function _validateScheduleRevocable(VestingTypes.VestingSchedule storage _schedule) private view {
        require(_schedule.revocable, "EducVesting: Schedule is not revocable");
    }

    /**
     * @dev Performs the revocation of a vesting schedule
     */
    function _performRevocation(bytes32 _vestingScheduleId, VestingTypes.VestingSchedule storage _schedule) private {
        uint256 releasable = _computeReleasableAmount(_schedule);
        uint256 unreleased = _schedule.totalAmount - _schedule.released - releasable;
        
        // Mark as revoked
        _schedule.revoked = true;
        
        // Release vested tokens to beneficiary
        _releaseVestedTokensOnRevocation(_vestingScheduleId, _schedule, releasable);
        
        // Transfer unreleased tokens to treasury
        _transferUnreleasedTokensToTreasury(_vestingScheduleId, _schedule, unreleased);
    }

    /**
     * @dev Releases vested tokens on revocation
     */
    function _releaseVestedTokensOnRevocation(
        bytes32 _vestingScheduleId, 
        VestingTypes.VestingSchedule storage _schedule, 
        uint256 _releasable
    ) private {
        if (_releasable > 0) {
            _schedule.released += _releasable;
            token.safeTransfer(_schedule.beneficiary, _releasable);
            
            emit VestingEvents.VestingScheduleReleased(
                _vestingScheduleId,
                _schedule.beneficiary,
                _releasable
            );
        }
    }

    /**
     * @dev Transfers unreleased tokens to treasury on revocation
     */
    function _transferUnreleasedTokensToTreasury(
        bytes32 _vestingScheduleId, 
        VestingTypes.VestingSchedule storage _schedule, 
        uint256 _unreleased
    ) private {
        if (_unreleased > 0) {
            token.safeTransfer(treasury, _unreleased);
            
            emit VestingEvents.VestingScheduleRevoked(
                _vestingScheduleId,
                _schedule.beneficiary,
                _unreleased
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
        
        _validateMilestoneSchedule(schedule);
        
        _completeMilestone(vestingScheduleId, schedule);
    }

    /**
     * @dev Validates milestone schedule
     */
    function _validateMilestoneSchedule(VestingTypes.VestingSchedule storage _schedule) private view {
        require(_schedule.vestingType == VestingTypes.VestingType.Milestone, "EducVesting: Not a milestone schedule");
        require(!_schedule.revoked, "EducVesting: Schedule has been revoked");
        require(_schedule.milestonesReached < _schedule.milestoneCount, "EducVesting: All milestones completed");
    }

    /**
     * @dev Completes a milestone and releases tokens
     */
    function _completeMilestone(bytes32 _vestingScheduleId, VestingTypes.VestingSchedule storage _schedule) private {
        // Increment milestone count
        _schedule.milestonesReached++;
        
        // Calculate release amount per milestone
        uint256 amountPerMilestone = _schedule.totalAmount / _schedule.milestoneCount;
        
        // Release tokens
        _schedule.released += amountPerMilestone;
        
        token.safeTransfer(_schedule.beneficiary, amountPerMilestone);
        
        emit VestingEvents.MilestoneCompleted(
            _vestingScheduleId,
            _schedule.beneficiary,
            _schedule.milestonesReached,
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
        _validateTreasuryAddress(_treasury);
        
        address oldTreasury = treasury;
        treasury = _treasury;
        
        emit VestingEvents.TreasuryUpdated(oldTreasury, _treasury);
    }
    
    /**
     * @dev Validates treasury address
     */
    function _validateTreasuryAddress(address _treasury) private pure {
        require(_treasury != address(0), "EducVesting: Treasury cannot be zero address");
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
        _validateNewBeneficiary(newBeneficiary);
        
        VestingTypes.VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        _validateCallerIsBeneficiary(schedule.beneficiary);
        _validateScheduleNotRevoked(schedule);
        
        _transferSchedule(vestingScheduleId, schedule, newBeneficiary);
    }

    /**
     * @dev Validates new beneficiary address
     */
    function _validateNewBeneficiary(address _newBeneficiary) private pure {
        require(_newBeneficiary != address(0), "EducVesting: New beneficiary cannot be zero address");
    }

    /**
     * @dev Transfers schedule to new beneficiary
     */
    function _transferSchedule(
        bytes32 _vestingScheduleId, 
        VestingTypes.VestingSchedule storage _schedule, 
        address _newBeneficiary
    ) private {
        address previousBeneficiary = _schedule.beneficiary;
        _schedule.beneficiary = _newBeneficiary;
        
        // Update holder tracking
        uint256 holderVestingCount = holdersVestingCount[_newBeneficiary];
        holderVestingSchedules[_newBeneficiary][holderVestingCount] = _vestingScheduleId;
        holdersVestingCount[_newBeneficiary] = holderVestingCount + 1;
        
        // Note: We don't remove from the previous beneficiary's mapping,
        // as this would require extensive remapping. The schedule ID remains
        // valid, but beneficiary is updated.
        
        emit VestingEvents.VestingScheduleTransferred(
            _vestingScheduleId,
            previousBeneficiary,
            _newBeneficiary
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
            vestedAmount = _calculateLinearVesting(_schedule, currentTime);
        } else if (_schedule.vestingType == VestingTypes.VestingType.Cliff) {
            vestedAmount = _calculateCliffVesting(_schedule, currentTime);
        } else if (_schedule.vestingType == VestingTypes.VestingType.Hybrid) {
            vestedAmount = _calculateHybridVesting(_schedule, currentTime);
        } else if (_schedule.vestingType == VestingTypes.VestingType.Milestone) {
            vestedAmount = _calculateMilestoneVesting(_schedule);
        }
        
        return vestedAmount - _schedule.released;
    }

    /**
     * @dev Calculates vested amount for linear vesting
     */
    function _calculateLinearVesting(
        VestingTypes.VestingSchedule memory _schedule, 
        uint256 _currentTime
    ) private pure returns (uint256) {
        if (_currentTime >= _schedule.startTime + _schedule.duration) {
            return _schedule.totalAmount;
        } else {
            return _schedule.totalAmount * (_currentTime - _schedule.startTime) / _schedule.duration;
        }
    }

    /**
     * @dev Calculates vested amount for cliff vesting
     */
    function _calculateCliffVesting(
        VestingTypes.VestingSchedule memory _schedule, 
        uint256 _currentTime
    ) private pure returns (uint256) {
        if (_currentTime >= _schedule.startTime + _schedule.cliffDuration) {
            return _schedule.totalAmount;
        } else {
            return 0;
        }
    }

    /**
     * @dev Calculates vested amount for hybrid vesting
     */
    function _calculateHybridVesting(
        VestingTypes.VestingSchedule memory _schedule, 
        uint256 _currentTime
    ) private pure returns (uint256) {
        if (_currentTime < _schedule.startTime + _schedule.cliffDuration) {
            return 0;
        } else if (_currentTime >= _schedule.startTime + _schedule.duration) {
            return _schedule.totalAmount;
        } else {
            uint256 timeAfterCliff = _currentTime - (_schedule.startTime + _schedule.cliffDuration);
            uint256 linearDuration = _schedule.duration - _schedule.cliffDuration;
            return _schedule.totalAmount * timeAfterCliff / linearDuration;
        }
    }

    /**
     * @dev Calculates vested amount for milestone vesting
     */
    function _calculateMilestoneVesting(
        VestingTypes.VestingSchedule memory _schedule
    ) private pure returns (uint256) {
        return _schedule.totalAmount * _schedule.milestonesReached / _schedule.milestoneCount;
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