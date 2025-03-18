// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    function run(
        uint8 participantsCount
    ) external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.vrfCoordinatorV2_5,
            networkConfig.keyHash,
            networkConfig.callbackGasLimit,
            participantsCount,
            networkConfig.subscriptionId,
            networkConfig.entranceFee
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
