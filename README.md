# IOSToken Contract

## How to deploy

1. Deploy IOSToken contract
    ```shell
    npx hardhat ignition deploy ignition/modules/IOSToken.ts --network hardhat
    ```
2. Deploy vesting contract
    ```shell
    npx hardhat ignition deploy ignition/modules/Vesting.ts --network hardhat
    ```
3. Transfer the IOSToken to the vesting contract before continuing
4. Create vesting schedules
   ```shell
   npx hardhat ignition deploy ignition/modules/IOSTokenVesting.ts --network hardhat
    ```
5. The corresponding vesting schedules id will be found in ignition/deployments/chain-xxx/journal.jsonl

## How to verify
 ```shell
npx hardhat ignition verify chain-97
 ```