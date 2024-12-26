import hre from "hardhat";
import fs from "fs";

export function getDeployedAddress(key: string): string {
  const chainId = hre.network.config.chainId;
  if (!chainId) {
    throw new Error("Chain ID not found in network configuration.");
  }

  const filePath = `ignition/deployments/chain-${chainId}/deployed_addresses.json`;

  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }

  const fileContent = fs.readFileSync(filePath, "utf-8");
  const jsonData = JSON.parse(fileContent);

  const address = jsonData[key];
  if (!address) {
    throw new Error(`"${key}" not found in JSON file: ${filePath}`);
  }

  return address;
}
