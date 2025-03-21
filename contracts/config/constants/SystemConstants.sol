// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SystemConstants
 * @dev Defines global constants used throughout the EducToken system
 * Centralizes all constant values to avoid hard-coding and ensure consistency
 */
library SystemConstants {
    // Token Constants
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10**18; // 10 million tokens
    uint256 public constant MAX_MINT_AMOUNT = 100_000 * 10**18; // 100,000 tokens per transaction
    uint256 public constant DAILY_MINT_LIMIT = 1_000 * 10**18; // 1,000 tokens daily limit
    
    // Time Constants
    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant ONE_WEEK = 7 days;
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant TWO_HOURS = 2 hours;
    uint256 public constant SIX_MONTHS = 180 days;
    uint256 public constant BURN_COOLDOWN_PERIOD = ONE_YEAR; // 1 year for token expiration
    uint256 public constant STUDENT_INACTIVITY_PERIOD = ONE_YEAR; // Period after which a student is considered inactive
    
    // System Limits
    uint16 public constant MAX_EDUCATORS_LIMIT = 1000;
    uint16 public constant MAX_COURSES_LIMIT = 500;
    uint16 public constant MAX_COURSES_PER_EDUCATOR = 100;
    uint32 public constant MAX_COURSES_PER_STUDENT = 1000;
    uint8 public constant MAX_SIGNERS = 10;
    uint8 public constant MIN_SIGNERS = 1;
    
    // String Length Limits
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;
    uint256 public constant MAX_COURSE_ID_LENGTH = 50;
    uint256 public constant MAX_COURSE_NAME_LENGTH = 100;
    uint256 public constant MAX_CHANGE_DESCRIPTION_LENGTH = 200;
    
    // Governance Constants
    uint256 public constant PROPOSAL_EXPIRATION_TIME = ONE_WEEK;
    
    // Security Constants
    uint256 public constant DEFAULT_COOLDOWN_PERIOD = ONE_WEEK;
    uint256 public constant DEFAULT_APPROVAL_THRESHOLD = 2;
    
    // Special Addresses
    address public constant ETH_PSEUDO_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    
    // Pause Flags
    uint32 public constant PAUSE_FLAG_MINT = 1 << 0;     // 1
    uint32 public constant PAUSE_FLAG_TRANSFER = 1 << 1; // 2
    uint32 public constant PAUSE_FLAG_BURN = 1 << 2;     // 4
    uint32 public constant PAUSE_FLAG_REGISTER = 1 << 3; // 8
    uint32 public constant PAUSE_FLAG_COURSE = 1 << 4;   // 16
    uint32 public constant PAUSE_FLAG_EDUCATOR = 1 << 5; // 32
    uint32 public constant PAUSE_FLAG_STUDENT = 1 << 6;  // 64
    uint32 public constant PAUSE_FLAG_ALL = 0xFFFFFFFF;  // All flags
    
    // Vesting Constants
    uint32 public constant DEFAULT_MILESTONE_COUNT =
    5;
}