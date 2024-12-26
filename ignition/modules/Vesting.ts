import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { getDeployedAddress } from "./utils";

const VestingModule = buildModule("Vesting", (m) => {
  // vesting contract owner
  const owner = m.getAccount(0);
  // get the iost address
  const iost = getDeployedAddress("IOSToken#IOSToken");
  // deploy vesting with iost token
  const vesting = m.contract("Vesting", [iost], { from: owner });
  return { vesting };
});

export default VestingModule;
