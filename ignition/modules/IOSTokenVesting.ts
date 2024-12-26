import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import * as fs from "fs";
import hre from "hardhat";
import {getDeployedAddress} from "./utils";

// Transfer the iost to vesting contract before deployment
const IOSTokenVesting = buildModule("IOSTokenVesting", (m) => {
  const rawData = fs.readFileSync("ignition/schedules.json", "utf-8");
  const schedules = JSON.parse(rawData);
  const vesting = m.contractAt("Vesting",getDeployedAddress("Vesting#Vesting"));

  for (const key in schedules) {
    if (schedules.hasOwnProperty(key)) {
      const entry = schedules[key];
      const future = m.call(
        vesting,
        "createVestingSchedule",
        [
          entry.beneficiary,
          entry.start,
          0n, // cliff is always 0
          entry.duration,
          entry.slice,
          true,
          processAmount(entry.amount),
        ],
        { id: key }
      );

      const vestingScheduleId = m.readEventArgument(
        future,
        "VestingScheduleCreated",
        "vestingScheduleId",
        { id: key + "_scheduleId" }
      );
    }
  }
  return {};
});

function processAmount(cfgAmount: any): bigint {
  let amount = BigInt(cfgAmount);
  const result = amount * BigInt(10 ** 18);
  return result;
}

export default IOSTokenVesting;
