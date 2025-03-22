const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("EducTokenUpgradeable Integration Tests", function () {
  let token;
  let student;
  let educator;
  let admin;
  let user1;
  let minter;

  const DAILY_MINT_LIMIT = ethers.parseEther("1000");
  const BURN_COOLDOWN_PERIOD = 365 * 24 * 60 * 60; // 1 year

  beforeEach(async function () {
    [admin, _, _, user1, minter] = await ethers.getSigners();

    // Deploy student contract first
    const StudentFactory = await ethers.getContractFactory("EducStudent");
    student = await StudentFactory.deploy(admin.address);

    // Deploy educator contract
    const EducatorFactory = await ethers.getContractFactory("EducEducator");
    educator = await EducatorFactory.deploy(admin.address);

    // Deploy Token with Upgradeable Proxy
    const TokenFactory = await ethers.getContractFactory("EducTokenUpgradeable");
    token = await upgrades.deployProxy(
      TokenFactory, 
      [admin.address], 
      { 
        initializer: 'initialize',
        kind: 'uups'
      }
    );

    // Set student contract
    await token.connect(admin).setStudentContract(student.target);

    // Register student
    await student.connect(admin)["registerStudent(address)"](user1.address);

    // Register educator and grant minter role
    await educator.connect(admin)["registerEducator(address,uint256)"](minter.address, ethers.parseEther("10000"));
    await token.grantRole(await token.MINTER_ROLE(), minter.address);
  });

  describe("Proxy Upgradability", function () {
    it("Should deploy with correct initial configuration", async function () {
      expect(await token.name()).to.equal("EducToken");
      expect(await token.symbol()).to.equal("EDUC");
      expect(await token.balanceOf(admin.address)).to.equal(ethers.parseEther("10000000"));
    });

    it("Should allow upgrading the implementation", async function () {
      // Deploy V2 implementation
      const TokenV2Factory = await ethers.getContractFactory("EducTokenUpgradeable");
      const upgradedToken = await upgrades.upgradeProxy(token.target, TokenV2Factory);

      // Verify core functionality still works
      await upgradedToken.connect(minter)["mint(address,uint256)"](user1.address, ethers.parseEther("100"));
      expect(await upgradedToken.balanceOf(user1.address)).to.equal(ethers.parseEther("100"));
    });
  });

  describe("Token Minting and Rewards", function () {
    it("Should allow minting educational rewards", async function () {
      const rewardAmount = ethers.parseEther("50");
      const reason = "Course Completion";
      
      await token.connect(minter)["mintReward(address,uint256,string)"](user1.address, rewardAmount, reason);
      
      expect(await token.balanceOf(user1.address)).to.equal(rewardAmount);
    });

    it("Should track daily minting limits", async function () {
      // Mint tokens up to daily limit
      const dailyLimit = DAILY_MINT_LIMIT;
      await token.connect(minter)["mint(address,uint256)"](user1.address, dailyLimit);

      // Check remaining minting capacity
      const remainingMintingCapacity = await token.getDailyMintingRemaining();
      expect(remainingMintingCapacity).to.equal(0);

      // Attempt to mint beyond daily limit should fail
      await expect(
        token.connect(minter)["mint(address,uint256)"](user1.address, ethers.parseEther("1"))
      ).to.be.revertedWith("EducTokenUpgradeable: daily mint limit exceeded");
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

  describe("Token Burning", function () {
    it("Should allow burning tokens from inactive accounts", async function () {
      // Mint tokens
      const initialAmount = ethers.parseEther("5000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, initialAmount);

      // Make tokens recoverable by advancing time
      await time.increase(BURN_COOLDOWN_PERIOD + 1);

      // Perform token burn
      const burnAmount = ethers.parseEther("2500");
      await token.connect(admin).burnFromInactive(user1.address, burnAmount, "Inactive account");

      const finalBalance = await token.balanceOf(user1.address);
      expect(finalBalance).to.equal(initialAmount - burnAmount);
    });

    it("Should prevent burning from active accounts", async function () {
      // Mint tokens
      const initialAmount = ethers.parseEther("5000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, initialAmount);

      // Tokens are still active, so burning should fail
      await expect(
        token.connect(admin).burnFromInactive(user1.address, ethers.parseEther("2500"), "Inactive account")
      ).to.be.revertedWith("EducTokenUpgradeable: account is not inactive");
    });
  });

  describe("Pause Mechanism", function () {
    it("Should prevent token operations when paused", async function () {
      // Mint tokens first
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);

      // Pause the contract
      await token.connect(admin).pause();

      // Try various operations that should fail
      await expect(
        token.connect(user1).transfer(minter.address, ethers.parseEther("100"))
      ).to.be.revertedWith("Pausable: paused");

      await expect(
        token.connect(minter)["mint(address,uint256)"](user1.address, ethers.parseEther("50"))
      ).to.be.revertedWith("Pausable: paused");

      await expect(
        token.connect(user1).burn(ethers.parseEther("50"))
      ).to.be.revertedWith("Pausable: paused");
    });
  });
});