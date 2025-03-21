const { run, ethers } = require("hardhat");

// Contract addresses (to be set after deployment)
const ADDRESSES = {
  EducToken: "",
  EducEducator: "",
  EducStudent: "",
  EducCourse: "",
  EducConfig: "",
  EducPause: "",
  EducMultisig: "",
  EducProposal: "",
  EducLearning: "",
};

// Admin address (deployer)
const ADMIN_ADDRESS = "";

// Initial signers for multisig (can be an array with multiple addresses)
const MULTISIG_SIGNERS = [ADMIN_ADDRESS];
const MULTISIG_THRESHOLD = 1;

async function verify() {
  console.log("Starting contract verification...");

  try {
    // Verify EducToken
    console.log("\nVerifying EducToken...");
    await run("verify:verify", {
      address: ADDRESSES.EducToken,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/core/EducToken.sol:EducToken",
    });

    // Verify EducEducator
    console.log("\nVerifying EducEducator...");
    await run("verify:verify", {
      address: ADDRESSES.EducEducator,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/core/EducEducator.sol:EducEducator",
    });

    // Verify EducStudent
    console.log("\nVerifying EducStudent...");
    await run("verify:verify", {
      address: ADDRESSES.EducStudent,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/core/EducStudent.sol:EducStudent",
    });

    // Verify EducCourse
    console.log("\nVerifying EducCourse...");
    await run("verify:verify", {
      address: ADDRESSES.EducCourse,
      constructorArguments: [ADMIN_ADDRESS, ADDRESSES.EducEducator],
      contract: "contracts/core/EducCourse.sol:EducCourse",
    });

    // Verify EducConfig
    console.log("\nVerifying EducConfig...");
    await run("verify:verify", {
      address: ADDRESSES.EducConfig,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/config/EducConfig.sol:EducConfig",
    });

    // Verify EducPause
    console.log("\nVerifying EducPause...");
    await run("verify:verify", {
      address: ADDRESSES.EducPause,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/security/EducPause.sol:EducPause",
    });

    // Verify EducMultisig
    console.log("\nVerifying EducMultisig...");
    await run("verify:verify", {
      address: ADDRESSES.EducMultisig,
      constructorArguments: [MULTISIG_SIGNERS, MULTISIG_THRESHOLD, ADMIN_ADDRESS],
      contract: "contracts/governance/EducMultisig.sol:EducMultisig",
    });

    // Verify EducProposal
    console.log("\nVerifying EducProposal...");
    await run("verify:verify", {
      address: ADDRESSES.EducProposal,
      constructorArguments: [ADDRESSES.EducMultisig, ADMIN_ADDRESS],
      contract: "contracts/governance/EducProposal.sol:EducProposal",
    });

    // Verify EducLearning
    console.log("\nVerifying EducLearning...");
    await run("verify:verify", {
      address: ADDRESSES.EducLearning,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/EducLearning.sol:EducLearning",
    });

    console.log("\nVerification complete!");
  } catch (error) {
    console.error("Error during verification:", error);
  }
}

verify()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });