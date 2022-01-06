import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";

dotenvConfig({ path: resolve(__dirname, "../../.env") });
const multiSigAccount: string | undefined = process.env.MULTI_SIG_ACCOUNT;
if (!multiSigAccount) {
  throw new Error("Please set your MULTI_SIG_ACCOUNT in a .env file");
}

task("deploy:exchange-proxy")
  .addFlag("verify", "Verify contracts at Etherscan")
  .setAction(async ({}, hre: HardhatRuntimeEnvironment) => {
    const ContractFactory = await hre.ethers.getContractFactory("ExchangeProxy");

    const contractProsy = await hre.upgrades.deployProxy(ContractFactory, [multiSigAccount]);
    await contractProsy.deployed();
    console.log("Contract proxy deployed to:", contractProsy.address);
  });

function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
