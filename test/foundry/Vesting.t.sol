// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;
import "../../contracts/IOSToken.sol";
import "../../contracts/Vesting.sol";
import "../../contracts/test/VestingHarness.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";

contract VestingTest is Test {
    IOSToken private iost;
    VestingHarness private vesting;

    function setUp() public {
        iost = new IOSToken(address(this));
        vesting = new VestingHarness(IERC20(address(iost)));
    }

    function test_createVestingSchedule() public {
        iost.transfer(address(vesting), 21320000000e18);
        // Before schedule was created, all coins could be withdrawn
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18);

        uint256 timestamp = 1734404291;

        bytes32 vestingScheduleId = vesting.createVestingSchedule(
            address(this),
            timestamp,
            0,
            100,
            1,
            false,
            100
        );

        // test getVestingSchedulesCount
        assertEq(vesting.getVestingSchedulesCount(), 1);
        // test holdersVestingCount
        assertEq(vesting.holdersVestingCount(address(this)), 1);

        (address beneficiary, uint256 cliff, uint256 start, uint256 duration,
            uint256 slicePeriodSeconds, bool revocable, uint256 amountTotal,
            uint256 released, bool revoked) = vesting.vestingSchedules(vestingScheduleId);

        assertEq(beneficiary, address(this));
        assertEq(cliff, timestamp);
        assertEq(start, timestamp);
        assertEq(duration, 100);
        assertEq(slicePeriodSeconds, 1);
        assertEq(revocable, false);
        assertEq(amountTotal, 100);
        assertEq(released, 0);
        assertEq(revoked, false);

        vm.warp(timestamp - 1);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 0);

        vm.warp(timestamp + 1);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 1);

        vm.warp(timestamp + 20);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 20);

        vm.warp(timestamp + 100);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 100);

        vm.warp(timestamp + 101);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 100);

        vm.warp(timestamp + 200);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 100);

        vm.warp(timestamp + 20);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 20);
        assertEq(iost.balanceOf(address(this)), 0);

        // test vestingSchedulesTotalAmount
        assertEq(vesting.vestingSchedulesTotalAmount(), 100);

        vesting.release(vestingScheduleId, 5);
        assertEq(vesting.vestingSchedulesTotalAmount(), 95);

        assertEq(iost.balanceOf(address(this)), 5);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 15);

        // error
        vm.expectRevert();
        vesting.release(vestingScheduleId, 20);
        assertEq(iost.balanceOf(address(this)), 5);
        assertEq(vesting.vestingSchedulesTotalAmount(), 95);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 15);

        vesting.release(vestingScheduleId, 5);
        assertEq(iost.balanceOf(address(this)), 10);
        assertEq(vesting.vestingSchedulesTotalAmount(), 90);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId), 10);

    }

    function test_createVestingScheduleMulti() public {
        iost.transfer(address(vesting), 21320000000e18);
        // Before schedule was created, all coins could be withdrawn
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18);

        address addressA = vm.addr(1);
        address addressB = vm.addr(2);
        address addressC = vm.addr(3);
        // time 2024-12-25 08:00:00
        uint256 startTimestampA = 1735084800;
        // time startTimestampA + 30 days
        uint256 startTimestampB = startTimestampA + 30 * 24 * 60 * 60;
        // time startTimestampA + 60 days
        uint256 startTimestampC = startTimestampA + 30 * 24 * 60 * 60 * 2;

        uint256 blockTimestamp = 1735000000;

        vm.warp(blockTimestamp);
        // payPinNode_1, 290,485,000 tokens/month，12 months
        // 112.06983025 tokens/second
        bytes32 vestingScheduleId1 = vesting.createVestingSchedule(
            address(addressA),
            startTimestampA,
            0,
            31104000,
            1,
            false,
            3485820000e18
        );

        // payPinNode_3, 213,200,000 tokens/month，12 months
        bytes32 vestingScheduleId2 = vesting.createVestingSchedule(
            address(addressB),
            startTimestampB,
            0,
            31104000,
            1,
            false,
            2558400000e18
        );

        // developerGrant,29,611,111 tokens/month，36 months
        bytes32 vestingScheduleId3 = vesting.createVestingSchedule(
            address(addressC),
            startTimestampC,
            0,
            93312000,
            2592000,
            false,
            1065999996e18
        );

        // test getVestingSchedulesCount
        assertEq(vesting.getVestingSchedulesCount(), 3);
        // test holdersVestingCount
        assertEq(vesting.holdersVestingCount(address(this)), 0);
        assertEq(vesting.holdersVestingCount(address(addressA)), 1);
        assertEq(vesting.holdersVestingCount(address(addressB)), 1);
        assertEq(vesting.holdersVestingCount(address(addressC)), 1);

        (address beneficiary, uint256 cliff, uint256 start, uint256 duration,
            uint256 slicePeriodSeconds, bool revocable, uint256 amountTotal,
            uint256 released, bool revoked) = vesting.vestingSchedules(vestingScheduleId1);

        assertEq(beneficiary, address(addressA));
        assertEq(cliff, startTimestampA);
        assertEq(start, startTimestampA);
        assertEq(duration, 31104000);
        assertEq(slicePeriodSeconds, 1);
        assertEq(revocable, false);
        assertEq(amountTotal, 3485820000e18);
        assertEq(released, 0);
        assertEq(revoked, false);

        (beneficiary, cliff, start, duration,
            slicePeriodSeconds, revocable, amountTotal,
            released, revoked) = vesting.vestingSchedules(vestingScheduleId2);

        assertEq(beneficiary, address(addressB));
        assertEq(cliff, startTimestampB);
        assertEq(start, startTimestampB);
        assertEq(duration, 31104000);
        assertEq(slicePeriodSeconds, 1);
        assertEq(revocable, false);
        assertEq(amountTotal, 2558400000e18);
        assertEq(released, 0);
        assertEq(revoked, false);

        (beneficiary, cliff, start, duration,
            slicePeriodSeconds, revocable, amountTotal,
            released, revoked) = vesting.vestingSchedules(vestingScheduleId3);

        assertEq(beneficiary, address(addressC));
        assertEq(cliff, startTimestampC);
        assertEq(start, startTimestampC);
        assertEq(duration, 93312000);
        assertEq(slicePeriodSeconds, 2592000);
        assertEq(revocable, false);
        assertEq(amountTotal, 1065999996e18);
        assertEq(released, 0);
        assertEq(revoked, false);

        // test address(this)
        vm.warp(blockTimestamp);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 0);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 0);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId3), 0);
        vm.warp(blockTimestamp + 1000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 0);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 0);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId3), 0);

        // test schedule 1
        vm.warp(startTimestampA + 1);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 112069830246913580246);
        // add 1 month
        vm.warp(startTimestampA + 30 * 24 * 60 * 60);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 290485000000000000000000000);

        // test schedule 1 and 2
        vm.warp(startTimestampB + 1);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 82253086419753086419);
        // add 1 month
        vm.warp(startTimestampB + 30 * 24 * 60 * 60);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 213200000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 580970000000000000000000000);

        // add 12 months
        vm.warp(startTimestampB + 30 * 24 * 60 * 60 * 12);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 2558400000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 3485820000000000000000000000);

        // add 12 months
        vm.warp(startTimestampB + 30 * 24 * 60 * 60 * 12);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 2558400000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 3485820000000000000000000000);

        // test schedule 1 and 2 and 3
        vm.warp(startTimestampC);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 580970000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 213200000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId3), 0);

        // startTimestampC add 36 months
        vm.warp(startTimestampC + 30 * 24 * 60 * 60 * 12 * 36 + 1);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 3485820000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 2558400000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId3), 1065999996000000000000000000);

        // test release for schedule1
        assertEq(vesting.vestingSchedulesTotalAmount(), 3485820000e18 + 2558400000e18 + 1065999996e18);
        assertEq(iost.balanceOf(address(addressA)), 0);
        vm.expectRevert();
        vesting.release(vestingScheduleId1, 3485820000000000000000000000 + 1);
        vesting.release(vestingScheduleId1, 100e18);
        assertEq(iost.balanceOf(address(addressA)), 100e18);
        assertEq(vesting.vestingSchedulesTotalAmount(), 3485820000e18 + 2558400000e18 + 1065999996e18 - 100e18);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 3485820000000000000000000000 - 100e18);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 2558400000000000000000000000);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId3), 1065999996000000000000000000);

        // test release for schedule2
        assertEq(vesting.vestingSchedulesTotalAmount(), 3485820000e18 + 2558400000e18 + 1065999996e18 - 100e18);
        assertEq(iost.balanceOf(address(addressB)), 0);
        vm.expectRevert();
        vesting.release(vestingScheduleId2, 2558400000000000000000000000 + 1);
        vesting.release(vestingScheduleId2, 200e18);
        assertEq(iost.balanceOf(address(addressB)), 200e18);
        assertEq(iost.balanceOf(address(addressA)), 100e18);
        assertEq(vesting.vestingSchedulesTotalAmount(), 3485820000e18 + 2558400000e18 + 1065999996e18 - 100e18 - 200e18);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId1), 3485820000000000000000000000 - 100e18);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId2), 2558400000000000000000000000 - 200e18);
        assertEq(vesting.computeReleasableAmount(vestingScheduleId3), 1065999996000000000000000000);

    }

    function test_Revoke_noRelease() public {
        iost.transfer(address(vesting), 21320000000e18);
        // Before schedule was created, all coins could be withdrawn
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18);

        uint256 timestamp = 1734404291;
        bytes32 vestingScheduleId = vesting.createVestingSchedule(
            address(this),
            timestamp,
            0,
            100,
            1,
            true,
            100e18
        );
        // test There is no release credit
        address addressA = vm.addr(1);
        vm.startPrank(addressA);
        vm.expectRevert();
        vesting.revoke(vestingScheduleId);
        vm.stopPrank();

        vm.warp(timestamp-1);
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18-100e18);
        assertEq(vesting.vestingSchedulesTotalAmount(), 100e18);
        assertEq(iost.balanceOf(address(this)), 0);
        vesting.revoke(vestingScheduleId);
        assertEq(iost.balanceOf(address(this)), 0);
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18);
        assertEq(vesting.vestingSchedulesTotalAmount(), 0);
    }

    function test_Revoke_Release() public {
        iost.transfer(address(vesting), 21320000000e18);
        // Before schedule was created, all coins could be withdrawn
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18);

        uint256 timestamp = 1734404291;
        bytes32 vestingScheduleId = vesting.createVestingSchedule(
            address(this),
            timestamp,
            0,
            100,
            1,
            true,
            100e18
        );

        vm.warp(timestamp+10);
        // test There is no release credit
        address addressA = vm.addr(1);
        vm.startPrank(addressA);
        vm.expectRevert();
        vesting.revoke(vestingScheduleId);
        vm.stopPrank();

        assertEq(vesting.getWithdrawableAmount(), 21320000000e18-100e18);
        assertEq(vesting.vestingSchedulesTotalAmount(), 100e18);
        assertEq(iost.balanceOf(address(this)), 0);
        vesting.revoke(vestingScheduleId);
        assertEq(iost.balanceOf(address(this)), 10e18);
        assertEq(vesting.getWithdrawableAmount(), 21320000000e18-10e18);
        assertEq(vesting.vestingSchedulesTotalAmount(), 0);
    }

    function test_owner() public {
        assertEq(vesting.owner(), address(this));
        address addressA = vm.addr(1);
        assertNotEq(vesting.owner(), address(addressA));

        vm.startPrank(addressA);
        vm.expectRevert();
        vesting.transferOwnership(addressA);
        vm.stopPrank();

        vesting.transferOwnership(addressA);
        assertEq(vesting.owner(), address(addressA));

        vm.startPrank(addressA);
        vesting.transferOwnership(address(this));
        vm.stopPrank();

        assertEq(vesting.owner(), address(this));
        vesting.renounceOwnership();
        assertEq(vesting.owner(), address(0));
    }

    function test_computeReleasableAmount() public {
        vm.warp(1734404292);
        uint256 amount = vesting.computeReleasableAmount(Vesting.VestingSchedule({
            beneficiary: address(this),
            cliff: 1734404291,
            start: 1734404291,
            duration: 100,
            slicePeriodSeconds: 1,
            revocable: true,
            amountTotal: 100,
            released: 0,
            revoked: false
        }));
        assertEq(amount, 1);
    }
}