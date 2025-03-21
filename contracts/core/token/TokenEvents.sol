// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TokenEvents
 * @dev Defines events for the Token module
 */
library TokenEvents {
    /**
     * @dev Emitted when tokens are minted
     * @param to Recipient of the minted tokens
     * @param amount Amount of tokens minted
     * @param minter Address that performed the minting
     */
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    
    /**
     * @dev Emitted when tokens are burned
     * @param from Address tokens were burned from
     * @param amount Amount of tokens burned
     */
    event TokensBurned(address indexed from, uint256 amount);
    
    /**
     * @dev Emitted when tokens are burned from an address by an admin
     * @param from Address tokens were burned from
     * @param amount Amount of tokens burned
     * @param burner Address that performed the burning
     * @param reason Reason for burning the tokens
     */
    event TokensBurnedFrom(
        address indexed from, 
        uint256 amount, 
        address indexed burner, 
        string reason
    );
    
    /**
     * @dev Emitted when an educational reward is issued
     * @param student Student receiving the reward
     * @param amount Amount of tokens rewarded
     * @param reason Educational reason for the reward
     */
    event RewardIssued(address indexed student, uint256 amount, string reason);
    
    /**
     * @dev Emitted when the student contract is set
     * @param studentContract Address of the student contract
     */
    event StudentContractSet(address indexed studentContract);
    
    /**
     * @dev Emitted when the daily minting limit is reached
     * @param date Day (in Unix timestamp / 1 days)
     * @param limit Daily minting limit
     * @param reached Amount that has been minted today
     */
    event DailyMintingLimitReached(uint256 date, uint256 limit, uint256 reached);
    
    /**
     * @dev Emitted when an account is detected as inactive
     * @param account The inactive account
     * @param lastActivity Timestamp of the last activity
     * @param balance Current token balance
     */
    event InactiveAccountDetected(
        address indexed account, 
        uint256 lastActivity, 
        uint256 balance
    );
}