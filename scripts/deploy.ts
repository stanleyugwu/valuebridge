// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { BigNumberish } from "ethers";
import hre from "hardhat";

async function main() {
  const utils = hre.ethers.utils;

  const constructorArgs: [string, BigNumberish, BigNumberish] = [
    "Devvie", // ownerName
    utils.parseEther("2"), // minimum transfer amount
    utils.parseEther("6"), // minimum withdrawal amount
  ];

  const valueBridge = await (
    await hre.ethers.getContractFactory("ValueBridge")
  ).deploy(...constructorArgs);
  await valueBridge.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
