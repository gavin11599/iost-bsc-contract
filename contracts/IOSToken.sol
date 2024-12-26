// SPDX-License-Identifier: MIT
pragma solidity =0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract IOSToken is ERC20Burnable, ERC20Capped, Ownable {
    constructor(address _receiver) ERC20("IOSToken", "IOST") ERC20Capped(90000000000e18) Ownable(msg.sender){
        require(_receiver != address(0), "Invalid receiver address");
        _mint(_receiver, 21320000000e18);
    }

    function mint(address _account, uint256 _amount) external onlyOwner {
        _mint(_account, _amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
