import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("deploy:nft1155")
  .addFlag("verify", "Verify contracts at Etherscan")
  .setAction(async ({}, hre: HardhatRuntimeEnvironment) => {
    const ContractFactory = await hre.ethers.getContractFactory("NFT1155");

    const contract = await ContractFactory.deploy("NFT1155 TEST", "TEST1155");
    await contract.deployed();
    console.log("Contract deployed to: ", contract.address);

    // We need to wait a little bit to verify the contract after deployment
    await delay(30000);
    await hre.run("verify:verify", {
      address: contract.address,
      constructorArguments: ["NFT1155 TEST", "TEST1155"],
      libraries: {},
    });
  });

function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
