// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DeployRaffle, HelperConfig} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {AddConsumer} from "../../script/Interactions.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {Constants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, Constants {
    uint8 constant PARTICIPANTS_COUNT = 2;
    uint256 constant USER_AMOUNT = 1 ether;
    uint256 constant AMOUNT_TO_ENTER = 0.1 ether;
    uint256 constant LINK_BALANCE = 100 ether;

    Raffle raffle;
    AddConsumer addConsumer;
    HelperConfig helperConfig;

    address vrfCoordinatorV2_5;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    uint256 minEntryFee;
    LinkToken link;

    address owner;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    modifier raffledEntered() {
        vm.prank(alice);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();

        vm.prank(bob);
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
        link = LinkToken(networkConfig.linkToken);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
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

    /* CHECK UPKEEP */

    function test_checkUpkeepReturnsTrue() public raffledEntered {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    function test_checkUpkeepStateClosed() public raffledEntered {
        vm.prank(owner);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function test_checkUpkeepNotEnoughParticipants() public {
        vm.prank(alice);
        raffle.enterRaffle{value: AMOUNT_TO_ENTER}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    /* PERFORM UPKEEP */
    function test_performUpkeep() public raffledEntered {
        vm.prank(owner);
        vm.expectEmit(false, false, false, false, address(raffle));
        emit Raffle.WinnerRequested();
        raffle.performUpkeep("");

        assertEq(uint8(raffle.getState()), uint8(Raffle.State.Closed));
    }

    function testRevert_performUpkeepUpkeepNotNeeded() public {
        vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("");
    }

    /* FULFILL RANDOM WORDS */

    function test_fulfillRandomWords() public raffledEntered {
        raffle.performUpkeep("");

        uint256 requestId = 1;
        uint256 prize = raffle.getCurrentWinnerPrize();
        uint256 bobBalanceBefore = bob.balance;

        vm.expectEmit(true, false, false, true, address(raffle));
        emit Raffle.WinnerPaid(bob, prize);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            requestId,
            address(raffle)
        );

        uint256 bobBalanceAfter = bob.balance;

        assertEq(uint8(raffle.getState()), uint8(Raffle.State.Opened));
        assertEq(raffle.getLastWinner(), bob);
        assertEq(raffle.getParticipants().length, 0);
        assertEq(raffle.getParticipantEntered(bob), false);
        assertEq(raffle.getParticipantEntered(alice), false);
        assertEq(raffle.getCurrentWinnerPrize(), 0);
        assertEq(bobBalanceAfter, bobBalanceBefore + prize);
    }
}
