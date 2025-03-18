// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract Constants {
    int256 internal constant MOCK_WEI_PER_UINT_LINK = 4e15;
    uint256 internal constant FUND_AMOUNT = 100 ether;
    uint32 internal constant CALLBACK_GAS_LIMIT = 500_000;
    uint256 internal constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    uint96 internal constant MOCK_BASE_FEE = 0.25 ether;
    uint96 internal constant MOCK_GAS_PRICE_LINK = 1e9;
}

contract HelperConfig is Constants, Script {
    error HelperConfig__InvalidChainId();

    // LINK / ETH price

    struct NetworkConfig {
        uint256 subscriptionId;
        address vrfCoordinatorV2_5;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 minEntryFee;
        address account;
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
                minEntryFee: 0.001 ether,
                account: 0x733E5e0E250f9b21F13507F7e3a415eb64e366eb
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5 = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );

        MockLinkToken linkToken = new MockLinkToken();

        uint256 subId = vrfCoordinatorV2_5.createSubscription();

        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            vrfCoordinatorV2_5: address(vrfCoordinatorV2_5),
            keyHash: bytes32(0),
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: subId,
            linkToken: address(linkToken),
            minEntryFee: 0.001 ether,
            account: DEFAULT_SENDER
        });

        return activeNetworkConfig;
    }
}
