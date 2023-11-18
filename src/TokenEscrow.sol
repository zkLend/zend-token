// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity =0.8.21;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title TokenEscrow
 *
 * @dev An upgradeable token escrow contract for releasing ERC20 tokens based on
 * schedule.
 */
contract TokenEscrow is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    event VestingScheduleAdded(
        address indexed user,
        uint256 startAmount,
        uint256 vestingAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 cliffTime,
        uint256 step
    );
    event VestingScheduleRemoved(address indexed user);
    event TokenVested(address indexed user, uint256 amount);

    /**
     * @param startAmount Amount immediately available at the beginning of the whole schedule
     * @param vestingAmount Amount to be vested over the complete period
     * @param startTime Unix timestamp in seconds for the period start time
     * @param endTime Unix timestamp in seconds for the period end time
     * @param cliffTime Unix timestamp in seconds for the cliff time
     * @param step Interval in seconds at which vestable amounts are accumulated
     * @param lastClaimTime Unix timestamp in seconds for the last claim time
     */
    struct VestingSchedule {
        uint128 startAmount;
        uint128 vestingAmount;
        uint32 startTime;
        uint32 endTime;
        uint32 cliffTime;
        uint32 step;
        uint32 lastClaimTime;
    }

    IERC20Upgradeable public token;
    mapping(address => VestingSchedule) public vestingSchedules;

    function getWithdrawableAmount(address user) external view returns (uint256) {
        (uint256 withdrawableFromSchedule,,) = calculateWithdrawableFromSchedule(user);

        return withdrawableFromSchedule;
    }

    function __TokenEscrow_init(IERC20Upgradeable _token) public initializer {
        __Ownable_init();

        require(address(_token) != address(0), "TokenEscrow: zero address");
        token = _token;
    }

    function setVestingSchedule(
        address user,
        uint256 startAmount,
        uint256 vestingAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 cliffTime,
        uint256 step
    ) external onlyOwner {
        require(user != address(0), "TokenEscrow: zero address");
        require(startAmount > 0 || vestingAmount > 0, "TokenEscrow: zero amount");
        require(startTime < endTime, "TokenEscrow: invalid time range");
        require(step > 0 && endTime.sub(startTime) % step == 0, "TokenEscrow: invalid step");
        require(
            cliffTime >= startTime && cliffTime <= endTime && (cliffTime - startTime) % step == 0,
            "TokenEscrow: invalid cliff time"
        );
        require(
            vestingSchedules[user].startAmount == 0 && vestingSchedules[user].vestingAmount == 0,
            "TokenEscrow: vesting schedule already exists"
        );

        // Overflow checks
        require(uint256(uint128(startAmount)) == startAmount, "TokenEscrow: startAmount overflow");
        require(uint256(uint128(vestingAmount)) == vestingAmount, "TokenEscrow: vestingAmount overflow");
        require(uint256(uint32(startTime)) == startTime, "TokenEscrow: startTime overflow");
        require(uint256(uint32(endTime)) == endTime, "TokenEscrow: endTime overflow");
        require(uint256(uint32(cliffTime)) == cliffTime, "TokenEscrow: cliffTime overflow");
        require(uint256(uint32(step)) == step, "TokenEscrow: step overflow");

        vestingSchedules[user] = VestingSchedule({
            startAmount: uint128(startAmount),
            vestingAmount: uint128(vestingAmount),
            startTime: uint32(startTime),
            endTime: uint32(endTime),
            cliffTime: uint32(cliffTime),
            step: uint32(step),
            lastClaimTime: 0
        });

        emit VestingScheduleAdded(user, startAmount, vestingAmount, startTime, endTime, cliffTime, step);
    }

    function removeVestingSchedule(address user) external onlyOwner {
        require(
            vestingSchedules[user].startAmount != 0 || vestingSchedules[user].vestingAmount != 0,
            "TokenEscrow: vesting schedule not set"
        );

        delete vestingSchedules[user];

        emit VestingScheduleRemoved(user);
    }

    function withdraw() external {
        uint256 withdrawableFromSchedule;

        // Withdraw from schedule
        {
            uint256 newClaimTime;
            bool allVested;
            (withdrawableFromSchedule, newClaimTime, allVested) = calculateWithdrawableFromSchedule(msg.sender);

            if (withdrawableFromSchedule > 0) {
                if (allVested) {
                    // Remove storage slot to save gas
                    delete vestingSchedules[msg.sender];
                } else {
                    vestingSchedules[msg.sender].lastClaimTime = uint32(newClaimTime);
                }
            }
        }

        uint256 totalAmountToSend = withdrawableFromSchedule;
        require(totalAmountToSend > 0, "TokenEscrow: nothing to withdraw");

        if (withdrawableFromSchedule > 0) {
            emit TokenVested(msg.sender, withdrawableFromSchedule);
        }

        token.transfer(msg.sender, totalAmountToSend);
    }

    function calculateWithdrawableFromSchedule(address user)
        private
        view
        returns (uint256 amount, uint256 newClaimTime, bool allVested)
    {
        VestingSchedule memory vestingSchedule = vestingSchedules[user];

        // Schedule not set?
        if (vestingSchedule.startAmount == 0 && vestingSchedule.vestingAmount == 0) {
            return (0, 0, false);
        }

        // Schedule not started?
        if (block.timestamp < uint256(vestingSchedule.startTime)) {
            return (0, 0, false);
        }

        uint256 currentStepTime = MathUpgradeable.min(
            block.timestamp.sub(uint256(vestingSchedule.startTime)).div(uint256(vestingSchedule.step)).mul(
                uint256(vestingSchedule.step)
            ).add(uint256(vestingSchedule.startTime)),
            uint256(vestingSchedule.endTime)
        );

        uint256 amountFromStart =
            vestingSchedule.lastClaimTime >= vestingSchedule.startTime ? 0 : vestingSchedule.startAmount;

        uint256 amountFromVesting;
        {
            uint256 effectiveLastClaimTime =
                MathUpgradeable.max(uint256(vestingSchedule.lastClaimTime), uint256(vestingSchedule.startTime));

            if (currentStepTime <= effectiveLastClaimTime) {
                // No step has elasped since last claim
                amountFromVesting = 0;
            } else if (currentStepTime < uint256(vestingSchedule.cliffTime)) {
                // No vesting due to cliff
                amountFromVesting = 0;
            } else {
                uint256 totalSteps =
                    uint256(vestingSchedule.endTime).sub(uint256(vestingSchedule.startTime)).div(vestingSchedule.step);

                if (currentStepTime == uint256(vestingSchedule.endTime)) {
                    // All vested

                    uint256 stepsVested =
                        effectiveLastClaimTime.sub(uint256(vestingSchedule.startTime)).div(vestingSchedule.step);
                    amountFromVesting = uint256(vestingSchedule.vestingAmount).sub(
                        uint256(vestingSchedule.vestingAmount).div(totalSteps).mul(stepsVested)
                    );
                } else {
                    // Partially vested
                    uint256 stepsToVest = currentStepTime.sub(effectiveLastClaimTime).div(vestingSchedule.step);
                    amountFromVesting = uint256(vestingSchedule.vestingAmount).div(totalSteps).mul(stepsToVest);
                }
            }
        }

        uint256 totalAmount = amountFromStart + amountFromVesting;
        if (totalAmount > 0) {
            if (amountFromVesting == 0) {
                // Only the start amount is taken
                return (amountFromStart, uint256(vestingSchedule.startTime), false);
            } else {
                return (totalAmount, currentStepTime, currentStepTime == uint256(vestingSchedule.endTime));
            }
        } else {
            return (0, 0, false);
        }
    }
}
