const { run } = require("hardhat");

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

// Initial signers for multisig
const MULTISIG_SIGNERS = [ADMIN_ADDRESS];
const MULTISIG_THRESHOLD = 1;

async function verify() {
  console.log("Starting contract verification...");

  try {
    // Verification functions remain mostly the same, just ensure you use the correct contract paths
    await run("verify:verify", {
      address: ADDRESSES.EducToken,
      constructorArguments: [ADMIN_ADDRESS],
      contract: "contracts/core/EducToken.sol:EducToken",
    });

    // (Repeat for other contracts...)

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