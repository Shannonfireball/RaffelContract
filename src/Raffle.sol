// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
// import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { VRFConsumerBaseV2Plus } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A raffle contract
 * @author Shannon Savio Fernandes
 * @notice The contract is used for creating raffles
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    error raffle__invalidAmount();
    error raffle__winnerPaymentFailed();
    error raffle__raffleClosed();
    error Raffle__UpKeepNotNeeded( uint256 contractBalance, uint256 noOfPlayers, uint256 raffleState );

    /* Type */
    enum RaffleState {
        OPEN,
        PICKING_WINNER
    }

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 2;
    uint32 private constant NUMBER_OF_WORDS = 1;

    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval;
    // VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHashGasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable [] private s_players;
    uint256 private s_lastTimestamp;
    address private s_winner;
    RaffleState private s_raffleState;

    /* Events */

    event EnteredRaffle( address indexed player );
    event RaffleWinner( address indexed player );
    event RequestedRaffleWinner( uint256 indexed requestId );

    constructor( uint256 entryFee, uint256 interval, address vrfCoordinator, bytes32 keyHashGasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = entryFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        // i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHashGasLane = keyHashGasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if(msg.value < i_entryFee){
            revert raffle__invalidAmount(); 
        }

        if( s_raffleState != RaffleState.OPEN ){
            revert raffle__raffleClosed();
        }

        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    /**
     * 
     * @dev this function is called by the chainlink automation node
     * when?
     * 1. when the time interval has passed.
     * 2. the contract has eth / it has palyers.
     * 3. the raffle is in OPEN state.
     * 4. (should) the subscription has link
     * @return upkeepNeeded 
     * @return 
     */

    function checkUpkeep( bytes memory /* checkData */ ) public view returns(bool upkeepNeeded, bytes memory /* performData */) {
        bool isTimePassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = ( isTimePassed && isRaffleOpen && hasBalance && hasPlayers );
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep( bytes calldata /* performData */ ) external override {

        (bool upkeepNeeded, )= checkUpkeep("");

        if(!upkeepNeeded){
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        // if( (block.timestamp - s_lastTimestamp) < i_interval ){
        //     revert();
        // }

        s_raffleState = RaffleState.PICKING_WINNER;

        // uint256 requestId = i_vrfCoordinator.requestRandomWords(
        //     i_keyHashGasLane, // gas lane
        //     i_subscriptionId, 
        //     REQUEST_CONFIRMATIONS, 
        //     i_callbackGasLimit, 
        //     NUMBER_OF_WORDS
        // );

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHashGasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMBER_OF_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords( uint256 /* requestId */,  uint256 [] calldata randomWords ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_winner = winner;
        (bool success, ) = winner.call{ value: address(this).balance }("");
        

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        emit RaffleWinner(winner);


        if(!success) {
            revert raffle__winnerPaymentFailed();
        }

    }

    /* Getter functions */

    function getEntryFee() external view returns(uint256) {
        return i_entryFee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }

    function getPlayer( uint256 index ) external view returns(address) {
        return s_players[index];
    }

    function getWinner() external view returns(address) {
        return s_winner;
    }

    function getLengthOfPlayers() external view returns(uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimestamp;
    }
}