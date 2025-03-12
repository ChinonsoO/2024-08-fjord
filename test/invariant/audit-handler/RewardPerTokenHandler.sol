// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.21;

import "./BaseHandler.sol";
import "../../../src/FjordStaking.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract RewardPerTokenHandler is BaseHandler {
    constructor(FjordStaking _fjordStaking, MockERC20 _token)
        BaseHandler(_fjordStaking, _token)
    {}

    // Stake a given amount. This will trigger a _checkEpochRollover and update rewardPerToken.
    function stake(uint256 _amount, uint256 _timeJumpSeed)
        public
        virtual
        instrument("stake")
        adjustTimestamp(_timeJumpSeed)
        bypassFjordStaking
    {
        _amount = bound(_amount, 1, 100_000_000 ether);
        deal(address(token), msg.sender, _amount);

        vm.startPrank(msg.sender);
        token.approve(address(fjordStaking), _amount);
        fjordStaking.stake(_amount);
        vm.stopPrank();
    }

    // Add rewards as the reward admin. Adding rewards will trigger epoch rollover and update rewardPerToken.
    function addReward(uint256 _amount, uint256 _timeJumpSeed)
        public
        virtual
        instrument("addReward")
        adjustTimestamp(_timeJumpSeed)
    {
        // Only allow the reward admin to add rewards.
        if (msg.sender != fjordStaking.rewardAdmin()) {
            return;
        }
        _amount = bound(_amount, 1, 100_000_000 ether);
        deal(address(token), msg.sender, _amount);

        vm.startPrank(msg.sender);
        token.approve(address(fjordStaking), _amount);
        fjordStaking.addReward(_amount);
        vm.stopPrank();
    }

    // Unstake function to remove a portion of a deposit from a past epoch.
    function unstake(uint16 _epoch, uint256 _amount, uint256 _timeJumpSeed)
        public
        virtual
        instrument("unstake")
        adjustTimestamp(_timeJumpSeed)
        bypassFjordStaking
    {
        _epoch = uint16(bound(_epoch, 0, fjordStaking.currentEpoch()));
        // Only allow unstaking for epochs that are sufficiently in the past.
        if (fjordStaking.currentEpoch() < 6 || _epoch > fjordStaking.currentEpoch() - 6) {
            return;
        }
        (uint16 epoch, uint256 staked, ) = fjordStaking.deposits(msg.sender, _epoch);
        if (epoch == 0 || staked == 0) {
            return;
        }
        _amount = bound(_amount, 1, staked);
        vm.prank(msg.sender);
        fjordStaking.unstake(_epoch, _amount);
    }
}
