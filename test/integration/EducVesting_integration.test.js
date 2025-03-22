const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducVesting Integration Tests", function () {
  let vestingContract;
  let token;
  let admin;
  let treasury;
  let beneficiary1;
  let beneficiary2;

  const TOTAL_VESTING_AMOUNT = ethers.parseEther("1000");
  const VESTING_DURATION = 365 * 24 * 60 * 60; // 1 year
  const CLIFF_DURATION = 180 * 24 * 60 * 60; // 6 months

  // Vesting type enum values
  const VESTING_TYPE = {
    LINEAR: 0,
    CLIFF: 1,
    HYBRID: 2,
    MILESTONE: 3
  };

  beforeEach(async function () {
    [admin, treasury, beneficiary1, beneficiary2] = await ethers.getSigners();

    // Deploy Token
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token = await TokenFactory.deploy(admin.address);

    // Deploy Vesting Contract
    const VestingFactory = await ethers.getContractFactory("EducVesting");
    vestingContract = await VestingFactory.deploy(
      await token.getAddress(), 
      await treasury.getAddress(), 
      admin.address
    );

    // Mint tokens for vesting
    await token.connect(admin).mint(admin.address, TOTAL_VESTING_AMOUNT);
    await token.connect(admin).approve(await vestingContract.getAddress(), TOTAL_VESTING_AMOUNT);
  });

  describe("Vesting Schedule Creation", function () {
    it("Should create linear vesting schedule", async function () {
      const currentBlock = await ethers.provider.getBlock('latest');
      const startTime = currentBlock.timestamp + (24 * 3600);
      
      const createTx = await vestingContract.createLinearVesting(
        beneficiary1.address,
        ethers.parseEther("300"),
        startTime,
        VESTING_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("linear_metadata"))
      );
      
      await createTx.wait();
      
      // Adjust to match actual contract method
      const schedulesCount = await vestingContract.vestingSchedulesCount();
      expect(schedulesCount).to.equal(1);
    });
    
    it("Should create cliff vesting schedule", async function () {
      const currentBlock = await ethers.provider.getBlock('latest');
      const startTime = currentBlock.timestamp + (24 * 3600);
      
      const createTx = await vestingContract.createCliffVesting(
        beneficiary2.address,
        ethers.parseEther("300"),
        startTime,
        CLIFF_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("cliff_metadata"))
      );
      
      await createTx.wait();
      
      // Adjust to match actual contract method
      const schedulesCount = await vestingContract.vestingSchedulesCount();
      expect(schedulesCount).to.equal(1);
    });
  });
});