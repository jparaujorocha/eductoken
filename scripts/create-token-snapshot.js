const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Creating token holder snapshot...");

  // Get the existing token address from command line or environment
  const existingTokenAddress = process.env.EXISTING_TOKEN_ADDRESS;
  if (!existingTokenAddress) {
    console.error("EXISTING_TOKEN_ADDRESS environment variable not set");
    process.exit(1);
  }

  console.log(`Token address: ${existingTokenAddress}`);

  // Load the existing token contract
  const existingToken = await ethers.getContractAt("EducToken", existingTokenAddress);
  
  try {
    // Extract token metadata
    const name = await existingToken.name();
    const symbol = await existingToken.symbol();
    const decimals = await existingToken.decimals();
    const totalSupply = await existingToken.totalSupply();
    
    console.log(`Token Name: ${name}`);
    console.log(`Token Symbol: ${symbol}`);
    console.log(`Decimals: ${decimals}`);
    console.log(`Total Supply: ${ethers.utils.formatEther(totalSupply)}`);
    
    // Get all Transfer events to identify token holders
    console.log("Fetching Transfer events to identify all token holders...");
    
    const provider = ethers.provider;
    const currentBlock = await provider.getBlockNumber();
    
    // Define the batch size and initialize the variables
    const batchSize = 10000;
    let fromBlock = 0;
    let toBlock = Math.min(fromBlock + batchSize, currentBlock);
    
    // Create a set to store unique addresses
    const addressSet = new Set();
    
    // Process events in batches to avoid RPC limitations
    while (fromBlock <= currentBlock) {
      console.log(`Processing blocks ${fromBlock} to ${toBlock}...`);
      
      const filter = existingToken.filters.Transfer();
      const events = await existingToken.queryFilter(filter, fromBlock, toBlock);
      
      for (const event of events) {
        addressSet.add(event.args.from);
        addressSet.add(event.args.to);
      }
      
      // Update block range for next batch
      fromBlock = toBlock + 1;
      toBlock = Math.min(fromBlock + batchSize, currentBlock);
    }
    
    // Remove the zero address from the set
    addressSet.delete(ethers.constants.AddressZero);
    
    console.log(`Found ${addressSet.size} unique addresses`);
    
    // Now get balance for each address
    console.log("Fetching balances for all addresses...");
    
    const holders = [];
    let addressArray = Array.from(addressSet);
    let totalProcessed = 0;
    
    // Process balances in smaller batches to avoid rate limiting
    const balanceBatchSize = 100;
    
    for (let i = 0; i < addressArray.length; i += balanceBatchSize) {
      const batch = addressArray.slice(i, i + balanceBatchSize);
      const batchPromises = batch.map(async (address) => {
        try {
          const balance = await existingToken.balanceOf(address);
          if (balance.gt(0)) {
            return {
              address,
              balance: balance.toString(),
              formattedBalance: ethers.utils.formatEther(balance)
            };
          }
          return null;
        } catch (error) {
          console.error(`Error fetching balance for ${address}:`, error);
          return null;
        }
      });
      
      const batchResults = await Promise.all(batchPromises);
      const validResults = batchResults.filter(result => result !== null);
      holders.push(...validResults);
      
      totalProcessed += batch.length;
      console.log(`Processed ${totalProcessed}/${addressArray.length} addresses (${Math.round(totalProcessed/addressArray.length*100)}%)`);
    }
    
    console.log(`Found ${holders.length} addresses with positive balances`);
    
    // Sort holders by balance (descending)
    holders.sort((a, b) => {
      const balanceA = ethers.BigNumber.from(a.balance);
      const balanceB = ethers.BigNumber.from(b.balance);
      return balanceB.sub(balanceA);
    });
    
    // Create snapshot object
    const snapshot = {
      token: {
        address: existingTokenAddress,
        name,
        symbol,
        decimals: decimals.toString(),
        totalSupply: totalSupply.toString(),
        formattedTotalSupply: ethers.utils.formatEther(totalSupply)
      },
      snapshotBlock: currentBlock,
      timestamp: Math.floor(Date.now() / 1000),
      holders
    };
    
    // Create snapshot directory if it doesn't exist
    const snapshotDir = path.join(__dirname, '../snapshots');
    if (!fs.existsSync(snapshotDir)) {
      fs.mkdirSync(snapshotDir);
    }
    
    // Save snapshot to file
    const filename = path.join(snapshotDir, `snapshot_${currentBlock}.json`);
    fs.writeFileSync(filename, JSON.stringify(snapshot, null, 2));
    
    console.log(`Snapshot created successfully at ${filename}`);
    
    // Create a CSV file for easier viewing
    const csvFilename = path.join(snapshotDir, `snapshot_${currentBlock}.csv`);
    const csvContent = [
      'Address,Balance,FormattedBalance',
      ...holders.map(h => `${h.address},${h.balance},${h.formattedBalance}`)
    ].join('\n');
    
    fs.writeFileSync(csvFilename, csvContent);
    console.log(`CSV snapshot created at ${csvFilename}`);
    
    // Verify total sum of balances matches total supply
    const totalBalances = holders.reduce(
      (sum, holder) => sum.add(ethers.BigNumber.from(holder.balance)),
      ethers.BigNumber.from(0)
    );
    
    console.log(`Total from balances: ${ethers.utils.formatEther(totalBalances)}`);
    console.log(`Total supply: ${ethers.utils.formatEther(totalSupply)}`);
    
    if (totalBalances.eq(totalSupply)) {
      console.log("✅ Total balances match total supply");
    } else {
      console.log("⚠️ Total balances do not match total supply");
      console.log(`Difference: ${ethers.utils.formatEther(totalSupply.sub(totalBalances))}`);
    }
    
  } catch (error) {
    console.error("Error creating snapshot:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });