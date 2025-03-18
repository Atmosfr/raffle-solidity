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

    function testRevert_setMinParticipantsCount() public {
        vm.expectRevert("Only callable by owner");
        raffle.setMinParticipantsCount(PARTICIPANTS_COUNT);
    }

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

    function testRevert_enterRaffleAlreadyEntered() public {
        vm.prank(alice);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();

        vm.prank(alice);
        vm.expectRevert(Raffle.Raffle__AlreadyEntered.selector);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();
    }

    function testRevert_enterRaffleNotEnoughFunds() public {
        vm.prank(alice);
        vm.expectRevert(Raffle.Raffle__NotEnoughFunds.selector);
        raffle.enterRaffle{value: 0}();
    }

    function testRevert_enterRaffleNotOpened() public {
        vm.prank(alice);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();

        vm.prank(bob);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();

        vm.prank(owner);
        raffle.performUpkeep("");

        vm.prank(alice);
        vm.expectRevert(Raffle.Raffle__NotOpened.selector);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();
    }
}
