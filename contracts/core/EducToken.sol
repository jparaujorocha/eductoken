// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../access/EducRoles.sol";
import "../interfaces/IEducToken.sol";

/**
 * @title EducToken
 * @dev ERC20 token for educational incentives with reward system
 */
contract EducToken is ERC20, AccessControl, Pausable, ReentrancyGuard, IEducToken {
    // Constants
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10**18; // 10 million tokens
    uint256 public constant MAX_MINT_AMOUNT = 100_000 * 10**18; // 100,000 tokens per transaction
    uint256 public constant BURN_COOLDOWN_PERIOD = 365 days; // 1 year for token expiration

    // Total counters
    uint256 public totalMinted;
    uint256 public totalBurned;

    // Role definitions from EducRoles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EDUCATOR_ROLE = keccak256("EDUCATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Modifiers
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "EducToken: caller is not an admin");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "EducToken: caller is not a minter");
        _;
    }

    /**
     * @dev Constructor that initializes the token with name, symbol and initial supply
     * @param admin The address that will be granted the admin role
     */
    constructor(address admin) ERC20("EducToken", "EDUC") {
        require(admin != address(0), "EducToken: admin cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);

        _mint(admin, INITIAL_SUPPLY);
        totalMinted = INITIAL_SUPPLY;
    }

    /**
     * @dev Pauses all token transfers and minting operations
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and minting operations
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @dev Mints tokens to an address
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external override onlyMinter whenNotPaused nonReentrant {
        require(to != address(0), "EducToken: mint to the zero address");
        require(amount > 0, "EducToken: mint amount must be positive");
        require(amount <= MAX_MINT_AMOUNT, "EducToken: amount exceeds max mint amount");

        _mint(to, amount);
        totalMinted += amount;

        emit TokensMinted(to, amount, msg.sender);
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external override whenNotPaused nonReentrant {
        require(amount > 0, "EducToken: burn amount must be positive");
        require(balanceOf(msg.sender) >= amount, "EducToken: burn amount exceeds balance");

        _burn(msg.sender, amount);
        totalBurned += amount;

        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from a specific account (admin function for expired tokens)
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @param reason The reason for burning tokens
     */
    function burnFrom(address from, uint256 amount, string calldata reason) 
        external 
        override 
        onlyAdmin 
        whenNotPaused 
        nonReentrant 
    {
        require(from != address(0), "EducToken: burn from the zero address");
        require(amount > 0, "EducToken: burn amount must be positive");
        require(balanceOf(from) >= amount, "EducToken: burn amount exceeds balance");
        
        // Allow burning tokens that haven't been used in a long time (expired)
        require(
            _isAccountInactive(from) || hasRole(ADMIN_ROLE, msg.sender),
            "EducToken: cannot burn from active account"
        );

        _burn(from, amount);
        totalBurned += amount;

        emit TokensBurnedFrom(from, amount, msg.sender, reason);
    }

    /**
     * @dev Transfer function override to enforce pause logic
     */
    function transfer(address to, uint256 amount) public override(ERC20, IEducToken) whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @dev TransferFrom function override to enforce pause logic
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override(ERC20, IEducToken) 
        whenNotPaused 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Determines if an account is considered inactive
     * @param account The account to check
     * @return bool True if the account is inactive and eligible for token expiration
     */
    function _isAccountInactive(address account) internal view returns (bool) {
        // Admin accounts cannot be considered inactive
        if (hasRole(ADMIN_ROLE, account)) {
            return false;
        }
        
        // Implementation depends on integration with student tracking system
        // For now, always return false to prevent unauthorized burns
        return false;
    }
}