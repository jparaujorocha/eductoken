const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("EducTokenWithRecovery Integration Tests", function () {
  let token;
  let student;
  let admin;
  let treasury;
  let emergencyRecovery;
  let user1;
  let minter;

  const DAILY_MINT_LIMIT = ethers.parseEther("1000");
  const BURN_COOLDOWN_PERIOD = 365 * 24 * 60 * 60; // 1 year

  beforeEach(async function () {
    [admin, treasury, emergencyRecovery, user1, minter] = await ethers.getSigners();

    // Deploy Student contract first
    const StudentFactory = await ethers.getContractFactory("EducStudent");
    student = await StudentFactory.deploy(admin.address);

    // Deploy Token with Recovery
    const TokenFactory = await ethers.getContractFactory("EducTokenWithRecovery");
    token = await TokenFactory.deploy(
      admin.address, 
      treasury.address, 
      emergencyRecovery.address
    );

    await token.connect(admin).grantRole(
        ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE")), 
        emergencyRecovery.address
      );
      await token.connect(admin).grantRole(
        ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE")), 
        minter.address
      );
      
      await token.connect(admin).setDailyMintLimit(ethers.parseEther("10000"));
  });

  describe("Token Minting and Recovery", function () {
    it("Should mint tokens with emergency recovery mechanism", async function () {
      // Mint tokens to user1
      const initialAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, initialAmount);

      // Make user1 inactive
      await time.increase(BURN_COOLDOWN_PERIOD + 1);

      // Simulate emergency recovery
      const recoveryAmount = ethers.parseEther("500");
      await token.connect(emergencyRecovery).burnFromInactive(
        user1.address, 
        recoveryAmount, 
        "Emergency recovery test"
      );

      // Verify tokens burned
      const finalBalance = await token.balanceOf(user1.address);
      expect(finalBalance).to.equal(initialAmount - recoveryAmount);

      // Verify total burned updated
      const totalBurned = await token.getTotalBurned();
      expect(totalBurned).to.equal(recoveryAmount);
    });

    it("Should prevent recovery for active accounts", async function () {
      // Mint tokens to user1
      const initialAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, initialAmount);

      // Perform recent activity to keep account active
      await student.connect(admin)["recordCustomActivity(address,string,string)"](
        user1.address, 
        "RecentActivity", 
        "Preventing inactivity"
      );

      // Attempt emergency recovery should fail
      await expect(
        token.connect(emergencyRecovery).burnFromInactive(
          user1.address, 
          ethers.parseEther("500"), 
          "Emergency recovery test"
        )
      ).to.be.revertedWith("EducToken: account is not inactive");
    });
  });

  describe("Daily Minting Limits", function () {
    it("Should track and limit daily minting", async function () {
      // Mint tokens up to daily limit
      const dailyLimit = DAILY_MINT_LIMIT;
      await token.connect(minter)["mint(address,uint256)"](user1.address, dailyLimit);

      // Check remaining minting capacity
      const remainingMintingCapacity = await token.getDailyMintingRemaining();
      expect(remainingMintingCapacity).to.equal(0);

      // Attempt to mint beyond daily limit should fail
      await expect(
        token.connect(minter)["mint(address,uint256)"](user1.address, ethers.parseEther("1"))
      ).to.be.revertedWith("EducToken: daily mint limit exceeded");
    });

    it("Should reset daily minting limit after 24 hours", async function () {
      // Mint up to daily limit
      await token.connect(minter)["mint(address,uint256)"](user1.address, DAILY_MINT_LIMIT);

      // Advance time by one day
      await time.increase(24 * 60 * 60);

      // Should be able to mint again
      const newMintAmount = ethers.parseEther("500");
      await token.connect(minter)["mint(address,uint256)"](user1.address, newMintAmount);

      const remainingMintingCapacity = await token.getDailyMintingRemaining();
      expect(remainingMintingCapacity).to.equal(DAILY_MINT_LIMIT - newMintAmount);
    });
  });

  describe("Emergency Withdrawal Mechanism", function () {
    it("Should allow emergency token withdrawal", async function () {
      // Mint tokens
      const initialAmount = ethers.parseEther("5000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, initialAmount);

      // Make tokens recoverable
      await time.increase(BURN_COOLDOWN_PERIOD + 1);

      // Perform emergency withdrawal
      const withdrawalAmount = ethers.parseEther("2500");
      await token.connect(emergencyRecovery).burnFromInactive(
        user1.address, 
        withdrawalAmount, 
        "Emergency withdrawal"
      );

      const finalBalance = await token.balanceOf(user1.address);
      expect(finalBalance).to.equal(initialAmount - withdrawalAmount);
    });
  });
});