// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A raffel contract
 * @author Shannon Savio Fernandes
 * @notice The contract is used for creating raffels
 * @dev Implements Chainlink VRFv2
 */
contract Raffel is VRFConsumerBaseV2 {
    error raffel__invalidAmount();
    error raffel__winnerPaymentFailed();
    error raffel__raffelClosed();
    error Raffel__UpKeepNotNeeded( uint256 contractBalance, uint256 noOfPlayers, RaffelState raffelState );

    /* Type */
    enum RaffelState {
        OPEN,
        PICKING_WINNER
    }

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 2;
    uint32 private constant NUMBER_OF_WORDS = 1;

    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHashGasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable [] private s_players;
    uint256 private s_firstTimestamp;
    address private s_winner;
    RaffelState private s_raffelState;

    /* Events */

    event EnteredRaffel( address indexed player );
    event RaffelWinner( address indexed player );

    constructor( uint256 entryFee, uint256 interval, address vrfCoordinator, bytes32 keyHashGasLane, uint64 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator) {
        i_entryFee = entryFee;
        i_interval = interval;
        s_firstTimestamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHashGasLane = keyHashGasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffelState = RaffelState.OPEN;
    }

    function EnterRaffel() external payable {
        if(msg.value < i_entryFee){
            revert raffel__invalidAmount(); 
        }

        if( s_raffelState != RaffelState.OPEN ){
            revert raffel__raffelClosed();
        }

        s_players.push(payable(msg.sender));

        emit EnteredRaffel(msg.sender);
    }

    /**
     * 
     * @dev this function is called by the chainlink automation node
     * when?
     * 1. when the time interval has passed.
     * 2. the contract has eth / it has palyers.
     * 3. the raffel is in OPEN state.
     * 4. (should) the subscription has link
     * @return upKeepNeeded 
     * @return 
     */

    function checkUpKeep( bytes memory /* checkData */ ) public view returns(bool upKeepNeeded, bytes memory /* performData */) {
        bool isTimePassed = (block.timestamp - s_firstTimestamp) >= i_interval;
        bool isRaffelOpen = s_raffelState == RaffelState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = ( isTimePassed && isRaffelOpen && hasBalance && hasPlayers );
        return (upKeepNeeded, "0x0");
    }

    function performUpKeep/*PickWinner*/( bytes calldata /* performData */ ) external {

        (bool upKeepNeeded, )= checkUpKeep("");

        if(!upKeepNeeded){
            revert Raffel__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffelState
            );
        }

        // if( (block.timestamp - s_firstTimestamp) < i_interval ){
        //     revert();
        // }

        s_raffelState = RaffelState.PICKING_WINNER;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHashGasLane, // gas lane
            i_subscriptionId, 
            REQUEST_CONFIRMATIONS, 
            i_callbackGasLimit, 
            NUMBER_OF_WORDS
        );
    }

    function fulfillRandomWords( uint256 requestId, uint256 [] memory randomWords ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_winner = winner;
        (bool success, ) = winner.call{ value: address(this).balance }("");
        

        s_raffelState = RaffelState.OPEN;
        s_players = new address payable[](0);
        s_firstTimestamp = block.timestamp;

        emit RaffelWinner(winner);


        if(!success) {
            revert raffel__winnerPaymentFailed();
        }

    }

    /* Getter functions */

    function getEntryFee() external view returns(uint256) {
        return i_entryFee;
    }
}