import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const IOSTokenModule = buildModule("IOSToken", (m) => {
  const owner = m.getAccount(0);
  let receiver = m.getParameter("receiver", owner);
  const iost = m.contract("IOSToken", [receiver], { from: owner });
  return { iost };
});

export default IOSTokenModule;
