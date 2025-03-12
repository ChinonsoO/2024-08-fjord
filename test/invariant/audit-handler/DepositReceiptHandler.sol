// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.21;

import "./BaseHandler.sol";
import "../../../src/FjordStaking.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract DepositReceiptHandler is BaseHandler {
    /// @notice Mapping to track expected deposit amounts for each user per epoch.
    mapping(address => mapping(uint16 => uint256)) public expectedDeposits;
    mapping(address => mapping(uint16 => uint256)) public expectedVestedDeposits;

    /// @notice List of users that have interacted with the handler.
    address[] public users;

    constructor(FjordStaking _fjordStaking, MockERC20 _token)
        BaseHandler(_fjordStaking, _token)
    {}

    /// @dev Internal helper to record a user if not already recorded.
    function _recordUser(address _user) internal {
        bool found = false;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == _user) {
                found = true;
                break;
            }
        }
        if (!found) {
            users.push(_user);
        }
    }

    /// @notice Stake regular tokens. Records the expected deposit for the current epoch.
    function stake(uint256 _amount, uint256 _timeJumpSeed)
        public
        virtual
        instrument("stake")
        adjustTimestamp(_timeJumpSeed)
        bypassFjordStaking
    {
        _amount = bound(_amount, 1, 100_000_000 ether);
        _recordUser(msg.sender);
        deal(address(token), msg.sender, _amount);

        vm.startPrank(msg.sender);
        token.approve(address(fjordStaking), _amount);
        fjordStaking.stake(_amount);
        vm.stopPrank();

        uint16 epoch = fjordStaking.currentEpoch();
        expectedDeposits[msg.sender][epoch] += _amount;
    }

    /// @notice Stake vested tokens. Records the expected deposit for the current epoch.
    /// Note: In a complete test this function would simulate a valid Sablier NFT deposit.
    function stakeVested(uint256 _streamID, uint256 _timeJumpSeed, uint256 _amount)
        public
        virtual
        instrument("stakeVested")
        adjustTimestamp(_timeJumpSeed)
        bypassFjordStaking
    {
        // For testing purposes, we simulate a vested stake with a given _amount.
        _amount = bound(_amount, 1, 100_000_000 ether);
        _recordUser(msg.sender);

        // In an actual scenario, stakeVested would transfer an NFT from a valid sablier stream.
        // Here we update our expected deposit as if the call succeeded.
        uint16 epoch = fjordStaking.currentEpoch();
        expectedDeposits[msg.sender][epoch] += _amount;
        expectedVestedDeposits[msg.sender][epoch] += _amount;

        // (Optionally, one could call fjordStaking.stakeVested(_streamID) if a proper mock were set up.)
    }

    /// @notice Unstake tokens from a given epoch. Adjusts the expected deposit accordingly.
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
        (uint16 epochStored, uint256 staked, uint256 vestedStaked) = fjordStaking.deposits(msg.sender, _epoch);
        if (epochStored == 0 || (staked == 0 && vestedStaked == 0)) {
            return;
        }
        uint256 currentDeposit = staked + vestedStaked;
        _amount = bound(_amount, 1, currentDeposit);
        vm.prank(msg.sender);
        fjordStaking.unstake(_epoch, _amount);

        // Update the expected deposit for that epoch.
        if (expectedDeposits[msg.sender][_epoch] >= _amount) {
            expectedDeposits[msg.sender][_epoch] -= _amount;
        } else {
            expectedDeposits[msg.sender][_epoch] = 0;
        }
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }
}
