//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;


import "forge-std/Test.sol";
import "../src/StakingApp.sol";
import "../src/StakingToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract StakingAppTest is Test {

    StakingApp stakingApp;
    StakingToken stakingToken;
    string name_ = "stakinToken";
    string symbol_ = "STK";
    address owner_ = vm.addr(1);
    address user_ = vm.addr(2);
    uint256  stakingPeriod = 1 days; 
    uint256  fixedStakingAmount = 10;
    uint256  rewardPerPeriod = 1 ether;

    function setUp() public {
        stakingToken = new StakingToken(name_, symbol_);
        stakingApp = new StakingApp(address(stakingToken), owner_, stakingPeriod, fixedStakingAmount, rewardPerPeriod);
    }

    function testStakingCorrectlyDeployed() external view {
        assert(address(stakingToken) != address(0));
        assert(address(stakingApp) != address(0));

    }

    function testChangeStakingPeriodRevertIfNotOwner() external {
        uint256 newStakingPeriod = 1;
        vm.startPrank(user_);
        vm.expectRevert();
        stakingApp.setStakingPeriod(newStakingPeriod);
        vm.stopPrank();
    }

    function testSetStakingPeriodCorretly() external {
        uint256 newStakingPeriod = 1;
        uint256 stakingPeriodBefore = stakingApp.stakingPeriod();
        vm.startPrank(owner_);
        stakingApp.setStakingPeriod(newStakingPeriod);
        //vm.warp(block.timestamp + stakingPeriod);
        assertEq(newStakingPeriod, stakingApp.stakingPeriod());
        vm.stopPrank();
    }

    function testContractReceiveEther() external {
        vm.startPrank(owner_);
        vm.deal(owner_, 100 ether);
        uint256 etherValue = 10 ether;
        uint256 balanceBefore = address(stakingApp).balance;
        (bool success, ) = address(stakingApp).call{value: etherValue}("");
        assert(success);
        uint256 balanceAfter = address(stakingApp).balance;
        assertEq(balanceBefore + etherValue, balanceAfter);
        vm.stopPrank();

    }

    function testDepositStakeRevertIfIncorrectAmount() external {
        uint256 incorrectAmount = fixedStakingAmount + 1;
        vm.startPrank(user_);
        vm.expectRevert("Incorrect staking amount");
        stakingApp.depositStake(incorrectAmount);
        vm.stopPrank();
    }

    
    function testDepositStakeCorrectly() external {
        uint256 correctAmount = fixedStakingAmount;
        vm.startPrank(user_);
        uint256 userBalanceBefore = stakingApp.stakingBalance(user_);
        uint256 timestampBefore = stakingApp.stakingTimestamp(user_);
        stakingToken.mint(100);
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        stakingApp.depositStake(correctAmount);
        uint256 balanceAfter = stakingApp.stakingBalance(user_);
        uint256 timestampAfter = stakingApp.stakingTimestamp(user_);
        assertEq(balanceAfter, userBalanceBefore + correctAmount);
        assertEq(timestampAfter, block.timestamp);
        vm.stopPrank();
    }

    function testDepositAlreadyStaked() external {
        uint256 correctAmount = fixedStakingAmount;
        vm.startPrank(user_);
        uint256 userBalanceBefore = stakingApp.stakingBalance(user_);
        uint256 timestampBefore = stakingApp.stakingTimestamp(user_);
        stakingToken.mint(100);
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        stakingApp.depositStake(correctAmount);
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        vm.expectRevert("Already staking");
        stakingApp.depositStake(correctAmount);
        vm.stopPrank();
    }

    function testWithdrawNoStake() external {
        vm.startPrank(user_);
        vm.expectRevert("No stake to withdraw");
        stakingApp.withdrawStake();
        vm.stopPrank();
    }

        function testWithdrawStakeCorrectly() external {
        vm.startPrank(user_);
        uint256 correctAmount = fixedStakingAmount;
        stakingToken.mint(100);
        uint256 userBalanceBefore = IERC20(address(stakingToken)).balanceOf(address(user_));
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        stakingApp.depositStake(correctAmount);
        stakingApp.withdrawStake();
        uint256 userBalanceAfter = IERC20(address(stakingToken)).balanceOf(address(user_));
        assertEq(userBalanceBefore, userBalanceAfter);
        vm.stopPrank();
    }

    function testClaimRewardsNoStake() external {
        vm.startPrank(user_);
        vm.expectRevert("No stake to claim reward");
        stakingApp.claimRewards();
        vm.stopPrank();
    }

    function testClaimRewardsNotTimeElapsed() external {
        uint256 correctAmount = fixedStakingAmount;
        vm.startPrank(user_);
        uint256 userBalanceBefore = stakingApp.stakingBalance(user_);
        uint256 timestampBefore = stakingApp.stakingTimestamp(user_);
        stakingToken.mint(100);
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        stakingApp.depositStake(correctAmount);
        uint256 balanceAfter = stakingApp.stakingBalance(user_);
        uint256 timestampAfter = stakingApp.stakingTimestamp(user_);
        assertEq(balanceAfter, userBalanceBefore + correctAmount);
        assertEq(timestampAfter, block.timestamp);
        vm.expectRevert();
        stakingApp.claimRewards();
        vm.stopPrank();
    }

    function testClaimRewardsErrorNoEther() external {
        vm.startPrank(user_);
        uint256 correctAmount = fixedStakingAmount;
        stakingToken.mint(100);
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        stakingApp.depositStake(correctAmount);
        vm.warp(block.timestamp + stakingPeriod);
        vm.expectRevert("Reward transfer failed");
        stakingApp.claimRewards();
        vm.stopPrank();
    }

    
    function testClaimRewardsCorrectly() external {
        vm.startPrank(user_);
        uint256 correctAmount = fixedStakingAmount;
        stakingToken.mint(100);
        IERC20(address(stakingToken)).approve(address(stakingApp), correctAmount);
        stakingApp.depositStake(correctAmount);
        vm.stopPrank();

        vm.startPrank(owner_);
        vm.deal(owner_, 100 ether);
        (bool success, ) = address(stakingApp).call{value: 100 ether}("");
        assert(success);
        vm.stopPrank();

        vm.startPrank(user_);
        vm.warp(block.timestamp + stakingPeriod);
        uint256 etherBefore = address(user_).balance;
        stakingApp.claimRewards();
        uint256 etherAfter = address(user_).balance;
        uint256 timestampAfter = stakingApp.stakingTimestamp(user_);
        assertEq(timestampAfter, block.timestamp);
        assertEq(etherAfter, etherBefore + rewardPerPeriod);

        vm.stopPrank();


    
    }

}