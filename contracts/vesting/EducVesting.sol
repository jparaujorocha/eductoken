// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../access/roles/EducRoles.sol";
import "../config/constants/SystemConstants.sol";
import "../interfaces/IEducVesting.sol";
import "./VestingEvents.sol";
import "./types/VestingTypes.sol";

contract EducVesting is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Custom Errors
    error InvalidAddress(address addr);
    error InvalidAmount(uint256 amount);
    error InvalidDuration(uint256 duration);
    error ScheduleAlreadyRevoked(bytes32 scheduleId);
    error NotBeneficiary(address caller);
    error NoTokensDue();
    error InvalidMilestoneCount(uint32 count);

    // Vesting schedule structure
    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 released;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        uint32 milestoneCount;
        uint32 milestonesReached;
        bool revocable;
        bool revoked;
        VestingTypes.VestingType vestingType;
        bytes32 metadata;
    }

    // Constants
    uint256 private constant MAX_MILESTONE_COUNT = 100;
    uint256 private constant MAX_VESTING_DURATION = 10 * 365 days;

    // Storage variables
    IERC20 public immutable token;
    address public treasury;
    uint256 public vestingSchedulesCount;

    // Mappings
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    mapping(address => uint256) private holdersVestingCount;
    mapping(address => mapping(uint256 => bytes32)) private holderVestingSchedules;

    constructor(address _token, address _treasury, address _admin) {
        _validateConstructorParams(_token, _treasury, _admin);
        
        token = IERC20(_token);
        treasury = _treasury;

        _setupRoles(_admin);
    }

    function _validateConstructorParams(
        address _token, 
        address _treasury, 
        address _admin
    ) private pure {
        if (_token == address(0)) revert InvalidAddress(_token);
        if (_treasury == address(0)) revert InvalidAddress(_treasury);
        if (_admin == address(0)) revert InvalidAddress(_admin);
    }

    function _setupRoles(address _admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EducRoles.ADMIN_ROLE, _admin);
        _grantRole(EducRoles.PAUSER_ROLE, _admin);
    }

    function createLinearVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        bool _revocable,
        bytes32 _metadata
    ) external onlyRole(EducRoles.ADMIN_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        _validateVestingParams(_beneficiary, _totalAmount, _duration);
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            0,
            0,
            0,
            _revocable,
            VestingTypes.VestingType.Linear,
            _metadata
        );
    }

    function createCliffVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        bool _revocable,
        bytes32 _metadata
    ) external onlyRole(EducRoles.ADMIN_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        _validateVestingParams(_beneficiary, _totalAmount, _cliffDuration);
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _cliffDuration,
            0,
            0,
            _revocable,
            VestingTypes.VestingType.Cliff,
            _metadata
        );
    }

    function createHybridVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliffDuration,
        bool _revocable,
        bytes32 _metadata
    ) external onlyRole(EducRoles.ADMIN_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        _validateVestingParams(_beneficiary, _totalAmount, _duration);
        
        if (_cliffDuration >= _duration) 
            revert InvalidDuration(_cliffDuration);
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            _cliffDuration,
            0,
            0,
            _revocable,
            VestingTypes.VestingType.Hybrid,
            _metadata
        );
    }

    function createMilestoneVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint32 _milestoneCount,
        bool _revocable,
        bytes32 _metadata
    ) external onlyRole(EducRoles.ADMIN_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        _validateVestingParams(_beneficiary, _totalAmount, _duration);
        
        if (_milestoneCount == 0 || _milestoneCount > MAX_MILESTONE_COUNT) 
            revert InvalidMilestoneCount(_milestoneCount);
        
        return _createVestingSchedule(
            _beneficiary,
            _totalAmount,
            _startTime,
            _duration,
            0,
            _milestoneCount,
            0,
            _revocable,
            VestingTypes.VestingType.Milestone,
            _metadata
        );
    }

    function _validateVestingParams(
        address _beneficiary, 
        uint256 _totalAmount, 
        uint256 _duration
    ) private pure {
        if (_beneficiary == address(0)) revert InvalidAddress(_beneficiary);
        if (_totalAmount == 0) revert InvalidAmount(_totalAmount);
        if (_duration == 0 || _duration > MAX_VESTING_DURATION) 
            revert InvalidDuration(_duration);
    }

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
    ) private returns (bytes32) {
        uint256 effectiveStartTime = _startTime == 0 ? block.timestamp : _startTime;
        
        if (effectiveStartTime < block.timestamp) 
            revert InvalidDuration(effectiveStartTime);

        bytes32 vestingScheduleId = _generateVestingScheduleId(
            _beneficiary, _totalAmount, effectiveStartTime, 
            _duration, _cliffDuration, _vestingType
        );

        _initializeVestingSchedule(
            vestingScheduleId,
            _beneficiary,
            _totalAmount,
            effectiveStartTime,
            _duration,
            _cliffDuration,
            _milestoneCount,
            _milestonesReached,
            _revocable,
            _vestingType,
            _metadata
        );

        _trackVestingSchedule(_beneficiary, vestingScheduleId);

        token.safeTransferFrom(msg.sender, address(this), _totalAmount);

        emit VestingEvents.VestingScheduleCreated(
            vestingScheduleId,
            _beneficiary,
            _totalAmount,
            _vestingType,
            effectiveStartTime,
            _duration
        );

        return vestingScheduleId;
    }

    function _initializeVestingSchedule(
        bytes32 vestingScheduleId,
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
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        schedule.beneficiary = _beneficiary;
        schedule.totalAmount = _totalAmount;
        schedule.startTime = _startTime;
        schedule.duration = _duration;
        schedule.cliffDuration = _cliffDuration;
        schedule.milestoneCount = _milestoneCount;
        schedule.milestonesReached = _milestonesReached;
        schedule.revocable = _revocable;
        schedule.vestingType = _vestingType;
        schedule.metadata = _metadata;
    }

    function _generateVestingScheduleId(
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

    function _trackVestingSchedule(
        address _beneficiary, 
        bytes32 _vestingScheduleId
    ) private {
        uint256 holderVestingCount = holdersVestingCount[_beneficiary];
        holderVestingSchedules[_beneficiary][holderVestingCount] = _vestingScheduleId;
        holdersVestingCount[_beneficiary] = holderVestingCount + 1;
        vestingSchedulesCount++;
    }

    function release(bytes32 vestingScheduleId) 
        external 
        nonReentrant 
        whenNotPaused
    {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        
        if (schedule.beneficiary != msg.sender) 
            revert NotBeneficiary(msg.sender);
        
        if (schedule.revoked) 
            revert ScheduleAlreadyRevoked(vestingScheduleId);
        
        uint256 releasable = _computeReleasableAmount(schedule);
        
        if (releasable == 0) 
            revert NoTokensDue();
        
        schedule.released += releasable;
        
        token.safeTransfer(schedule.beneficiary, releasable);
        
        emit VestingEvents.VestingScheduleReleased(
            vestingScheduleId,
            schedule.beneficiary,
            releasable
        );
    }

    function _computeReleasableAmount(VestingSchedule memory _schedule) 
        private 
        view 
        returns (uint256) 
    {
        if (_schedule.revoked) return 0;
        
        uint256 currentTime = block.timestamp;
        if (currentTime < _schedule.startTime) return 0;
        
        uint256 vestedAmount = _computeVestedAmountByType(_schedule, currentTime);
        return vestedAmount > _schedule.released 
            ? vestedAmount - _schedule.released 
            : 0;
    }

    function _computeVestedAmountByType(
        VestingSchedule memory _schedule, 
        uint256 _currentTime
    ) private pure returns (uint256) {
        if (_schedule.vestingType == VestingTypes.VestingType.Linear) {
            return _computeLinearVestedAmount(
                _schedule.totalAmount, 
                _schedule.startTime, 
                _schedule.duration, 
                _currentTime
            );
        } else if (_schedule.vestingType == VestingTypes.VestingType.Cliff) {
            return _computeCliffVestedAmount(
                _schedule.totalAmount, 
                _schedule.startTime, 
                _schedule.cliffDuration, 
                _currentTime
            );
        } else if (_schedule.vestingType == VestingTypes.VestingType.Hybrid) {
            return _computeHybridVestedAmount(
                _schedule.totalAmount,
                _schedule.startTime,
                _schedule.duration,
                _schedule.cliffDuration,
                _currentTime
            );
        } else if (_schedule.vestingType == VestingTypes.VestingType.Milestone) {
            return _computeMilestoneVestedAmount(
                _schedule.totalAmount,
                _schedule.milestoneCount,
                _schedule.milestonesReached
            );
        }
        
        return 0;
    }

    // Calculation methods (linear, cliff, hybrid, milestone vesting)
    function _computeLinearVestedAmount(
        uint256 totalAmount, 
        uint256 startTime, 
        uint256 duration, 
        uint256 currentTime
    ) private pure returns (uint256) {
        if (currentTime >= startTime + duration) return totalAmount;
        return totalAmount * (currentTime - startTime) / duration;
    }

    function _computeCliffVestedAmount(
        uint256 totalAmount, 
        uint256 startTime, 
        uint256 cliffDuration, 
        uint256 currentTime
    ) private pure returns (uint256) {
        return (currentTime >= startTime + cliffDuration) ? totalAmount : 0;
    }

    function _computeHybridVestedAmount(
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        uint256 currentTime
    ) private pure returns (uint256) {
        if (currentTime < startTime + cliffDuration) return 0;
        if (currentTime >= startTime + duration) return totalAmount;

        uint256 timeAfterCliff = currentTime - (startTime + cliffDuration);
        uint256 linearDuration = duration - cliffDuration;
        return totalAmount * timeAfterCliff / linearDuration;
    }

    function _computeMilestoneVestedAmount(
        uint256 totalAmount,
        uint32 milestoneCount,
        uint32 milestonesReached
    ) private pure returns (uint256) {
        return totalAmount * milestonesReached / milestoneCount;
    }

    // Remaining core methods to be implemented
    function pause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EducRoles.PAUSER_ROLE) {
        _unpause();
    }
}