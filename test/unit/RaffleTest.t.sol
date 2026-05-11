// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import { Test, console,console2 } from "forge-std/Test.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";

contract RaffleTest is Test {

    /* Events */

    event EnteredRaffle( address indexed player );
    event RaffleWinner( address indexed player );


    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entryFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHashGasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    LinkToken link;
    address accountAddress;

    address USER = makeAddr("test-USER");
    uint256 constant AMOUNT = 0.01 ether;
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;
    uint256 public constant LINK_BALANCE = 100 ether;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    
    function setUp() external {
        DeployRaffle raffleDeployer = new DeployRaffle();
        ( raffle, helperConfig ) = raffleDeployer.run();

        vm.deal(USER, INITIAL_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entryFee = config.entryFee;
        subscriptionId = config.subscriptionId;
        keyHashGasLane = config.keyHashGasLane;
        interval = config.interval;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        link = LinkToken(config.link);

        console.log("subscriptionId",subscriptionId);
        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinator, LINK_BALANCE);
        vm.stopPrank();
    }

    function testLotteryIsInOpenStateAtStart() public {
        // console.log("uint256(raffle.getRaffleState())",uint256(raffle.getRaffleState()));
        // assertEq(uint256(raffle.getRaffleState()), 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testLotteryRevertsWithLowEthPayment() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.raffle__invalidAmount.selector);
        raffle.enterRaffle();
    }

    function testPlayerIsTrackedOnEnterance() public {
        vm.prank(USER);
        raffle.enterRaffle{ value: AMOUNT }();
        address fetchedPlayerAddress = raffle.getPlayer(0);
        assert( fetchedPlayerAddress == USER );
    }

    function testPlayerEmitEventOnEnterance() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));

        // we have to emit the event that we want to check for
        emit EnteredRaffle(USER);
        raffle.enterRaffle{ value: AMOUNT }();
    }

    function testPlayerIsNotAllowedAfterClosing() public {
        vm.prank(USER);
        raffle.enterRaffle{ value: AMOUNT }();

        // edit the block time cheatcode
        vm.warp(block.timestamp + interval + 1);

        // add a block cheat
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.raffle__raffleClosed.selector);
        vm.prank(USER);
        raffle.enterRaffle{ value: AMOUNT }();
    }


    function testCheckUpkeepReturnsFalseWhenLowBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenRaffleNotOpen() public {
        vm.prank(USER);
        raffle.enterRaffle{ value: AMOUNT }();
        
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded == false);
    }




    function testPerformUpkeepCanRunWhenCheckUpkeepIsTrue() public {
        vm.prank(USER);
        raffle.enterRaffle{ value: AMOUNT }();
        
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }


    function testPerformUpkeepCanRevertsWhenCheckUpkeepIsFalse() public {
        uint256 currentBlance = 0;
        uint256 numberOfPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBlance, numberOfPlayers, raffleState));

        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(USER);
        raffle.enterRaffle{ value: AMOUNT }();
        
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        // logs all events
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        // special types in test
        Vm.Log[] memory entries = vm.getRecordedLogs();
                                        // 0 refers to the event in topice
                                        // 1 refers to the requestId in topice
                            // we know the first event is the chainlink event
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert( uint256(requestId) > 0 );
        assert( uint256(raffleState) == 1 );
    }


    modifier skipForFork(){
        if(block.chainid != 31337 ){
            return;
        }
        _;
    }

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public skipForFork raffleEnteredAndTimePassed {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));


        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));
    }


    function testFullfillRandomWordsPicksWinnerResetsAndSendsMoney() public skipForFork raffleEnteredAndTimePassed {
        uint256 additionalEntrance = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; i < startingIndex + additionalEntrance; i++){
            address player = address(uint160(i));
            hoax(player, INITIAL_BALANCE);
            raffle.enterRaffle{ value: AMOUNT }();
        }

        uint256 prize = entryFee * ( additionalEntrance + 1);


        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console.logBytes32(entries[1].topics[1]);
        console.logBytes32(entries[0].topics[1]);

        // vm.recordLogs();
        // raffle.performUpkeep(""); // emits requestId
        // Vm.Log[] memory entries = vm.getRecordedLogs();
        // console2.logBytes32(entries[1].topics[1]);
        // bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        uint256 lastTimeStamp = raffle.getLastTimeStamp();
        // console.log("requestId",requestId);
        console.log("entries",entries.length);

        // pretend to be chainlink vrf
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords( uint256(requestId), address(raffle) );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(lastTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getWinner().balance == (INITIAL_BALANCE + prize - entryFee) );

    }
}