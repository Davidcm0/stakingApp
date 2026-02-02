//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;
import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract StakingTokenTest is Test {

    StakingToken stakingToken;
    string name_ = "stakinToken";
    string symbol_ = "STK";
    address user = vm.addr(1);

    function setUp() public {
        stakingToken = new StakingToken(name_, symbol_);
    }

    function testMint() public {
        
        uint256 amount = 1 ether;
        stakingToken.mint(amount);
        assertEq(amount, stakingToken.balanceOf(address(this)));
        vm.startPrank(user);
        //token balance previous (ya tiene 1 ether)
        uint256 initBalance = IERC20(address(stakingToken)).balanceOf(user);
        stakingToken.mint(amount);
        uint256 finalBalance = IERC20(address(stakingToken)).balanceOf(user);
        assertEq(amount, finalBalance - initBalance);
        vm.stopPrank();

    }

}