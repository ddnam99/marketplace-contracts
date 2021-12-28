import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";

dotenvConfig({ path: resolve(__dirname, "../../.env") });
const multiSigAccount: string | undefined = process.env.MULTI_SIG_ACCOUNT;
if (!multiSigAccount) {
  throw new Error("Please set your MULTI_SIG_ACCOUNT in a .env file");
}

task("deploy:marketplace")
  .addFlag("verify", "Verify contracts at Etherscan")
  .setAction(async ({}, hre: HardhatRuntimeEnvironment) => {
    const ContractFactory = await hre.ethers.getContractFactory("Marketplace");

    const contract = await ContractFactory.deploy(multiSigAccount);
    await contract.deployed();
    console.log("Contract deployed to: ", contract.address);

    // We need to wait a little bit to verify the contract after deployment
    await delay(30000);
    await hre.run("verify:verify", {
      address: contract.address,
      constructorArguments: [multiSigAccount],
      libraries: {},
    });
  });

function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
