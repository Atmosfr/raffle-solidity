// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle, HelperConfig} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {AddConsumer} from "../../script/Interactions.s.sol";

contract RaffleTest is Test {
    uint8 constant PARTICIPANTS_COUNT = 2;
    uint256 constant USER_AMOUNT = 1 ether;
    uint256 constant AMOUNT_TO_ENTER = 0.1 ether;

    Raffle raffle;
    AddConsumer addConsumer;
    HelperConfig helperConfig;

    address vrfCoordinatorV2_5;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    uint256 minEntryFee;

    address owner;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    modifier raffledEntered() {
        vm.prank(alice);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run(PARTICIPANTS_COUNT);
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        owner = raffle.owner();

        addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            networkConfig.vrfCoordinatorV2_5,
            networkConfig.subscriptionId,
            owner
        );

        deal(alice, USER_AMOUNT);
        deal(bob, USER_AMOUNT);

        vrfCoordinatorV2_5 = networkConfig.vrfCoordinatorV2_5;
        keyHash = networkConfig.keyHash;
        callbackGasLimit = networkConfig.callbackGasLimit;
        subscriptionId = networkConfig.subscriptionId;
        minEntryFee = networkConfig.minEntryFee;
    }

    function test_constructor() public view {
        assertEq(raffle.getParticipantsCount(), PARTICIPANTS_COUNT);
        assertEq(raffle.getMinEntryFee(), minEntryFee);
        assertEq(raffle.getKeyHash(), keyHash);
        assertEq(address(raffle.s_vrfCoordinator()), vrfCoordinatorV2_5);
        assertEq(raffle.getSubscriptionId(), subscriptionId);
        assertEq(raffle.getCallbackGasLimit(), callbackGasLimit);
    }

    function test_setMinParticipantsCount() public {
        vm.prank(owner);
        raffle.setMinParticipantsCount(PARTICIPANTS_COUNT);
        assertEq(raffle.getParticipantsCount(), PARTICIPANTS_COUNT);
    }

    function testRevert_setMinParticipantsCountNotOwner() public {
        vm.expectRevert("Only callable by owner");
        raffle.setMinParticipantsCount(PARTICIPANTS_COUNT);
    }

    /* ENTER RAFFLE */

    function test_enterRaffle() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(raffle));
        emit Raffle.ParticipantEntered(alice, USER_AMOUNT);
        raffle.enterRaffle{value: USER_AMOUNT}();

        assertEq(raffle.getParticipantEntered(alice), true);
        assertEq(raffle.getParticipants()[0], alice);

        uint256 feeRate = raffle.getFeeRate();
        uint256 fee = USER_AMOUNT / feeRate;
        assertEq(raffle.getFeesCollected(), fee);

        assertEq(raffle.getCurrentWinnerPrize(), USER_AMOUNT - fee);
    }

    function testRevert_enterRaffleAlreadyEntered() public raffledEntered {
        vm.prank(alice);
        vm.expectRevert(Raffle.Raffle__AlreadyEntered.selector);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();
    }

    function testRevert_enterRaffleNotEnoughFunds() public {
        vm.prank(alice);
        vm.expectRevert(Raffle.Raffle__NotEnoughFunds.selector);
        raffle.enterRaffle{value: 0}();
    }

    function testRevert_enterRaffleNotOpened() public raffledEntered {
        vm.prank(bob);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();

        vm.prank(owner);
        raffle.performUpkeep("");

        vm.prank(alice);
        vm.expectRevert(Raffle.Raffle__NotOpened.selector);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();
    }

    /* WITHDRAW FEES */
    function test_withdrawFees() public raffledEntered {
        uint256 balanceBefore = owner.balance;
        uint256 fees = raffle.getFeesCollected();

        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(raffle));
        emit Raffle.FeeWithdrawn(owner, fees);
        raffle.withdrawFees(owner);

        uint256 balanceAfter = owner.balance;

        assertEq(balanceAfter, balanceBefore + fees);
        assertEq(raffle.getFeesCollected(), 0);
    }

    function testRevert_withdrawFees() public {
        vm.expectRevert("Only callable by owner");
        raffle.withdrawFees(owner);
    }

    function testRevert_withdrawFeesZeroAddress() public raffledEntered {
        vm.prank(owner);
        vm.expectRevert(Raffle.Raffle__ZeroAddress.selector);
        raffle.withdrawFees(address(0));
    }

    function testRevert_withdrawFeesZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(Raffle.Raffle__ZeroAmount.selector);
        raffle.withdrawFees(owner);
    }

    function testRevert_withdrawFeesFailedToPay() public raffledEntered {
        vm.prank(owner);
        vm.expectRevert(Raffle.Raffle__FailedToPay.selector);
        raffle.withdrawFees(address(raffle));
    }
}
