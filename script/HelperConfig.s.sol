// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    address public constant FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {

    error HelperConfig__InvalidChainId();


    struct NetworkConfig {
        uint256 entryFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHashGasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address accountAddress;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e18;


    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        // networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig( uint256 chainId, NetworkConfig memory networkConfig ) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId( uint256 chainId ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory)  {
        console.log("here in sepo");
        return NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHashGasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 113503580238593415129493623276401202005942471904087827860556868535019018840678, // remember  to update to yours
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            accountAddress: vm.envAddress("METAMASK_ACCOUNT_ADDRESS_ETH")
        });

    }
    
    // function getMainnetEthConfig() public pure returns(NetworkConfig memory)  {
    //     return NetworkConfig({ entryFee: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 });

    // }

    function getOrCreateAnvilConfig() public returns(NetworkConfig memory) {
        console.log("here in getOrCreateAnvilConfig");

        if( activeNetworkConfig.vrfCoordinator != address(0) ) {
            return activeNetworkConfig;
        }

        // uint256 accountAddress =  vm.envUint("PRIVATE_KEY");
        // address anvilAddress = vm.addr(accountAddress);

        vm.startBroadcast(vm.envAddress("LOCAL_ACCOUNT_ADDRESS"));
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken link = new LinkToken();
        console.log("here dead last");
        // uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        console.log("here dead line");
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            keyHashGasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // does not matter
            subscriptionId: 0, // remember  to update to yours
            callbackGasLimit: 500000,
            link: address(link),
            accountAddress: vm.envAddress("LOCAL_ACCOUNT_ADDRESS")
        });

        vm.deal(anvilConfig.accountAddress, 100 ether);
        return anvilConfig;
    }
}