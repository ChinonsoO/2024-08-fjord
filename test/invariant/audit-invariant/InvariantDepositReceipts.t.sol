// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.21;

import "../../../src/FjordStaking.sol";
import "../audit-handler/DepositReceiptHandler.sol";
import "forge-std/Test.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FjordPointsMock } from "../../mocks/FjordPointsMock.sol";

contract InvariantDepositReceiptsTest is Test {
    FjordStaking private fjordStaking;
    MockERC20 private token;
    DepositReceiptHandler private depositHandler;
    address minter = makeAddr("minter");
    // Using a dummy Sablier address for testing.
    address private constant SABLIER_ADDRESS = address(0xB10daee1FCF62243aE27776D7a92D39dC8740f95);

    function setUp() public {
        token = new MockERC20("Fjord", "FJO", 18);
        fjordStaking = new FjordStaking(
            address(token),
            minter,
            SABLIER_ADDRESS,
            address(this), // used as an authorized sablier sender for testing
            address(new FjordPointsMock())
        );
        depositHandler = new DepositReceiptHandler(fjordStaking, token);
        // Target the DepositReceiptHandler for fuzzing.
        targetContract(address(depositHandler));
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = depositHandler.stake.selector;
        selectors[1] = depositHandler.unstake.selector;
        selectors[2] = depositHandler.stakeVested.selector;
        targetSelector(FuzzSelector({ addr: address(depositHandler), selectors: selectors }));
    }

    /// @dev Invariant test to ensure that for each user, for every active deposit epoch,
    /// the sum stored in the deposit receipt (staked + vestedStaked) equals the expected deposit amount.
    function invariant_DepositReceiptsCorrect() public {
        uint256 usersLength = depositHandler.getUsers().length;
        for (uint256 i = 0; i < usersLength; i++) {
            address user = depositHandler.getUsers()[i];
            uint256[] memory activeEpochs = fjordStaking.getActiveDeposits(user);
            for (uint256 j = 0; j < activeEpochs.length; j++) {
                uint16 epoch = uint16(activeEpochs[j]);
                ( , uint256 staked, uint256 vestedStaked) = fjordStaking.deposits(user, epoch);
                uint256 depositSum = staked + vestedStaked;
                uint256 expected = depositHandler.expectedDeposits(user, epoch);
                uint256 expectedVested = depositHandler.expectedVestedDeposits(user, epoch);
                // Assert that the deposit receipt's sum matches the expected amount.
                assertEq(depositSum, expected - expectedVested , "Invariant: Deposit receipt sum mismatch for user and epoch");
            }
        }
    }
}
