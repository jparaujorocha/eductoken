const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Preparing to upgrade EducTokenUpgradeable...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);

  // Get the proxy address from command line or use a default one
  const proxyAddress = process.env.PROXY_ADDRESS;
  if (!proxyAddress) {
    console.error("PROXY_ADDRESS environment variable not set");
    process.exit(1);
  }

  console.log(`Proxy address: ${proxyAddress}`);
  console.log(`Current implementation address: ${await upgrades.erc1967.getImplementationAddress(proxyAddress)}`);

  // Deploy the upgraded implementation and update the proxy
  console.log("Deploying new implementation...");
  const EducTokenUpgradeableV2 = await ethers.getContractFactory("EducTokenUpgradeable");
  
  console.log("Upgrading proxy...");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, EducTokenUpgradeableV2);
  await upgraded.deployTransaction.wait();

  console.log("Upgrade complete!");
  console.log(`New implementation address: ${await upgrades.erc1967.getImplementationAddress(proxyAddress)}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });