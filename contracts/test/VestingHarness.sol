// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

import "../Vesting.sol";

contract VestingHarness is Vesting {

    constructor(IERC20 _token) Vesting(_token){}

    function computeReleasableAmount(VestingSchedule memory vestingSchedule) public view returns (uint256){
        return _computeReleasableAmount(vestingSchedule);
    }
}