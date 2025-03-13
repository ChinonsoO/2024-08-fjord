// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity =0.8.21;

// import "forge-std/Test.sol";
// import "../../../src/FjordStaking.sol";
// import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
// import { FjordPointsMock } from "../../mocks/FjordPointsMock.sol";

// contract MultipleStakesBugTest is Test {
//     FjordStaking public fjordStaking;
//     MockERC20 public token;
//     address public minter = makeAddr("minter");
//     // For testing we use a dummy sablier address.
//     address public constant SABLIER_ADDRESS = address(0xB10daee1FCF62243aE27776D7a92D39dC8740f95);
//     address public user = address(this);
//     address public points;

//     function setUp() public {
//         points = address(new FjordPointsMock());
//         token = new MockERC20("Fjord", "FJO", 18);
//         fjordStaking = new FjordStaking(address(token), minter, SABLIER_ADDRESS, address(this), points);

//         // Fund and approve tokens for the user.
//         deal(address(token), user, 1000 ether);
//         token.approve(address(fjordStaking), 1000 ether);

//         // Fund minter and set its approval.
//         deal(address(token), minter, 1000 ether);
//         vm.prank(minter);
//         token.approve(address(fjordStaking), 1000 ether);
//     }

//     function testMultipleStakesUnredeemedDepositBug() public {
//         // The user stakes twice in different epochs.
//         // Because the contract only keeps a single unredeemedEpoch marker,
//         // the deposit from the first epoch gets "overwritten" and is never redeemed.

//         uint256 stakeEpoch1 = 10 ether;
//         uint256 stakeEpoch2 = 5 ether;
//         uint256 stakeEpoch3 = 1 ether;
        
//         // Initially currentEpoch == 1.
//         uint16 initialEpoch = fjordStaking.currentEpoch();
//         assertEq(initialEpoch, 1, "Initial epoch should be 1");

//         // === Epoch 1: Stake first deposit ===
//         fjordStaking.stake(stakeEpoch1);
//         // At this point:
//         //   deposits[user][1] = stakeEpoch1,
//         //   userData.unredeemedEpoch is set to 1.

//         // === Move to Epoch 2 ===
//         vm.warp(block.timestamp + fjordStaking.epochDuration());
//         // Now currentEpoch is 2.
//         // Stake a second time. This call sets userData.unredeemedEpoch = 2,
//         // and creates deposits[user][2] = stakeEpoch2.
//         // also _redeem is called, _ud.totalStaked is zero so the first section of our
//         // redeem function adds zero rewards, The second part is called but unredeemedEpoch == current epoch -1
//         // so zero rewards are also added, so that stake gains nothing for that epoch.
//         fjordStaking.stake(stakeEpoch2);

//         // The bug: deposit from epoch 1 remains in deposits[user][1] but is never processed,
//         // because _redeem only redeems the deposit corresponding to unredeemedEpoch (now 2).

//         // === Move to Epoch 3 to allow redemption ===
//         vm.warp(block.timestamp + fjordStaking.epochDuration());
//         // Now currentEpoch becomes 3. Calling any function with the redeemPendingRewards modifier
//         // claimReward will trigger _redeem.
//         fjordStaking.claimReward(false);

//         // At this point, _redeem runs and processes deposits[user][unredeemedEpoch] which is epoch 2.
//         // The deposit from epoch 1 is left unrewarded.
//         // Thus, userData.totalStaked is updated with only stakeEpoch2 (redeemed from epoch 2)
//         // A correct implementation would have totalStaked = stakeEpoch1 + stakeEpoch2 + stakeEpoch3.

//         // Retrieve user data.
//         (uint256 totalStaked, , , ) = fjordStaking.userData(user);

//         // Due to the bug, only the deposit from epoch 2 and the new stake from epoch 3 are redeemed.
//         uint256 expectedTotal = stakeEpoch1 + stakeEpoch2;
//         assertEq(
//             totalStaked,
//             expectedTotal,
//             "Bug: The deposit from epoch 1 was not redeemed, causing lost rewards"
//         );
//     }
// }
