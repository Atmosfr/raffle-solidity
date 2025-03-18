// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle, HelperConfig} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract RaffleTest is Test {
    uint8 constant PARTICIPANTS_COUNT = 2;

    Raffle raffle;
    HelperConfig helperConfig;

    address vrfCoordinatorV2_5;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    uint256 minEntryFee;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run(PARTICIPANTS_COUNT);
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

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
}
