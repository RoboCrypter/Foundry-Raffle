// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/automation/AutomationCompatibleInterface.sol";


/**
*@title Raffle contract
*@author M.Siddique
*@notice Fully decentralized Raffle/Lottery contract
*@dev This contract implements Chainlink VRF Version 2
*/


contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {

    // Errors

    error Raffle__Not_open();
    error Raffle__Less_than_entrance_fee();
    error Raffle__Participant_has_already_entered();
    error Raffle__Upkeep_not_needed(uint256 raffleState, uint256 numberOfParticipants, uint256 contractBalance);
    error Raffle__Transfer_failed();


    // Type Declarations

    enum RaffleState {OPEN, CALCULATING}


    // State Variables

    uint256 private immutable i_entranceFee;

    address payable[] private s_participants;

    uint256 private s_prizePool;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinatorV2Interface;

    bytes32 private immutable i_keyHash;

    uint64 private immutable i_subscriptionId;

    uint16 private immutable i_requestNumberOfConfirmations;

    uint32 private immutable i_callbackGasLimit;

    uint32 private immutable i_numberOfWords;

    RaffleState private s_raffleState;

    uint256 private s_lastTimeStamp;

    uint256 private immutable i_chainlinkAutomationInterval;   // This is the "Time interval" for "Chainlink Keepers" to automatically run the raffle in every "X amount of time".

    address payable private s_recentRaffleWinner;


    // Events

    event EnteredRaffle(address indexed participant, uint256 indexed entranceFee);

    event RequestedRandomNumber(uint256 indexed requestId);
    
    event WinnerPicked(address indexed recentRaffleWinner, uint256 indexed prizePool);


    // Constructor

    constructor(uint256 entranceFee, address vrfCoordinatorV2Interface, bytes32 keyHash, uint64 subscriptionId, uint16 requestNumberOfConfirmations, uint32 callbackGasLimit, uint32 numberOfWords, uint256 chainlinkAutomationInterval) VRFConsumerBaseV2(vrfCoordinatorV2Interface) {
        
        i_entranceFee = entranceFee;
        
        i_vrfCoordinatorV2Interface = VRFCoordinatorV2Interface(vrfCoordinatorV2Interface);

        i_keyHash = keyHash;

        i_subscriptionId = subscriptionId;

        i_requestNumberOfConfirmations = requestNumberOfConfirmations;
        
        i_callbackGasLimit = callbackGasLimit;

        i_numberOfWords = numberOfWords;

        s_raffleState = RaffleState(RaffleState.OPEN);

        s_lastTimeStamp = block.timestamp;

        i_chainlinkAutomationInterval = chainlinkAutomationInterval;
    }


    // Public & External Functions

    function enterRaffle() external payable {

        if(s_raffleState == RaffleState.CALCULATING) revert Raffle__Not_open();

        uint256 participantsLength = s_participants.length;

        for(uint256 i = 0; i < participantsLength; i++) {

            if(s_participants[i] == msg.sender) revert Raffle__Participant_has_already_entered();
        }

        if(msg.value < i_entranceFee) revert Raffle__Less_than_entrance_fee();

        s_participants.push(payable(msg.sender));

        s_prizePool = s_prizePool + msg.value;

        emit EnteredRaffle(msg.sender, msg.value);
    }


    function checkUpkeep(bytes memory /* checkData */) public view override returns(bool upkeepNeeded, bytes memory checkData) {

        bool hasRaffleOpen = s_raffleState == RaffleState.OPEN;

        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) > i_chainlinkAutomationInterval;

        bool hasParticipants = s_participants.length > 0;

        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = hasRaffleOpen && hasTimePassed && hasParticipants && hasBalance;

        checkData = "0x00";
    }


    function performUpkeep(bytes memory /* performData */) external override {

        (bool upkeepNeeded, ) = checkUpkeep("0x00");

        if(!upkeepNeeded) revert Raffle__Upkeep_not_needed(uint256(s_raffleState), s_participants.length, address(this).balance);

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinatorV2Interface.requestRandomWords(i_keyHash, i_subscriptionId, i_requestNumberOfConfirmations, i_callbackGasLimit, i_numberOfWords);

        emit RequestedRandomNumber(requestId);
    }

    
    function fulfillRandomWords(uint256 /* requestId */, uint256[] memory randomWords) internal override {

        uint256 randomNumber = randomWords[0] % s_participants.length;

        address payable raffleWinner = s_participants[randomNumber];

        s_recentRaffleWinner = raffleWinner;

        s_participants = new address payable[](0);

        s_lastTimeStamp = block.timestamp;

        s_raffleState = RaffleState.OPEN;

        (bool success, ) = raffleWinner.call{ value: address(this).balance }("");

        if(!success) revert Raffle__Transfer_failed();

        emit WinnerPicked(s_recentRaffleWinner, s_prizePool);

        s_prizePool = 0;
    }


    // View & Pure Functions

    function getEntranceFee() external view returns(uint256) {

        return i_entranceFee;
    }


    function getRaffleState() external view returns(RaffleState) {

        return s_raffleState;
    }


    function getParticipant(uint256 index) external view returns(address) {

        return s_participants[index];
    }


    function getAllParticipants() external view returns(address payable[] memory) {

        return s_participants;
    }


    function getNumberOfParticipants() external view returns(uint256) {

        return s_participants.length;
    }


    function getCurrentPrizePool() external view returns(uint256) {

        return s_prizePool;
    }


    function getVRFCoordinatorV2Interface() external view returns(VRFCoordinatorV2Interface) {

        return i_vrfCoordinatorV2Interface;
    }


    function getKeyHash() external view returns(bytes32) {

        return i_keyHash;
    }


    function getSubscriptionId() external view returns(uint64) {

        return i_subscriptionId;
    }


    function getRequestNumberOfConfirmations() external view returns(uint16) {

        return i_requestNumberOfConfirmations;
    }


    function getCallbackGasLimit() external view returns(uint32) {

        return i_callbackGasLimit;
    }


    function getNumberOfWords() external view returns(uint32) {

        return i_numberOfWords;
    }


    function getLastTimeStamp() external view returns(uint256) {

        return s_lastTimeStamp;
    }


    function getChainlinkAutomationInterval() external view returns(uint256) {

        return i_chainlinkAutomationInterval;
    }


    function getRecentRaffleWinner() external view returns(address payable) {

        return s_recentRaffleWinner;
    }
}