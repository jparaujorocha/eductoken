const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying EducLearning system...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // Deploy EducToken
  console.log("Deploying EducToken...");
  const EducToken = await ethers.getContractFactory("EducToken");
  const token = await EducToken.deploy(deployer.address);
  await token.deploymentTransaction().wait();
  console.log(`EducToken deployed to: ${token.target}`);

  // Deploy EducEducator
  console.log("Deploying EducEducator...");
  const EducEducator = await ethers.getContractFactory("EducEducator");
  const educator = await EducEducator.deploy(deployer.address);
  await educator.deploymentTransaction().wait();
  console.log(`EducEducator deployed to: ${educator.target}`);

  // Deploy EducStudent
  console.log("Deploying EducStudent...");
  const EducStudent = await ethers.getContractFactory("EducStudent");
  const student = await EducStudent.deploy(deployer.address);
  await student.deploymentTransaction().wait();
  console.log(`EducStudent deployed to: ${student.target}`);

  // Deploy EducCourse
  console.log("Deploying EducCourse...");
  const EducCourse = await ethers.getContractFactory("EducCourse");
  const course = await EducCourse.deploy(deployer.address, educator.target);
  await course.deploymentTransaction().wait();
  console.log(`EducCourse deployed to: ${course.target}`);

  // Deploy EducConfig
  console.log("Deploying EducConfig...");
  const EducConfig = await ethers.getContractFactory("EducConfig");
  const config = await EducConfig.deploy(deployer.address);
  await config.deploymentTransaction().wait();
  console.log(`EducConfig deployed to: ${config.target}`);

  // Deploy EducPause
  console.log("Deploying EducPause...");
  const EducPause = await ethers.getContractFactory("EducPause");
  const pauseControl = await EducPause.deploy(deployer.address);
  await pauseControl.deploymentTransaction().wait();
  console.log(`EducPause deployed to: ${pauseControl.target}`);

  // Deploy Multisig
  console.log("Deploying EducMultisig...");
  const EducMultisig = await ethers.getContractFactory("EducMultisig");
  const signers = [deployer.address];
  const multisig = await EducMultisig.deploy(signers, 1, deployer.address);
  await multisig.deploymentTransaction().wait();
  console.log(`EducMultisig deployed to: ${multisig.target}`);

  // Deploy EducProposal
  console.log("Deploying EducProposal...");
  const EducProposal = await ethers.getContractFactory("EducProposal");
  const proposal = await EducProposal.deploy(multisig.target, deployer.address);
  await proposal.deploymentTransaction().wait();
  console.log(`EducProposal deployed to: ${proposal.target}`);

  // Deploy main EducLearning contract
  console.log("Deploying EducLearning...");
  const EducLearning = await ethers.getContractFactory("EducLearning");
  const educLearning = await EducLearning.deploy(deployer.address);
  await educLearning.deploymentTransaction().wait();
  console.log(`EducLearning deployed to: ${educLearning.target}`);

  // Initialize the EducLearning contract
  console.log("Initializing EducLearning...");
  const initTx = await educLearning.initialize(
    token.target,
    educator.target,
    student.target,
    course.target,
    config.target,
    pauseControl.target,
    multisig.target,
    proposal.target
  );
  await initTx.wait();
  console.log("EducLearning initialized");

  // Setting up roles
  console.log("Setting up roles...");
  
  const EDUCATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EDUCATOR_ROLE"));
  await course.grantRole(EDUCATOR_ROLE, educLearning.target);
  
  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  await token.grantRole(ADMIN_ROLE, educLearning.target);
  await educator.grantRole(ADMIN_ROLE, educLearning.target);
  await student.grantRole(ADMIN_ROLE, educLearning.target);

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  await token.grantRole(MINTER_ROLE, educLearning.target);

  console.log("Deployment and initialization complete!");

  // Print out all contract addresses for reference
  console.log("\nContract Addresses:");
  console.log("===================");
  console.log(`EducToken:     ${token.target}`);
  console.log(`EducEducator:  ${educator.target}`);
  console.log(`EducStudent:   ${student.target}`);
  console.log(`EducCourse:    ${course.target}`);
  console.log(`EducConfig:    ${config.target}`);
  console.log(`EducPause:     ${pauseControl.target}`);
  console.log(`EducMultisig:  ${multisig.target}`);
  console.log(`EducProposal:  ${proposal.target}`);
  console.log(`EducLearning:  ${educLearning.target}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });