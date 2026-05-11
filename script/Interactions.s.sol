// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";
import { DevOpsTools } from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address)  {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfigByChainId(block.chainid).vrfCoordinator;
        address accountAddress = helperConfig.getConfigByChainId(block.chainid).accountAddress;
        return createSubscription(vrfCoordinator, accountAddress);
    }

    function createSubscription(address vrfCoordinator, address accountAddress) public returns (uint256, address)  {
        console.log("Creating subscription on chain id: ", block.chainid);
        vm.startBroadcast(accountAddress);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Created subscriptionId: ", subscriptionId);
        return ( subscriptionId, vrfCoordinator );
    }

    function run() external returns (uint256, address)  {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint64 public constant AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfigByChainId(block.chainid).vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfigByChainId(block.chainid).subscriptionId;
        address link = helperConfig.getConfigByChainId(block.chainid).link;
        address accountAddress = helperConfig.getConfigByChainId(block.chainid).accountAddress;
    
        fundSubscription(vrfCoordinator, subscriptionId, link, accountAddress);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address link, address accountAddress ) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using VRF: ", vrfCoordinator);
        console.log("On chain id: ", block.chainid);

        if(block.chainid == 31337){
            vm.startBroadcast(accountAddress);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(accountAddress);
            LinkToken(link).transferAndCall(vrfCoordinator, AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        return fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address raffle, address vrfCoordinator, uint256 subscriptionId, address accountAddress) public {
        console.log("adding consumer: ", raffle);
        console.log("with vrfCoordinator: ", vrfCoordinator);
        console.log("On chain id: ", block.chainid);

        console.log("On address: ", accountAddress);

        vm.startBroadcast(accountAddress);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig( address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address accountAddress = helperConfig.getConfig().accountAddress;

        addConsumer(raffle, vrfCoordinator, subscriptionId, accountAddress);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid );
        addConsumerUsingConfig(raffle);
    }
}