const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Deploying EducLearning system...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // Deploy EducToken
  console.log("Deploying EducToken...");
  const EducToken = await ethers.getContractFactory("EducToken");
  const token = await EducToken.deploy(deployer.address);
  await token.deployed();
  console.log(`EducToken deployed to: ${token.address}`);

  // Deploy EducEducator
  console.log("Deploying EducEducator...");
  const EducEducator = await ethers.getContractFactory("EducEducator");
  const educator = await EducEducator.deploy(deployer.address);
  await educator.deployed();
  console.log(`EducEducator deployed to: ${educator.address}`);

  // Deploy EducStudent
  console.log("Deploying EducStudent...");
  const EducStudent = await ethers.getContractFactory("EducStudent");
  const student = await EducStudent.deploy(deployer.address);
  await student.deployed();
  console.log(`EducStudent deployed to: ${student.address}`);

  // Deploy EducCourse
  console.log("Deploying EducCourse...");
  const EducCourse = await ethers.getContractFactory("EducCourse");
  const course = await EducCourse.deploy(deployer.address, educator.address);
  await course.deployed();
  console.log(`EducCourse deployed to: ${course.address}`);

  // Deploy EducConfig
  console.log("Deploying EducConfig...");
  const EducConfig = await ethers.getContractFactory("EducConfig");
  const config = await EducConfig.deploy(deployer.address);
  await config.deployed();
  console.log(`EducConfig deployed to: ${config.address}`);

  // Deploy EducPause
  console.log("Deploying EducPause...");
  const EducPause = await ethers.getContractFactory("EducPause");
  const pauseControl = await EducPause.deploy(deployer.address);
  await pauseControl.deployed();
  console.log(`EducPause deployed to: ${pauseControl.address}`);

  // Deploy Multisig
  console.log("Deploying EducMultisig...");
  const EducMultisig = await ethers.getContractFactory("EducMultisig");
  const signers = [deployer.address]; // Initial signer is the deployer
  const multisig = await EducMultisig.deploy(signers, 1, deployer.address);
  await multisig.deployed();
  console.log(`EducMultisig deployed to: ${multisig.address}`);

  // Deploy EducProposal
  console.log("Deploying EducProposal...");
  const EducProposal = await ethers.getContractFactory("EducProposal");
  const proposal = await EducProposal.deploy(multisig.address, deployer.address);
  await proposal.deployed();
  console.log(`EducProposal deployed to: ${proposal.address}`);

  // Deploy main EducLearning contract
  console.log("Deploying EducLearning...");
  const EducLearning = await ethers.getContractFactory("EducLearning");
  const educLearning = await EducLearning.deploy(deployer.address);
  await educLearning.deployed();
  console.log(`EducLearning deployed to: ${educLearning.address}`);

  // Initialize the EducLearning contract
  console.log("Initializing EducLearning...");
  const initTx = await educLearning.initialize(
    token.address,
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

  // Setting up roles
  console.log("Setting up roles...");
  
  // Grant EDUCATOR_ROLE to EducLearning in the EducCourse contract
  const EDUCATOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("EDUCATOR_ROLE"));
  await course.grantRole(EDUCATOR_ROLE, educLearning.address);
  
  // Grant ADMIN_ROLE to EducLearning in all contracts for managing them
  const ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ADMIN_ROLE"));
  await token.grantRole(ADMIN_ROLE, educLearning.address);
  await educator.grantRole(ADMIN_ROLE, educLearning.address);
  await student.grantRole(ADMIN_ROLE, educLearning.address);

  // Grant MINTER_ROLE to EducLearning in the EducToken contract
  const MINTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));
  await token.grantRole(MINTER_ROLE, educLearning.address);

  console.log("Deployment and initialization complete!");

  // Print out all contract addresses for reference
  console.log("\nContract Addresses:");
  console.log("===================");
  console.log(`EducToken:     ${token.address}`);
  console.log(`EducEducator:  ${educator.address}`);
  console.log(`EducStudent:   ${student.address}`);
  console.log(`EducCourse:    ${course.address}`);
  console.log(`EducConfig:    ${config.address}`);
  console.log(`EducPause:     ${pauseControl.address}`);
  console.log(`EducMultisig:  ${multisig.address}`);
  console.log(`EducProposal:  ${proposal.address}`);
  console.log(`EducLearning:  ${educLearning.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });