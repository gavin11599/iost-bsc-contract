// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

import "forge-std/Test.sol";
import "../../contracts/IOSToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IOSTokenTest is Test {
    IOSToken private token;

    function setUp() public {
        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(this), 21320000000000000000000000000);
        token = new IOSToken(address(this));
    }

    function test_receiverBalance_pass() public view {
        assertEq(token.cap(), 900e26);
        assertEq(token.balanceOf(address(this)), 21320000000000000000000000000);
    }

    function test_transfer_pass() public {
        vm.expectEmit();
        emit IERC20.Transfer(address(this), address(0x123), 100);
        token.transfer(address(0x123), 100);
        assertEq(token.balanceOf(address(this)), 21320000000000000000000000000 - 100);
        assertEq(token.balanceOf(address(0x123)), 100);
    }

    function test_transfer_fail() public {
        uint256 balance = token.balanceOf(address(this));
        vm.expectRevert();
        token.transfer(address(0x123), balance + 1);
    }

    function test_burn_pass() public {
        vm.expectEmit();
        emit IERC20.Transfer(address(this), address(0), 100);
        token.burn(100);
        assertEq(token.totalSupply(), 21320000000000000000000000000 - 100);
        assertEq(token.balanceOf(address(this)), 21320000000000000000000000000 - 100);
    }

}