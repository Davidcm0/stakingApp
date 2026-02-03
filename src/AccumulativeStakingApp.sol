//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title AccumulativeStakingApp
 * @author David
 * @notice Smart contract to stake ERC20 tokens and earn ETH rewards in an accumulative manner with penalties for early withdrawal
 * @dev Uses reward accumulation per token staked to efficiently calculate rewards
 */

contract AccumulativeStakingApp is Ownable {

    uint256 constant PRECISION = 1e18;
    
    address public stakingToken;
    uint256 public accRewardPerToken; // accumulated reward per token staked, scaled by 1e18
    uint256 public lastUpdateTime; // last time the accRewardPerToken was updated
    uint256 public totalStaked; // total tokens staked in the contract
    uint256 public rewardRate; //fixed reward per staking period, scaled by 1e18
    uint256 public lockPeriod;
    uint256 public penaltyRate; //penalty rate for early withdrawal, scaled by 1e4 (e.g., 2000 = 20.00%)
    struct StakerInfo {
        uint256 stakingBalance;
        uint256 rewardDebt; // rewards already accounted for the staker
        uint256 pendingRewards; // rewards pending to be claimed
        uint256 unlockTime;//To prevent early withdrawals
    }
    mapping(address => StakerInfo) public stakers;

    event SetUnlockTime(uint256 newUnlockTime, address indexed owner);
    event Staked(uint256 amountStaked, address indexed staker);
    event Withdraw(uint256 amountWithdrawn, uint256 penalty, address indexed staker);
    event ClaimReward(uint256 amountClaimed, address indexed staker);
    event EtherReceived(address indexed sender, uint256 amount);
    event SetPenaltyRate(uint256 newPenaltyRate, address indexed owner);

    constructor(address stakingToken_, address owner_, uint256 rewardRate_, uint256 lockPeriod_) Ownable(owner_) {
        stakingToken = stakingToken_;
        rewardRate = rewardRate_;
        lastUpdateTime = block.timestamp;
        totalStaked = 0;
        lockPeriod = lockPeriod_;
    }

    function setUnlockTime(uint256 lockPeriod_) external onlyOwner() {
        lockPeriod = lockPeriod_;
        emit SetUnlockTime(lockPeriod_, msg.sender);
    }

    function setPenaltyRate(uint256 penaltyRate_) external onlyOwner() {
        require(penaltyRate_ <= 10000, "Penalty rate must be less than or equal to 10000");
        penaltyRate = penaltyRate_;
        emit SetPenaltyRate(penaltyRate_, msg.sender);
    }
    
    //@notice Deposit tokens to stake and start earning rewards
    function depositStake(uint256 tokenAmountToDeposit_) external {
        StakerInfo storage staker = stakers[msg.sender];
        updateRewardsData();

        if (staker.stakingBalance > 0) {
            uint256 pending = (staker.stakingBalance * accRewardPerToken) / PRECISION - staker.rewardDebt;
            staker.pendingRewards += pending;
        } 

        bool success = IERC20(address(stakingToken)).transferFrom(msg.sender, address(this), tokenAmountToDeposit_);
        require(success, "Token transfer failed");

        staker.stakingBalance += tokenAmountToDeposit_;
        totalStaked += tokenAmountToDeposit_;

        staker.unlockTime = block.timestamp + lockPeriod;

        staker.rewardDebt = (staker.stakingBalance * accRewardPerToken) / PRECISION;

        emit Staked(tokenAmountToDeposit_, msg.sender);
    }

    //@notice Withdraw staked tokens, with penalty if withdrawn before unlock time
    function withdrawStake(uint256 amountToWithdraw) public {
        //Checks
        StakerInfo storage staker = stakers[msg.sender];
        uint256 penalty = 0;
        updateRewardsData();
        require(amountToWithdraw <= staker.stakingBalance, "Not enough staked balance");

        if (block.timestamp < staker.unlockTime) {
            penalty = (amountToWithdraw * penaltyRate) / 10000; //20.00% penalty for early withdrawal
        }

        uint256 toUser = amountToWithdraw - penalty;

        //Effects
        uint256 pending = (staker.stakingBalance * accRewardPerToken) / PRECISION - staker.rewardDebt;
        staker.pendingRewards += pending;

        staker.stakingBalance -= amountToWithdraw;
        totalStaked -= amountToWithdraw;

        //Interactions
        if (penalty > 0 && totalStaked > 0) {
            accRewardPerToken += (penalty * PRECISION) / totalStaked; //redistribute the penalty among stakers
        }
        bool success = IERC20(address(stakingToken)).transfer(msg.sender, toUser);
        require(success, "Token transfer failed");
        staker.rewardDebt = (staker.stakingBalance * accRewardPerToken) / PRECISION;
        emit Withdraw(amountToWithdraw, penalty, msg.sender);
    }

    //@notice Claim accumulated rewards
    function claimRewards() public {
        //Check the balance staked
        StakerInfo storage staker = stakers[msg.sender];
        updateRewardsData();
        uint256 pending = (staker.stakingBalance * accRewardPerToken) / PRECISION - staker.rewardDebt;
        uint256 toClaim = pending + staker.pendingRewards;
        require(toClaim > 0, "No rewards to claim");
        //effects
        staker.pendingRewards = 0;
        staker.rewardDebt = (staker.stakingBalance * accRewardPerToken) / PRECISION;
        require(address(this).balance >= toClaim, "Not enough ether in contract to pay rewards");
        //interactions
        //Transfer the rewards
        (bool success,) = msg.sender.call {value: toClaim}("");
        require(success, "Reward transfer failed");
        emit ClaimReward(toClaim, msg.sender);

    }

    //@notice Exit staking: withdraw all stake and claim all rewards
    function exit() external {
        StakerInfo storage staker = stakers[msg.sender];
        uint256 stakedAmount = staker.stakingBalance;
        require(stakedAmount > 0, "No stake to withdraw");
        withdrawStake(stakedAmount);
        claimRewards();
    }

    //@notice Receive ether to fund rewards pool
    receive() external payable onlyOwner() {
        //receive function to accept ethers
        emit EtherReceived(msg.sender, msg.value);
    }
    //@dev update the accumulated reward per token staked and the last update time
    function updateRewardsData() internal {
        if(block.timestamp <= lastUpdateTime) return;
        if (totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            uint256 rewards = rewardRate * timeElapsed;
            accRewardPerToken += (rewards * PRECISION) / totalStaked;
            lastUpdateTime = block.timestamp;
        }
    }
}