const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("EducVesting Integration Tests", function () {
  let vestingContract;
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

    // Deploy Vesting Contract
    const VestingFactory = await ethers.getContractFactory("EducVesting");
    vestingContract = await VestingFactory.deploy(
      token.target, 
      treasury.address, 
      admin.address
    );

    // Mint and approve tokens for vesting
    await token.connect(admin).mint(admin.address, TOTAL_VESTING_AMOUNT);
    await token.connect(admin).approve(vestingContract.target, TOTAL_VESTING_AMOUNT);
  });

  describe("Vesting Schedule Creation", function () {
    it("Should create linear vesting schedule", async function () {
      const vestingSchedule = await vestingContract.createLinearVesting(
        beneficiary1.address,
        ethers.parseEther("3000"),
        await time.latest(),
        VESTING_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("linear_metadata"))
      );

      const scheduleId = (await vestingSchedule.wait()).logs[0].args[0];
      const schedule = await vestingContract.getVestingSchedule(scheduleId);

      expect(schedule.beneficiary).to.equal(beneficiary1.address);
      expect(schedule.totalAmount).to.equal(ethers.parseEther("3000"));
      expect(schedule.vestingType).to.equal(0); // Linear vesting type
    });

    it("Should create cliff vesting schedule", async function () {
      const vestingSchedule = await vestingContract.createCliffVesting(
        beneficiary2.address,
        ethers.parseEther("3000"),
        await time.latest(),
        CLIFF_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("cliff_metadata"))
      );

      const scheduleId = (await vestingSchedule.wait()).logs[0].args[0];
      const schedule = await vestingContract.getVestingSchedule(scheduleId);

      expect(schedule.beneficiary).to.equal(beneficiary2.address);
      expect(schedule.totalAmount).to.equal(ethers.parseEther("3000"));
      expect(schedule.vestingType).to.equal(1); // Cliff vesting type
    });
  });

  describe("Token Release Mechanics", function () {
    let linearScheduleId;

    beforeEach(async function () {
      const vestingSchedule = await vestingContract.createLinearVesting(
        beneficiary1.address,
        ethers.parseEther("3000"),
        await time.latest(),
        VESTING_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("linear_metadata"))
      );

      linearScheduleId = (await vestingSchedule.wait()).logs[0].args[0];
    });

    it("Should allow partial token release during vesting", async function () {
      // Advance time halfway through vesting
      await time.increase(VESTING_DURATION / 2);

      // Release tokens
      await vestingContract.connect(beneficiary1).release(linearScheduleId);

      // Check releasable amount
      const releasableAmount = await vestingContract.getReleasableAmount(linearScheduleId);
      const schedule = await vestingContract.getVestingSchedule(linearScheduleId);

      expect(releasableAmount).to.be.gt(0);
      expect(schedule.released).to.be.gt(0);
    });

    it("Should allow full token release after vesting period", async function () {
      // Advance time past vesting period
      await time.increase(VESTING_DURATION + 1);

      // Release all tokens
      await vestingContract.connect(beneficiary1).release(linearScheduleId);

      const schedule = await vestingContract.getVestingSchedule(linearScheduleId);
      expect(schedule.released).to.equal(ethers.parseEther("3000"));
    });
  });

  describe("Vesting Schedule Revocation", function () {
    let revocableScheduleId;

    beforeEach(async function () {
      const vestingSchedule = await vestingContract.createLinearVesting(
        beneficiary1.address,
        ethers.parseEther("3000"),
        await time.latest(),
        VESTING_DURATION,
        true,
        ethers.keccak256(ethers.toUtf8Bytes("revocable_metadata"))
      );

      revocableScheduleId = (await vestingSchedule.wait()).logs[0].args[0];
    });

    it("Should allow admin to revoke vesting schedule", async function () {
      // Advance time partially through vesting
      await time.increase(VESTING_DURATION / 2);

      // Revoke schedule
      await vestingContract.connect(admin).revoke(revocableScheduleId);

      const schedule = await vestingContract.getVestingSchedule(revocableScheduleId);
      expect(schedule.revoked).to.be.true;
    });
  });
});