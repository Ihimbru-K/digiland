const hre = require("hardhat");

async function main() {
  console.log("Deploying LandVaultRegistry to Polygon Amoy...");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(balance), "MATIC");

  const LandVaultRegistry = await hre.ethers.getContractFactory("LandVaultRegistry");
  const registry = await LandVaultRegistry.deploy();
  await registry.waitForDeployment();

  const address = await registry.getAddress();
  console.log("\n✅ LandVaultRegistry deployed to:", address);
  console.log("🔗 View on explorer: https://amoy.polygonscan.com/address/" + address);
  console.log("\n⚠️  SAVE THIS ADDRESS — add it to your backend .env as CONTRACT_ADDRESS");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
