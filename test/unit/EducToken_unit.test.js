const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("EducToken", function () {
  let EducToken;
  let token;
  let EducStudent;
  let student;
  let admin;
  let user1;
  let user2;
  let user3;
  let minter;
  
  // Constants for roles
  let ADMIN_ROLE;
  let MINTER_ROLE;
  
  // Constants from SystemConstants
  const INITIAL_SUPPLY = ethers.parseEther("10000000"); // 10 million tokens
  const MAX_MINT_AMOUNT = ethers.parseEther("100000"); // 100k tokens
  const DAILY_MINT_LIMIT = ethers.parseEther("1000"); // 1k tokens per day
  const BURN_COOLDOWN_PERIOD = 365 * 24 * 60 * 60; // 1 year in seconds

  beforeEach(async function () {
    // Get signers
    [admin, user1, user2, user3, minter] = await ethers.getSigners();
    
    // Calculate role hashes
    ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
    MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    
    // Deploy student contract first (needed for token's activity tracking)
    EducStudent = await ethers.getContractFactory("EducStudent");
    student = await EducStudent.deploy(admin.address);
    
    // Deploy token contract
    EducToken = await ethers.getContractFactory("EducToken");
    token = await EducToken.deploy(admin.address);
    
    // Set student contract in token
    await token.setStudentContract(student.target);
    
    // Grant minter role to the minter account
    await token.grantRole(MINTER_ROLE, minter.address);
  });

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      expect(await token.hasRole(ADMIN_ROLE, admin.address)).to.equal(true);
    });

    it("Should set the right name and symbol", async function () {
      expect(await token.name()).to.equal("EducToken");
      expect(await token.symbol()).to.equal("EDUC");
    });

    it("Should mint initial supply to admin", async function () {
      expect(await token.balanceOf(admin.address)).to.equal(INITIAL_SUPPLY);
    });
    
    it("Should track total minted amount", async function () {
      expect(await token.getTotalMinted()).to.equal(INITIAL_SUPPLY);
      expect(await token.getTotalBurned()).to.equal(0);
    });
  });

  describe("Role Management", function () {
    it("Should allow admin to grant roles", async function () {
      await token.grantRole(MINTER_ROLE, user1.address);
      expect(await token.hasRole(MINTER_ROLE, user1.address)).to.equal(true);
    });

    it("Should allow admin to revoke roles", async function () {
      await token.grantRole(MINTER_ROLE, user1.address);
      await token.revokeRole(MINTER_ROLE, user1.address);
      expect(await token.hasRole(MINTER_ROLE, user1.address)).to.equal(false);
    });

    it("Should not allow non-admin to grant roles", async function () {
      await expect(
        token.connect(user1).grantRole(MINTER_ROLE, user2.address)
      ).to.be.reverted;
    });
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      expect(await token.balanceOf(user1.address)).to.equal(mintAmount);
    });

    it("Should update total minted amount when minting", async function () {
      const mintAmount = ethers.parseEther("1000");
      const initialTotalMinted = await token.getTotalMinted();
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      expect(await token.getTotalMinted()).to.equal(initialTotalMinted + mintAmount);
    });
    
    it("Should emit TokensMinted event when minting", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount))
        .to.emit(token, "TokensMinted")
        .withArgs(user1.address, mintAmount, minter.address);
    });

    it("Should not allow minting to zero address", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(
        token.connect(minter)["mint(address,uint256)"](ethers.ZeroAddress, mintAmount)
      ).to.be.revertedWith("EducToken: zero address not allowed");
    });

    it("Should not allow minting more than MAX_MINT_AMOUNT", async function () {
      await expect(
        token.connect(minter)["mint(address,uint256)"](user1.address, MAX_MINT_AMOUNT + BigInt(1))
      ).to.be.revertedWith("EducToken: amount exceeds max mint amount");
    });

    it("Should not allow minting more than DAILY_MINT_LIMIT", async function () {
      // First mint to reach the daily limit
      await token.connect(minter)["mint(address,uint256)"](user1.address, DAILY_MINT_LIMIT);
      
      // Second mint should fail because we've reached the daily limit
      await expect(
        token.connect(minter)["mint(address,uint256)"](user2.address, 1)
      ).to.be.revertedWith("EducToken: daily mint limit exceeded");
    });

    it("Should reset daily minting limit after a day passes", async function () {
      // First mint to reach the daily limit
      await token.connect(minter)["mint(address,uint256)"](user1.address, DAILY_MINT_LIMIT);
      
      // Increase time by 1 day
      await time.increase(24 * 60 * 60);
      
      // Should be able to mint again after a day passes
      await token.connect(minter)["mint(address,uint256)"](user2.address, DAILY_MINT_LIMIT);
      expect(await token.balanceOf(user2.address)).to.equal(DAILY_MINT_LIMIT);
    });

    it("Should not allow non-minter to mint tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(
        token.connect(user1)["mint(address,uint256)"](user2.address, mintAmount)
      ).to.be.revertedWith("EducToken: caller is not a minter");
    });
  });

  describe("Educational Rewards", function () {
    it("Should allow minting as educational rewards", async function () {
      const rewardAmount = ethers.parseEther("100");
      await token.connect(minter)["mintReward(address,uint256,string)"](user1.address, rewardAmount, "Completed Course");
      expect(await token.balanceOf(user1.address)).to.equal(rewardAmount);
    });

    it("Should emit RewardIssued event when minting rewards", async function () {
      const rewardAmount = ethers.parseEther("100");
      const reason = "Completed Course";
      
      await expect(token.connect(minter)["mintReward(address,uint256,string)"](user1.address, rewardAmount, reason))
        .to.emit(token, "RewardIssued")
        .withArgs(user1.address, rewardAmount, reason);
    });

    it("Should fail when minting reward with empty reason", async function () {
      const rewardAmount = ethers.parseEther("100");
      await expect(
        token.connect(minter)["mintReward(address,uint256,string)"](user1.address, rewardAmount, "")
      ).to.be.revertedWith("EducToken: reason cannot be empty");
    });

    it("Should allow batch minting of educational rewards", async function () {
      const students = [user1.address, user2.address, user3.address];
      const amounts = [
        ethers.parseEther("50"),
        ethers.parseEther("75"),
        ethers.parseEther("100")
      ];
      const reasons = ["Quiz", "Assignment", "Project"];
      
      await token.connect(minter)["batchMintReward(address[],uint256[],string[])"](students, amounts, reasons);
      
      expect(await token.balanceOf(user1.address)).to.equal(amounts[0]);
      expect(await token.balanceOf(user2.address)).to.equal(amounts[1]);
      expect(await token.balanceOf(user3.address)).to.equal(amounts[2]);
    });

    it("Should fail batch minting with mismatched arrays", async function () {
      const students = [user1.address, user2.address];
      const amounts = [ethers.parseEther("50")];
      const reasons = ["Quiz", "Assignment"];
      
      await expect(
        token.connect(minter)["batchMintReward(address[],uint256[],string[])"](students, amounts, reasons)
      ).to.be.revertedWith("EducToken: arrays length mismatch");
    });

    it("Should fail batch minting with empty arrays", async function () {
      await expect(
        token.connect(minter)["batchMintReward(address[],uint256[],string[])"]([], [], [])
      ).to.be.revertedWith("EducToken: empty arrays");
    });
  });
  
  describe("Burning", function () {
    it("Should allow anyone to burn their own tokens", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Then burn a portion of them
      const burnAmount = ethers.parseEther("400");
      await token.connect(user1).burn(burnAmount);
      
      expect(await token.balanceOf(user1.address)).to.equal(mintAmount - burnAmount);
      expect(await token.getTotalBurned()).to.equal(burnAmount);
    });

    it("Should emit TokensBurned event when burning", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Then burn a portion of them
      const burnAmount = ethers.parseEther("400");
      await expect(token.connect(user1).burn(burnAmount))
        .to.emit(token, "TokensBurned")
        .withArgs(user1.address, burnAmount);
    });

    it("Should not allow burning more than balance", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Try to burn more than the balance
      const burnAmount = ethers.parseEther("1001");
      await expect(
        token.connect(user1).burn(burnAmount)
      ).to.be.revertedWith("EducToken: burn amount exceeds balance");
    });

    it("Should allow admin to burn tokens from inactive accounts", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Register user1 as student
      await student["registerStudent(address)"](user1.address);
      
      // Get the last activity time to make this account appear inactive
      await student["recordCustomActivity(address,string,string)"](user1.address, "Test", "Initial activity");
      
      // Increase time to make user1 inactive
      await time.increase(BURN_COOLDOWN_PERIOD + 1);
      
      // Now admin should be able to burn tokens from the inactive account
      const burnAmount = ethers.parseEther("500");
      await token.connect(admin).burnFromInactive(user1.address, burnAmount, "Inactive account");
      
      expect(await token.balanceOf(user1.address)).to.equal(mintAmount - burnAmount);
      expect(await token.getTotalBurned()).to.equal(burnAmount);
    });

    it("Should emit TokensBurnedFrom event when burning from inactive accounts", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Register user1 as student
      await student["registerStudent(address)"](user1.address);
      
      // Get the last activity time to make this account appear inactive
      await student["recordCustomActivity(address,string,string)"](user1.address, "Test", "Initial activity");
      
      // Increase time to make user1 inactive
      await time.increase(BURN_COOLDOWN_PERIOD + 1);
      
      // Now admin should be able to burn tokens from the inactive account
      const burnAmount = ethers.parseEther("500");
      const reason = "Inactive account";
      
      await expect(token.connect(admin).burnFromInactive(user1.address, burnAmount, reason))
        .to.emit(token, "TokensBurnedFrom")
        .withArgs(user1.address, burnAmount, admin.address, reason);
    });

    it("Should not allow burning from active accounts", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Register user1 as student
      await student["registerStudent(address)"](user1.address);
      
      // Get the last activity time to make this account appear inactive
      await student["recordCustomActivity(address,string,string)"](user1.address, "Test", "Recent activity");
      
      // Account is active (no time increase), so this should fail
      const burnAmount = ethers.parseEther("500");
      await expect(
        token.connect(admin).burnFromInactive(user1.address, burnAmount, "Inactive account")
      ).to.be.revertedWith("EducToken: account is not inactive");
    });
  });

  describe("Pausing", function () {
    it("Should allow admin to pause the contract", async function () {
      await token.connect(admin).pause();
      expect(await token.paused()).to.equal(true);
    });

    it("Should allow admin to unpause the contract", async function () {
      await token.connect(admin).pause();
      await token.connect(admin).unpause();
      expect(await token.paused()).to.equal(false);
    });

    it("Should not allow non-admin to pause the contract", async function () {
      await expect(token.connect(user1).pause()).to.be.reverted;
    });

    it("Should prevent transfers when paused", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Pause the contract
      await token.connect(admin).pause();
      
      // Try to transfer tokens - should fail
      await expect(
        token.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.reverted;
    });

    it("Should prevent minting when paused", async function () {
      // Pause the contract
      await token.connect(admin).pause();
      
      // Try to mint tokens - should fail
      await expect(
        token.connect(minter)["mint(address,uint256)"](user1.address, ethers.parseEther("100"))
      ).to.be.reverted;
    });
    
    it("Should prevent burning when paused", async function () {
      // First mint some tokens to user1
      const mintAmount = ethers.parseEther("1000");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Pause the contract
      await token.connect(admin).pause();
      
      // Try to burn tokens - should fail
      await expect(
        token.connect(user1).burn(ethers.parseEther("100"))
      ).to.be.reverted;
    });
  });
  
  describe("Student Contract Integration", function () {
    it("Should correctly set the student contract", async function () {
      // Deploy a new student contract
      const newStudent = await EducStudent.deploy(admin.address);
      
      // Set the new student contract
      await token.connect(admin).setStudentContract(newStudent.target);
      
      // Verify the student contract was set correctly
      const contractAddress = await token.studentContract();
      expect(contractAddress).to.equal(newStudent.target);
    });
    
    it("Should emit StudentContractSet event when setting student contract", async function () {
      // Deploy a new student contract
      const newStudent = await EducStudent.deploy(admin.address);
      
      // Set the new student contract and check for event
      await expect(token.connect(admin).setStudentContract(newStudent.target))
        .to.emit(token, "StudentContractSet")
        .withArgs(newStudent.target);
    });
    
    it("Should not allow non-admin to set student contract", async function () {
      // Deploy a new student contract
      const newStudent = await EducStudent.deploy(admin.address);
      
      // Try to set the student contract as non-admin
      await expect(
        token.connect(user1).setStudentContract(newStudent.target)
      ).to.be.reverted;
    });
    
    it("Should not allow setting student contract to zero address", async function () {
      await expect(
        token.connect(admin).setStudentContract(ethers.ZeroAddress)
      ).to.be.revertedWith("EducToken: zero address not allowed");
    });
  });
  
  describe("Daily Minting Limit", function () {
    it("Should return correct daily minting remaining", async function () {
      // Mint some tokens first
      const mintAmount = ethers.parseEther("400");
      await token.connect(minter)["mint(address,uint256)"](user1.address, mintAmount);
      
      // Check remaining amount
      const remaining = await token.getDailyMintingRemaining();
      expect(remaining).to.equal(DAILY_MINT_LIMIT - mintAmount);
    });
    
    it("Should return zero when daily limit is reached", async function () {
      // Mint tokens to reach the daily limit
      await token.connect(minter)["mint(address,uint256)"](user1.address, DAILY_MINT_LIMIT);
      
      // Check remaining amount
      const remaining = await token.getDailyMintingRemaining();
      expect(remaining).to.equal(0);
    });
    
    it("Should reset daily limit after a day passes", async function () {
      // Mint tokens to reach the daily limit
      await token.connect(minter)["mint(address,uint256)"](user1.address, DAILY_MINT_LIMIT);
      
      // Increase time by 1 day
      await time.increase(24 * 60 * 60);
      
      // Check remaining amount - should be reset to the full limit
      const remaining = await token.getDailyMintingRemaining();
      expect(remaining).to.equal(DAILY_MINT_LIMIT);
    });
  });
  
  describe("Account Inactivity", function () {
    it("Should correctly identify inactive accounts", async function () {
      // Register user1 as student
      await student["registerStudent(address)"](user1.address);
      
      // Record activity
      await student["recordCustomActivity(address,string,string)"](user1.address, "Test", "Initial activity");
      
      // Account should be active now
      expect(await token.isAccountInactive(user1.address)).to.equal(false);
      
      // Increase time to make user1 inactive
      await time.increase(BURN_COOLDOWN_PERIOD + 1);
      
      // Account should be inactive now
      expect(await token.isAccountInactive(user1.address)).to.equal(true);
    });
    
    it("Should always consider admin accounts as active", async function () {
      // Register admin as student
      await student["registerStudent(address)"](admin.address);
      
      // Record activity
      await student["recordCustomActivity(address,string,string)"](admin.address, "Test", "Initial activity");
      
      // Increase time to normally make account inactive
      await time.increase(BURN_COOLDOWN_PERIOD + 1);
      
      // Admin account should still be considered active
      expect(await token.isAccountInactive(admin.address)).to.equal(false);
    });
    
    it("Should consider non-student accounts as active", async function () {
      // user1 is not registered as a student
      
      // Increase time
      await time.increase(BURN_COOLDOWN_PERIOD + 1);
      
      // Non-student account should be considered active
      expect(await token.isAccountInactive(user1.address)).to.equal(false);
    });
  });
});