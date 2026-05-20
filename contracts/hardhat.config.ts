import dotenv from "dotenv";
import hardhatEthers from "@nomicfoundation/hardhat-ethers";
import hardhatNetworkHelpers from "@nomicfoundation/hardhat-network-helpers";
import { defineConfig } from "hardhat/config";

dotenv.config();

const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;

export default defineConfig({
  plugins: [hardhatEthers, hardhatNetworkHelpers],
  solidity: {
    version: "0.8.24",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1"
    },
    bsc: {
      type: "http",
      chainType: "l1",
      url: process.env.BSC_RPC_URL || "https://bsc-dataseed.binance.org/",
      accounts: deployerPrivateKey ? [deployerPrivateKey] : []
    }
  }
});
