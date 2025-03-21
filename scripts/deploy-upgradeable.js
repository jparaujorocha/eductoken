const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Deploying Upgradeable EducToken System...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // Define initial signers and threshold
  const signers = [deployer.address];
  const MULTISIG_THRESHOLD = signers.length; // Threshold equal to number of signers

  // Deploy EducTokenUpgradeable with UUPS proxy
  console.log("Deploying EducTokenUpgradeable...");
  const EducTokenUpgradeable = await ethers.getContractFactory("EducTokenUpgradeable");
  
  // Deploy proxy with initialize function
  const tokenProxy = await upgrades.deployProxy(
    EducTokenUpgradeable, 
    [deployer.address], 
    { 
      initializer: 'initialize',
      kind: 'uups'
    }
  );
  
  await tokenProxy.deployTransaction.wait();
  console.log(`EducTokenUpgradeable (Proxy) deployed to: ${tokenProxy.address}`);
  console.log(`EducTokenUpgradeable (Implementation) deployed to: ${await upgrades.erc1967.getImplementationAddress(tokenProxy.address)}`);

  // Define treasury for vesting and emergency recovery
  const treasury = deployer.address; // In production, this should be a separate secure wallet

  // Deploy EducVesting
  console.log("Deploying EducVesting...");
  const EducVesting = await ethers.getContractFactory("EducVesting");
  const vesting = await EducVesting.deploy(tokenProxy.address, treasury, deployer.address);
  await vesting.deployTransaction.wait();
  console.log(`EducVesting deployed to: ${vesting.address}`);

  // Continue with other essential contracts
  
  // Deploy EducEducator
  console.log("Deploying EducEducator...");
  const EducEducator = await ethers.getContractFactory("EducEducator");
  const educator = await EducEducator.deploy(deployer.address);
  await educator.deployTransaction.wait();
  console.log(`EducEducator deployed to: ${educator.address}`);

  // Deploy EducStudent
  console.log("Deploying EducStudent...");
  const EducStudent = await ethers.getContractFactory("EducStudent");
  const student = await EducStudent.deploy(deployer.address);
  await student.deployTransaction.wait();
  console.log(`EducStudent deployed to: ${student.address}`);

  // Deploy EducCourse
  console.log("Deploying EducCourse...");
  const EducCourse = await ethers.getContractFactory("EducCourse");
  const course = await EducCourse.deploy(deployer.address, educator.address);
  await course.deployTransaction.wait();
  console.log(`EducCourse deployed to: ${course.address}`);

  // Deploy EducConfig
  console.log("Deploying EducConfig...");
  const EducConfig = await ethers.getContractFactory("EducConfig");
  const config = await EducConfig.deploy(deployer.address);
  await config.deployTransaction.wait();
  console.log(`EducConfig deployed to: ${config.address}`);

  // Deploy EducPause
  console.log("Deploying EducPause...");
  const EducPause = await ethers.getContractFactory("EducPause");
  const pauseControl = await EducPause.deploy(deployer.address);
  await pauseControl.deployTransaction.wait();
  console.log(`EducPause deployed to: ${pauseControl.address}`);

  // Deploy Multisig with correct threshold
  console.log("Deploying EducMultisig...");
  const EducMultisig = await ethers.getContractFactory("EducMultisig");
  const multisig = await EducMultisig.deploy(
    signers,             // Initial signers
    MULTISIG_THRESHOLD,  // Threshold for approvals
    deployer.address     // Admin address
  );
  await multisig.deployTransaction.wait();
  console.log(`EducMultisig deployed to: ${multisig.address}`);

  // Deploy EducProposal
  console.log("Deploying EducProposal...");
  const EducProposal = await ethers.getContractFactory("EducProposal");
  const proposal = await EducProposal.deploy(multisig.address, deployer.address);
  await proposal.deployTransaction.wait();
  console.log(`EducProposal deployed to: ${proposal.address}`);

  // Deploy Emergency Recovery System
  console.log("Deploying EducEmergencyRecovery...");
  const EducEmergencyRecovery = await ethers.getContractFactory("EducEmergencyRecovery");
  const emergencyRecovery = await EducEmergencyRecovery.deploy(
    deployer.address,  // Admin
    treasury,         // Treasury address
    deployer.address, // System contract (temporary, will be updated to EducLearning)
    multisig.address  // Multisig
  );
  await emergencyRecovery.deployTransaction.wait();
  console.log(`EducEmergencyRecovery deployed to: ${emergencyRecovery.address}`);

  // Deploy main EducLearning contract
  console.log("Deploying EducLearning...");
  const EducLearning = await ethers.getContractFactory("EducLearning");
  const educLearning = await EducLearning.deploy(deployer.address);
  await educLearning.deployTransaction.wait();
  console.log(`EducLearning deployed to: ${educLearning.address}`);

  // Update System Contract reference in Emergency Recovery
  console.log("Updating emergency recovery system contract reference...");
  const updateTx = await emergencyRecovery.updateConfig(
    treasury,
    educLearning.address,
    7 * 24 * 60 * 60, // 7 days cooldown
    2 // approval threshold
  );
  await updateTx.wait();
  
  // Setting up roles BEFORE initialization
  console.log("Setting up roles...");
  
  const EDUCATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EDUCATOR_ROLE"));
  await student.grantRole(EDUCATOR_ROLE, educLearning.address);
  await course.grantRole(EDUCATOR_ROLE, educLearning.address);
  
  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  await tokenProxy.grantRole(ADMIN_ROLE, educLearning.address);
  await educator.grantRole(ADMIN_ROLE, educLearning.address);
  await student.grantRole(ADMIN_ROLE, educLearning.address);
  await course.grantRole(ADMIN_ROLE, educLearning.address);

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  await tokenProxy.grantRole(MINTER_ROLE, educLearning.address);
  
  // Grant emergency role to emergency recovery contract
  const EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));
  await pauseControl.grantRole(EMERGENCY_ROLE, emergencyRecovery.address);

  // Initialize the EducLearning contract AFTER granting roles
  console.log("Initializing EducLearning...");
  const initTx = await educLearning.initialize(
    tokenProxy.address,
    educator.address,
    student.address,
    course.address,
    config.address,
    pauseControl.address,
    multisig.address,
    proposal.address
  );
  await initTx.wait();
  console.log("EducLearning initialized");

  // Set up initial vesting schedules for team and partners
  console.log("Setting up initial token vesting schedules...");
  
  // Approve vesting contract to transfer tokens
  const approvalAmount = ethers.parseEther("3000000"); // 3 million tokens for vesting
  const approveTx = await tokenProxy.approve(vesting.address, approvalAmount);
  await approveTx.wait();
  
  // Create team vesting (1 million tokens, 2 year linear vesting with 6 month cliff)
  const now = Math.floor(Date.now() / 1000);
  const sixMonthsInSeconds = 180 * 24 * 60 * 60;
  const twoYearsInSeconds = 2 * 365 * 24 * 60 * 60;
  
  console.log("Creating team vesting schedule...");
  const teamVestingTx = await vesting.createHybridVesting(
    deployer.address, // Team address (replace in production)
    ethers.parseEther("1000000"), // 1 million tokens
    now, // Start now
    twoYearsInSeconds, // 2 year duration
    sixMonthsInSeconds, // 6 month cliff
    true, // Revocable
    ethers.id("TEAM_ALLOCATION") // Metadata
  );
  await teamVestingTx.wait();
  
  console.log("Creating advisors vesting schedule...");
  const advisorVestingTx = await vesting.createHybridVesting(
    deployer.address, // Advisor address (replace in production)
    ethers.parseEther("500000"), // 500k tokens
    now, // Start now
    twoYearsInSeconds, // 2 year duration
    sixMonthsInSeconds, // 6 month cliff
    true, // Revocable
    ethers.id("ADVISOR_ALLOCATION") // Metadata
  );
  await advisorVestingTx.wait();
  
  console.log("Creating milestone-based partnership vesting schedule...");
  const partnerVestingTx = await vesting.createMilestoneVesting(
    deployer.address, // Partner address (replace in production)
    ethers.parseEther("1500000"), // 1.5 million tokens
    now, // Start now
    twoYearsInSeconds, // Max 2 year duration
    5, // 5 milestones
    true, // Revocable
    ethers.id("PARTNERSHIP_ALLOCATION") // Metadata
  );
  await partnerVestingTx.wait();

  console.log("Deployment and initialization complete!");

  // Print out all contract addresses for reference
  console.log("\nContract Addresses:");
  console.log("===================");
  console.log(`EducTokenUpgradeable (Proxy): ${tokenProxy.address}`);
  console.log(`EducTokenUpgradeable (Implementation): ${await upgrades.erc1967.getImplementationAddress(tokenProxy.address)}`);
  console.log(`EducVesting:        ${vesting.address}`);
  console.log(`EducEducator:       ${educator.address}`);
  console.log(`EducStudent:        ${student.address}`);
  console.log(`EducCourse:         ${course.address}`);
  console.log(`EducConfig:         ${config.address}`);
  console.log(`EducPause:          ${pauseControl.address}`);
  console.log(`EducMultisig:       ${multisig.address}`);
  console.log(`EducProposal:       ${proposal.address}`);
  console.log(`EducEmergencyRecovery: ${emergencyRecovery.address}`);
  console.log(`EducLearning:       ${educLearning.address}`);
}