// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity =0.8.21;

import "forge-std/Test.sol";

import "src/TokenEscrow.sol";
import "test/mock/MockToken.sol";

contract TokenEscrowTest is Test {
    event TokenVested(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event VestingScheduleAdded(address indexed user, uint256 amount, uint256 startTime, uint256 endTime, uint256 step);

    MockERC20 erc20Token;
    TokenEscrow tokenEscrow;
    // MockRewardLocker rewardLocker;
    // AirdropDistributor airdrop;

    uint256 deploymentTime;

    address private constant OWNER = 0x0000000000000000000000000000000000000011;
    address private constant ALICE = 0x0000000000000000000000000000000000000012;
    address private constant BOB = 0x0000000000000000000000000000000000000033;
    address private constant CHARLIE = 0x0000000000000000000000000000000000000044;
    address private constant DAVID = 0x0000000000000000000000000000000000000055;

    function setUp() public {
        payable(OWNER).transfer(1000 ether);
        payable(ALICE).transfer(1000 ether);
        payable(BOB).transfer(1000 ether);
        payable(CHARLIE).transfer(1000 ether);
        payable(DAVID).transfer(1000 ether);

        erc20Token = new MockERC20("Mock Token","MOCK", 8);
        erc20Token.mint(
            OWNER, // account
            10_000_000_000_000000000000000000 // amount
        );

        tokenEscrow = new TokenEscrow();
        tokenEscrow.__TokenEscrow_init(
            IERC20Upgradeable(address(erc20Token)) // token
        );

        tokenEscrow.transferOwnership(
            OWNER // newOwner
        );

        deploymentTime = block.timestamp;

        // Distribute 1B token to escrow
        vm.prank(OWNER);
        erc20Token.transfer(
            address(tokenEscrow), // recipient
            1_000_000_000_000000000000000000 // amount
        );
    }

    function testOnlyOwnerCanSetVestingSchedule() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(ALICE);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            1, // amount
            2, // startTime
            10, // endTime
            2 // step
        );

        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            1, // amount
            2, // startTime
            10, // endTime
            2 // step
        );
    }

    function testOnlyOwnerCanRemoveVestingSchedule() public {
        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            1, // amount
            2, // startTime
            10, // endTime
            2 // step
        );
        (uint128 amount,,,,) = tokenEscrow.vestingSchedules(BOB);
        assertNotEq(amount, 0);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(ALICE);
        tokenEscrow.removeVestingSchedule(
            BOB // user
        );

        vm.prank(OWNER);
        tokenEscrow.removeVestingSchedule(
            BOB // user
        );
        (amount,,,,) = tokenEscrow.vestingSchedules(BOB);
        assertEq(amount, 0);
    }

    function testVestingScheduleParamsMustNotOverflow() public {
        vm.expectRevert(bytes("TokenEscrow: amount overflow"));
        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            0xffffffffffffffffffffffffffffffff + 1, // amount
            2, // startTime
            10, // endTime
            1 // step
        );

        vm.expectRevert(bytes("TokenEscrow: startTime overflow"));
        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            1, // amount
            0xffffffff + 1, // startTime
            0xffffffff + 2, // endTime
            1 // step
        );

        vm.expectRevert(bytes("TokenEscrow: endTime overflow"));
        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            1, // amount
            2, // startTime
            0xffffffff + 1, // endTime
            1 // step
        );
    }

    function testCannotSetVestingScheduleForTheSameAddressTwice() public {
        vm.expectEmit(address(tokenEscrow));
        emit VestingScheduleAdded(
            BOB, // user
            100, // amount
            200, // startTime
            300, // endTime
            50 // step
        );
        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            100, // amount
            200, // startTime
            300, // endTime
            50 // step
        );

        vm.expectRevert(bytes("TokenEscrow: vesting schedule already exists"));
        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            BOB, // user
            100, // amount
            200, // startTime
            300, // endTime
            50 // step
        );
    }

    function testVestingAmountsCanOnlyBeRedeemedBySteps() public {
        uint256 startTime = deploymentTime + 5 days;
        uint256 step = 100;

        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            ALICE, // user
            10000, // amount
            startTime, // startTime
            startTime + step * 10, // endTime
            step // step
        );

        // Cannot claim before reaching start time
        vm.expectRevert(bytes("TokenEscrow: nothing to withdraw"));
        vm.prank(ALICE);
        tokenEscrow.withdraw();

        // Cannot claim before reaching the first step
        vm.warp(startTime + step - 1);
        vm.expectRevert(bytes("TokenEscrow: nothing to withdraw"));
        vm.prank(ALICE);
        tokenEscrow.withdraw();

        vm.warp(startTime + step);
        vm.expectEmit(address(tokenEscrow));
        emit TokenVested(ALICE, 1000);
        vm.expectEmit(address(erc20Token));
        emit Transfer(
            address(tokenEscrow), // sender
            ALICE, // recipient
            1000 // amount
        );
        vm.prank(ALICE);
        tokenEscrow.withdraw();

        // Cannot claim again until next step
        vm.expectRevert(bytes("TokenEscrow: nothing to withdraw"));
        vm.prank(ALICE);
        tokenEscrow.withdraw();
    }

    function testCanClaimMultipleVestingStepsAtOnce() public {
        uint256 startTime = deploymentTime + 5 days;
        uint256 step = 100;

        vm.prank(OWNER);
        tokenEscrow.setVestingSchedule(
            ALICE, // user
            10000, // amount
            startTime, // startTime
            startTime + step * 10, // endTime
            step // step
        );

        // Claim 3 steps at once
        vm.warp(startTime + step * 3);
        vm.expectEmit(address(tokenEscrow));
        emit TokenVested(ALICE, 3000);
        vm.expectEmit(address(erc20Token));
        emit Transfer(
            address(tokenEscrow), // sender
            ALICE, // recipient
            3000 // amount
        );
        vm.prank(ALICE);
        tokenEscrow.withdraw();

        // Claim 2 steps at once
        vm.warp(startTime + step * 5 + step / 2);
        vm.expectEmit(address(tokenEscrow));
        emit TokenVested(ALICE, 2000);
        vm.expectEmit(address(erc20Token));
        emit Transfer(
            address(tokenEscrow), // sender
            ALICE, // recipient
            2000 // amount
        );
        vm.prank(ALICE);
        tokenEscrow.withdraw();

        // Claim all remaining steps
        vm.warp(startTime + 3650 days);
        vm.expectEmit(address(tokenEscrow));
        emit TokenVested(ALICE, 5000);
        vm.expectEmit(address(erc20Token));
        emit Transfer(
            address(tokenEscrow), // sender
            ALICE, // recipient
            5000 // amount
        );
        vm.prank(ALICE);
        tokenEscrow.withdraw();

        // Nothing to withdraw anymore
        vm.expectRevert(bytes("TokenEscrow: nothing to withdraw"));
        vm.prank(ALICE);
        tokenEscrow.withdraw();
    }
}
