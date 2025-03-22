const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducVestingFactory Integration Tests", function () {
  let vestingFactory;
  let token1;
  let token2;
  let admin;
  let treasury;
  let beneficiary1;

  beforeEach(async function () {
    [admin, treasury, beneficiary1, _] = await ethers.getSigners();

    // Deploy multiple tokens
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token1 = await TokenFactory.deploy(admin.address);
    token2 = await TokenFactory.deploy(admin.address);

    // Deploy Vesting Factory
    const VestingFactoryFactory = await ethers.getContractFactory("EducVestingFactory");
    vestingFactory = await VestingFactoryFactory.deploy(admin.address);
  });

  describe("Vesting Contract Creation", function () {
  
    it("Should create vesting contracts for different tokens", async function () {
        // Create vesting contracts for different tokens
        const vestingContract1Tx = await vestingFactory.createVestingContract(
          token1.target, 
          treasury.address
        );
        const vestingContract1 = await vestingContract1Tx.wait();
        const vestingContractAddress1 = vestingContract1.logs[0].args[0];
      
        const vestingContractsToken1 = await vestingFactory.getVestingContractsForToken(token1.target);
        expect(vestingContractsToken1).to.include(vestingContractAddress1);
      });

    it("Should track multiple vesting contracts for the same token", async function () {
      // Create multiple vesting contracts for the same token
      const vestingContract1 = await vestingFactory.createVestingContract(
        token1.target, 
        treasury.address
      );

      const vestingContract2 = await vestingFactory.createVestingContract(
        token1.target, 
        treasury.address
      );

      // Get vesting contracts for the token
      const tokenVestingContracts = await vestingFactory.getVestingContractsForToken(token1.target);
      
      expect(tokenVestingContracts).to.have.lengthOf(2);
      expect(tokenVestingContracts).to.include(vestingContract1);
      expect(tokenVestingContracts).to.include(vestingContract2);
    });

    it("Should prevent creating vesting contract with zero addresses", async function () {
      await expect(
        vestingFactory.createVestingContract(
          ethers.ZeroAddress, 
          treasury.address
        )
      ).to.be.revertedWith("EducVestingFactory: Token cannot be zero address");

      await expect(
        vestingFactory.createVestingContract(
          token1.target, 
          ethers.ZeroAddress
        )
      ).to.be.revertedWith("EducVestingFactory: Treasury cannot be zero address");
    });
  });

  describe("Vesting Contract Management", function () {
    it("Should provide accurate vesting contract counts", async function () {
      // Create multiple vesting contracts across different tokens
      await vestingFactory.createVestingContract(token1.target, treasury.address);
      await vestingFactory.createVestingContract(token1.target, treasury.address);
      await vestingFactory.createVestingContract(token2.target, treasury.address);

      // Check total contracts count
      const totalContractsCount = await vestingFactory.getTotalVestingContractsCount();
      expect(totalContractsCount).to.equal(3);

      // Check token-specific contracts count
      const token1ContractsCount = await vestingFactory.getVestingContractsCountForToken(token1.target);
      const token2ContractsCount = await vestingFactory.getVestingContractsCountForToken(token2.target);

      expect(token1ContractsCount).to.equal(2);
      expect(token2ContractsCount).to.equal(1);
    });

    it("Should prevent non-admin from creating vesting contracts", async function () {
      const [, nonAdmin] = await ethers.getSigners();

      await expect(
        vestingFactory.connect(nonAdmin).createVestingContract(
          token1.target, 
          treasury.address
        )
      ).to.be.reverted;
    });
  });

  describe("Vesting Contract Interaction", function () {
    let vestingContract;

    beforeEach(async function () {
      // Create a vesting contract
      vestingContract = await vestingFactory.createVestingContract(
        token1.target, 
        treasury.address
      );

      // Mint tokens for vesting
      await token1.connect(admin).mint(admin.address, ethers.parseEther("10000"));
      await token1.connect(admin).approve(vestingContract, ethers.parseEther("5000"));
    });

    it("Should allow creating vesting schedules in created contracts", async function () {
      // Attach to the created vesting contract
      const VestingContract = await ethers.getContractFactory("EducVesting");
      const vestingContractInstance = VestingContract.attach(vestingContract);

      // Create linear vesting schedule
      const linearSchedule = await vestingContractInstance.createLinearVesting(
        beneficiary1.address,
        ethers.parseEther("3000"),
        await ethers.provider.getBlock('latest').then(block => block.timestamp),
        365 * 24 * 60 * 60, // 1 year
        true,
        ethers.keccak256(ethers.toUtf8Bytes("test_metadata"))
      );

      // Verify schedule creation
      const scheduleId = (await linearSchedule.wait()).logs[0].args[0];
      const schedule = await vestingContractInstance.getVestingSchedule(scheduleId);

      expect(schedule.beneficiary).to.equal(beneficiary1.address);
      expect(schedule.totalAmount).to.equal(ethers.parseEther("3000"));
    });
  });

  describe("Event Emission and Tracking", function () {
    it("Should emit VestingContractCreated event with correct details", async function () {
      const createTx = await vestingFactory.createVestingContract(
        token1.target, 
        treasury.address
      );

      const receipt = await createTx.wait();
      const createdEvent = receipt.logs.find(
        log => log.fragment && log.fragment.name === "VestingContractCreated"
      );

      expect(createdEvent).to.exist;
      expect(createdEvent.args[1]).to.equal(admin.address); // creator
      expect(createdEvent.args[2]).to.equal(token1.target); // token
    });
  });
});