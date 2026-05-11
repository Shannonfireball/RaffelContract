// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import { Script, console } from "forge-std/Script.sol";
import { Raffle } from "../src/Raffle.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { CreateSubscription, FundSubscription, AddConsumer } from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        console.log("in deploy config.subscriptionId",config.subscriptionId);
        if( config.subscriptionId == 0 ){
            // creating 
            CreateSubscription createSubscription = new CreateSubscription();
            ( config.subscriptionId, config.vrfCoordinator ) = createSubscription.createSubscription(config.vrfCoordinator, config.accountAddress);

            console.log("created returned subscriptionId", config.subscriptionId);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.accountAddress);
            
            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.accountAddress);
        Raffle raffle = new Raffle(config.entryFee, config.interval, config.vrfCoordinator, config.keyHashGasLane, config.subscriptionId, config.callbackGasLimit );
        vm.stopBroadcast();

        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.accountAddress);

        return (raffle, helperConfig);
    }
}