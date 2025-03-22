const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducTokenWithRecovery Integration Tests", function () {
  let token;
  let student;
  let admin;
  let treasury;
  let emergencyRecovery;
  let user1;
  let minter;

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

    // Grant roles (use string hash to avoid possible address errors)
    const EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));
    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    
    await token.connect(admin).grantRole(EMERGENCY_ROLE, emergencyRecovery.address);
    await token.connect(admin).grantRole(MINTER_ROLE, minter.address);
  });

  describe("Daily Minting Limits", function () {
    it("Should track and limit daily minting", async function () {
      // Mint tokens up to daily limit
      const dailyLimit = ethers.parseEther("1000");
      await token.connect(minter).mint(user1.address, dailyLimit);

      // Check remaining minting capacity
      const remainingMintingCapacity = await token.getDailyMintingRemaining();
      expect(remainingMintingCapacity).to.equal(0);

      // Attempt to mint beyond daily limit should fail
      await expect(
        token.connect(minter).mint(user1.address, ethers.parseEther("1"))
      ).to.be.revertedWith("EducToken: daily mint limit exceeded");
    });
  });
});