const { run } = require("hardhat");

async function main() {
  console.log("Verifying proxy implementation contract...");

  // Get the proxy address from command line or use a default one
  const proxyAddress = process.env.PROXY_ADDRESS;
  if (!proxyAddress) {
    console.error("PROXY_ADDRESS environment variable not set");
    process.exit(1);
  }

  try {
    // Get the implementation address from the proxy
    const { ethers, upgrades } = require("hardhat");
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    
    console.log(`Proxy address: ${proxyAddress}`);
    console.log(`Implementation address: ${implementationAddress}`);

    // Verify the implementation contract
    await run("verify:verify", {
      address: implementationAddress,
      // No constructor arguments for the implementation contract in the UUPS pattern
      constructorArguments: [],
      contract: "contracts/proxy/EducTokenUpgradeable.sol:EducTokenUpgradeable"
    });

    console.log("Implementation contract verified successfully!");
  } catch (error) {
    console.error("Error during verification:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });