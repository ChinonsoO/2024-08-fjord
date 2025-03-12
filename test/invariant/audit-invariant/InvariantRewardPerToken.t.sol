// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.21;

import "../../../src/FjordStaking.sol";
import "../audit-handler/RewardPerTokenHandler.sol";
import "forge-std/Test.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FjordPointsMock } from "../../mocks/FjordPointsMock.sol";

contract InvariantRewardPerTokenTest is Test {
    FjordStaking private fjordStaking;
    MockERC20 private token;
    RewardPerTokenHandler private rewardHandler;
    address minter = makeAddr("minter");
    // Using a dummy Sablier address for test purposes
    address private constant SABLIER_ADDRESS = address(0xB10daee1FCF62243aE27776D7a92D39dC8740f95);

    function setUp() public {
        token = new MockERC20("Fjord", "FJO", 18);
        fjordStaking = new FjordStaking(
            address(token), minter, SABLIER_ADDRESS, address(this), address(new FjordPointsMock())
        );
        rewardHandler = new RewardPerTokenHandler(fjordStaking, token);
        // Target the RewardPerTokenHandler for fuzzing
        targetContract(address(rewardHandler));
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = rewardHandler.stake.selector;
        selectors[1] = rewardHandler.unstake.selector;
        selectors[2] = rewardHandler.addReward.selector;
        targetSelector(FuzzSelector({ addr: address(rewardHandler), selectors: selectors }));
    }

    /// @dev Invariant test to ensure that rewardPerToken is non-decreasing across epochs.
    /// It iterates from epoch 0 to the currentEpoch and asserts that each new value is greater than
    /// or equal to the previous one.
    function invariant_RewardPerToken_NonDecreasing() public {
        uint16 currentEpoch = fjordStaking.currentEpoch();
        // Start from epoch 0 as the base (should be 0 by default)
        uint256 previousRPT = fjordStaking.rewardPerToken(0);
        for (uint16 epoch = 1; epoch < currentEpoch; epoch++) {
            uint256 currentRPT = fjordStaking.rewardPerToken(epoch);
            // Assert that the reward per token did not decrease.
            assertGe(currentRPT, previousRPT);
            previousRPT = currentRPT;
        }
    }
}
