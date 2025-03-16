// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    uint96 private constant BASE_FEE = 30 gwei;
    uint96 private constant GAS_PRICE = 10 gwei;
    int256 private constant WEI_PER_UNIT_LINK = 1 gwei;
    uint256 private constant FUND_AMOUNT = 100 ether;
    uint32 private constant CALLBACK_GAS_LIMIT = 500_000;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    struct NetworkConfig {
        uint256 subscriptionId;
        address vrfCoordinatorV2_5;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 entranceFee;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chain => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 0,
                vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                entranceFee: 0.001 ether
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        // deploy vrfCoordinator mock
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE,
            WEI_PER_UNIT_LINK
        );

        MockLinkToken linkToken = new MockLinkToken();

        uint256 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        vm.stopBroadcast();

        return
            NetworkConfig({
                vrfCoordinatorV2_5: address(vrfCoordinator),
                keyHash: bytes32(0),
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                subscriptionId: subId,
                linkToken: address(linkToken),
                entranceFee: 0.001 ether
            });
    }
}
