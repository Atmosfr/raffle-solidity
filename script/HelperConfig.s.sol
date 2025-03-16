// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract HelperConfig is Script {
    uint96 private constant BASE_FEE = 30 gwei;
    uint96 private constant GAS_PRICE = 10 gwei;
    int256 private constant WEI_PER_UNIT_LINK = 1 gwei;
    uint256 private constant FUND_AMOUNT = 100 ether;
    uint32 private constant CALLBACK_GAS_LIMIT = 40_000;

    struct NetworkConfig {
        address vrfCoordinatorAddress;
        bytes32 keyHash;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                vrfCoordinatorAddress: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
                callbackGasLimit: CALLBACK_GAS_LIMIT
                //linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinatorAddress != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        // deploy vrfCoordinator mock
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE,
            WEI_PER_UNIT_LINK
        );

        uint256 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        vm.stopBroadcast();

        return
            NetworkConfig({
                vrfCoordinatorAddress: address(vrfCoordinator),
                keyHash: bytes32(0),
                callbackGasLimit: CALLBACK_GAS_LIMIT
            });
    }
}
