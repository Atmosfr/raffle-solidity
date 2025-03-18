// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "foundry-devops/DevOpsTools.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig, Constants} from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        return createSubscription(config.vrfCoordinatorV2_5, config.account);
    }

    function createSubscription(
        address vrfCoordinatorV2_5,
        address account
    ) public returns (uint256, address) {
        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5)
            .createSubscription();
        vm.stopBroadcast();
        return (subscriptionId, vrfCoordinatorV2_5);
    }
}

contract FundSubscription is Constants, Script {
    uint256 public constant LINK_AMOUNT = 3 ether;

    function run() external {}

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        uint256 subscriptionId = config.subscriptionId;
        address linkToken = config.linkToken;
        address account = config.account;

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (subscriptionId, vrfCoordinatorV2_5) = createSubscription.run();
        }

        fundSubscription(
            vrfCoordinatorV2_5,
            subscriptionId,
            linkToken,
            account
        );
    }

    function fundSubscription(
        address vrfCoordinatorV2_5,
        uint256 subscriptionId,
        address link,
        address account
    ) public {
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subscriptionId,
                LINK_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2_5,
                LINK_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentDeployed);
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinatorV2_5,
        uint256 subId,
        address account
    ) public {
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        uint256 subscriptionId = config.subscriptionId;
        address account = config.account;

        addConsumer(
            mostRecentDeployed,
            vrfCoordinatorV2_5,
            subscriptionId,
            account
        );
    }
}
