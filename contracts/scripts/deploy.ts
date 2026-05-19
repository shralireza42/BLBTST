import "dotenv/config";
import { network } from "hardhat";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalBigInt(name: string, fallback: bigint): bigint {
  const value = process.env[name];
  return value ? BigInt(value) : fallback;
}

async function main() {
  const { ethers } = await network.connect("bsc");
  const [deployer] = await ethers.getSigners();

  const oracle = await ethers.deployContract("BlobbyUsdOracle", [
    deployer.address,
    required("BLOBBIE_TOKEN_ADDRESS"),
    required("WBNB_ADDRESS"),
    required("PANCAKE_PAIR_ADDRESS"),
    required("BNB_USD_FEED_ADDRESS"),
    60n * 60n,
    optionalBigInt("MIN_WBNB_RESERVE", 0n),
    BigInt(process.env.ORACLE_PREMIUM_BPS || "0")
  ]);
  await oracle.waitForDeployment();

  const dailyDraw = await ethers.deployContract("DailyDraw", [
    deployer.address,
    required("BLOBBIE_TOKEN_ADDRESS"),
    await oracle.getAddress(),
    {
      coordinator: required("VRF_COORDINATOR"),
      keyHash: required("VRF_KEY_HASH"),
      subscriptionId: BigInt(required("VRF_SUBSCRIPTION_ID")),
      requestConfirmations: Number(process.env.VRF_REQUEST_CONFIRMATIONS || "3"),
      callbackGasLimit: Number(process.env.VRF_CALLBACK_GAS_LIMIT || "500000"),
      extraArgs: process.env.VRF_EXTRA_ARGS || "0x"
    },
    300,
    24 * 60 * 60,
    Number(process.env.JACKPOT_BPS || "1000"),
    optionalBigInt("JACKPOT_TRIGGER_AMOUNT", 0n)
  ]);
  await dailyDraw.waitForDeployment();

  console.log("BlobbyUsdOracle:", await oracle.getAddress());
  console.log("DailyDraw:", await dailyDraw.getAddress());
  console.log("Admin:", deployer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
