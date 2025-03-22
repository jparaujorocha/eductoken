const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EducVestingCloneable", function () {
  let token, vesting, admin, treasury, beneficiary1, beneficiary2;

  // Standard setup, no fancy logic
  beforeEach(async function () {
    [admin, treasury, beneficiary1, beneficiary2] = await ethers.getSigners();
    
    // Deploy token
    const TokenFactory = await ethers.getContractFactory("EducToken");
    token = await TokenFactory.deploy(admin.address);
    
    // Deploy vesting
    const VestingFactory = await ethers.getContractFactory("EducVestingCloneable");
    vesting = await VestingFactory.deploy();
    
    // Initialize
    await vesting.initialize(
      await token.getAddress(),
      treasury.address,
      admin.address
    );
    
    // Mint and approve
    await token.mint(admin.address, ethers.parseEther("1000"));
    await token.approve(await vesting.getAddress(), ethers.parseEther("1000"));
  });

  it("Should create milestone vesting schedule", async function() {
    const startTime = (await ethers.provider.getBlock('latest')).timestamp + 100;
    
    // Create milestone vesting
    await vesting.createMilestoneVesting(
      beneficiary1.address,
      ethers.parseEther("200"),
      startTime,
      365 * 24 * 60 * 60, // 1 year
      5, // 5 milestones
      true,
      ethers.keccak256(ethers.toUtf8Bytes("milestone"))
    );
    
    // Get schedules for the beneficiary
    const schedules = await vesting.getVestingSchedulesForBeneficiary(beneficiary1.address);
    expect(schedules.length).to.equal(1);
    
    // Get and verify the schedule
    const schedule = await vesting.getVestingSchedule(schedules[0]);
    expect(schedule.beneficiary).to.equal(beneficiary1.address);
    expect(schedule.milestoneCount).to.equal(5);
    
    // Check count increased properly
    const count = await vesting.getVestingSchedulesCount();
    expect(count).to.equal(1n); // Using BigInt literal
  });

  it("Should create hybrid vesting schedule", async function() {
    const startTime = (await ethers.provider.getBlock('latest')).timestamp + 100;
    
    // Create hybrid vesting
    await vesting.createHybridVesting(
      beneficiary2.address,
      ethers.parseEther("300"),
      startTime,
      365 * 24 * 60 * 60, // 1 year
      180 * 24 * 60 * 60, // 6 months cliff
      true,
      ethers.keccak256(ethers.toUtf8Bytes("hybrid"))
    );
    
    // Get schedules for the beneficiary
    const schedules = await vesting.getVestingSchedulesForBeneficiary(beneficiary2.address);
    expect(schedules.length).to.equal(1);
    
    // Get and verify the schedule
    const schedule = await vesting.getVestingSchedule(schedules[0]);
    expect(schedule.beneficiary).to.equal(beneficiary2.address);
    expect(schedule.cliffDuration).to.equal(180 * 24 * 60 * 60);
    
    // Check count increased properly
    const count = await vesting.getVestingSchedulesCount();
    expect(count).to.equal(1n); // Using BigInt literal
  });

  it("Should track vesting count increments correctly", async function() {
    const startTime = (await ethers.provider.getBlock('latest')).timestamp + 100;
    
    // Verify initial count
    const initialCount = await vesting.getVestingSchedulesCount();
    expect(initialCount).to.equal(0n);
    
    // Create first schedule
    await vesting.createLinearVesting(
      beneficiary1.address,
      ethers.parseEther("100"),
      startTime,
      365 * 24 * 60 * 60,
      true,
      ethers.keccak256(ethers.toUtf8Bytes("linear1"))
    );
    
    // Verify count after first schedule
    const countAfterFirst = await vesting.getVestingSchedulesCount();
    expect(countAfterFirst).to.equal(1n);
    
    // Create second schedule
    await vesting.createLinearVesting(
      beneficiary2.address,
      ethers.parseEther("100"),
      startTime,
      365 * 24 * 60 * 60,
      true,
      ethers.keccak256(ethers.toUtf8Bytes("linear2"))
    );
    
    // Verify count after second schedule
    const countAfterSecond = await vesting.getVestingSchedulesCount();
    expect(countAfterSecond).to.equal(2n);
  });
});