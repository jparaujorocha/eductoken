const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("EducVestingCloneable Integration Tests", function () {
  let vestingCloneableContract;
  let token;
  let admin;
  let treasury;
  let beneficiary1;
  let beneficiary2;

  const TOTAL_VESTING_AMOUNT = ethers.parseEther("10000");
  const VESTING_DURATION = 365 * 24 * 60 * 60; // 1 year
  const CLIFF_DURATION = 180 * 24 * 60 * 60; // 6 months

  beforeEach(async function () {
    [admin, treasury, beneficiary1, beneficiary2] = await ethers.getSigners();

    // Deploy Token
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token = await TokenFactory.deploy(admin.address);

    // Deploy Vesting Cloneable Contract
    const VestingCloneableFactory = await ethers.getContractFactory("EducVestingCloneable");
    vestingCloneableContract = await VestingCloneableFactory.deploy();

    // Initialize cloneable contract
    await vestingCloneableContract.initialize(
      token.target, 
      treasury.address, 
      admin.address
    );

    // Mint and approve tokens for vesting
    await token.connect(admin).mint(admin.address, TOTAL_VESTING_AMOUNT);
    await token.connect(admin).approve(vestingCloneableContract.target, TOTAL_VESTING_AMOUNT);
  });

  describe("Vesting Schedule Creation", function () {
    it("Should create milestone-based vesting schedule", async function () {
      const vestingSchedule = await vestingCloneableContract.createMilestoneVesting(
        beneficiary1.address,
        ethers.parseEther("5000"),
        await time.latest(),
        VESTING_DURATION,
        5, // 5 milestones
        true,
        ethers.keccak256(ethers.toUtf8Bytes("milestone_metadata"))
      );

      const scheduleId = (await vestingSchedule.wait()).logs[0].args[0];
      const schedule = await vestingCloneableContract.getVestingSchedule(scheduleId);

      expect(schedule.beneficiary).to.equal(beneficiary1.address);
      expect(schedule.totalAmount).to.equal(ethers.parseEther("5000"));
      expect(schedule.vestingType).to.equal(3); // Milestone vesting type
      expect(schedule.milestoneCount).to.equal(5);
    });

    it("Should create hybrid vesting schedule", async function () {
      const vestingSchedule = await vestingCloneableContract.createHybridVesting(
        beneficiary2.address,
        ethers.parseEther("4000"),
        await time.latest(),
        VESTING_DURATION,
        CLIFF_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("hybrid_metadata"))
      );

      const scheduleId = (await vestingSchedule.wait()).logs[0].args[0];
      const schedule = await vestingCloneableContract.getVestingSchedule(scheduleId);

      expect(schedule.beneficiary).to.equal(beneficiary2.address);
      expect(schedule.totalAmount).to.equal(ethers.parseEther("4000"));
      expect(schedule.vestingType).to.equal(2); // Hybrid vesting type
      expect(schedule.cliffDuration).to.equal(CLIFF_DURATION);
    });
  });

  describe("Milestone Vesting Mechanics", function () {
    let milestoneScheduleId;

    beforeEach(async function () {
      const vestingSchedule = await vestingCloneableContract.createMilestoneVesting(
        beneficiary1.address,
        ethers.parseEther("5000"),
        await time.latest(),
        VESTING_DURATION,
        5, // 5 milestones
        true,
        ethers.keccak256(ethers.toUtf8Bytes("milestone_test"))
      );

      milestoneScheduleId = (await vestingSchedule.wait()).logs[0].args[0];
    });

    it("Should allow completing milestones and releasing tokens", async function () {
      // Complete first milestone
      await vestingCloneableContract.connect(admin).completeMilestone(milestoneScheduleId);

      // Check schedule after first milestone
      const scheduleAfterFirstMilestone = await vestingCloneableContract.getVestingSchedule(milestoneScheduleId);
      
      expect(scheduleAfterFirstMilestone.milestonesReached).to.equal(1);
      expect(scheduleAfterFirstMilestone.released).to.equal(ethers.parseEther("1000")); // 1/5 of total amount
    });

    it("Should prevent completing more milestones than defined", async function () {
      // Complete all 5 milestones
      for (let i = 0; i < 5; i++) {
        await vestingCloneableContract.connect(admin).completeMilestone(milestoneScheduleId);
      }

      // Try to complete 6th milestone
      await expect(
        vestingCloneableContract.connect(admin).completeMilestone(milestoneScheduleId)
      ).to.be.revertedWith("EducVesting: All milestones completed");
    });
  });

  describe("Schedule Transfer Mechanism", function () {
    let scheduleId;

    beforeEach(async function () {
      const vestingSchedule = await vestingCloneableContract.createLinearVesting(
        beneficiary1.address,
        ethers.parseEther("3000"),
        await time.latest(),
        VESTING_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("transfer_test"))
      );

      scheduleId = (await vestingSchedule.wait()).logs[0].args[0];
    });

    it("Should allow transferring vesting schedule", async function () {
      // Transfer schedule from beneficiary1 to beneficiary2
      await vestingCloneableContract.connect(beneficiary1).transferVestingSchedule(
        scheduleId, 
        beneficiary2.address
      );

      const updatedSchedule = await vestingCloneableContract.getVestingSchedule(scheduleId);
      expect(updatedSchedule.beneficiary).to.equal(beneficiary2.address);
    });
  });
});