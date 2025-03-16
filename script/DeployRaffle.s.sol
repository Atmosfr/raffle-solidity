// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    function run(
        uint8 participantsCount,
        uint256 minEntryFee
    ) external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .activeNetworkConfig;

        vm.startBroadcast();
        raffle = new Raffle(
            networkConfig.vrfCoordinatorAddress,
            networkConfig.keyHash,
            networkConfig.callbackGasLimit,
            participantsCount,
            networkConfig.subscriptionId,
            minEntryFee
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
