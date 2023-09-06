// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, Vm, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {RaffleScript} from "../../script/Raffle.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test {

    error Raffle__Participant_has_already_entered();
    error Raffle__Less_than_entrance_fee();
    error Raffle__Not_open();
    error Raffle__Upkeep_not_needed(uint256 raffleState, uint256 numberOfParticipants, uint256 contractBalance);


    Raffle private raffle;

    uint256 private entranceFee;

    uint256 private chainlinkAutomationInterval;

    VRFCoordinatorV2Mock private vrfCoordinatorV2Mock;

    uint64 private subscriptionId;

    address public USER = makeAddr("USER");


    event EnteredRaffle(address indexed participant, uint256 indexed entranceFee);

    event RequestedRandomNumber(uint256 indexed requestId);

    event WinnerPicked(address indexed recentRaffleWinner, uint256 indexed prizePool);


    modifier enteredRaffle() {

        vm.prank(USER);

        raffle.enterRaffle{ value: entranceFee }();

        _;
    }


    modifier onlyRunOnTestNetwork() {

        if(block.chainid != 31337) {

            return;
        }

        _;
    }


    function setUp() external {

        RaffleScript raffleScript = new RaffleScript();

        raffle = raffleScript.run();

        entranceFee = raffle.getEntranceFee();

        chainlinkAutomationInterval = raffle.getChainlinkAutomationInterval();

        address vrfCoordinatorV2Interface = address(raffle.getVRFCoordinatorV2Interface());

        vrfCoordinatorV2Mock = VRFCoordinatorV2Mock(vrfCoordinatorV2Interface);

        subscriptionId = raffle.getSubscriptionId();

        ( , , address owner, ) = vrfCoordinatorV2Mock.getSubscription(subscriptionId);

        vm.prank(owner);

        vrfCoordinatorV2Mock.addConsumer(subscriptionId, address(raffle));

        vm.deal(USER, 10 ether);
    }


    function testEnterRaffleFunction() external {

        vm.prank(USER);

        raffle.enterRaffle{ value: entranceFee }();

        address participant = raffle.getParticipant(0);

        uint256 participantsLength = raffle.getNumberOfParticipants();

        uint256 contractBalance = address(raffle).balance;

        uint256 prizePool = raffle.getCurrentPrizePool();

        assertEq(participant, USER);

        assertEq(participantsLength, 1);

        assertEq(contractBalance, prizePool);
    }


    function testEnterRaffleShouldEmitAnEvent() external {

        vm.prank(USER);

        vm.expectEmit();

        emit EnteredRaffle(USER, entranceFee);

        raffle.enterRaffle{ value: entranceFee }();
    }


    function testOneParticipantCanOnlyBeEnteredOnce() external enteredRaffle {

        vm.prank(USER);

        vm.expectRevert(Raffle__Participant_has_already_entered.selector);

        raffle.enterRaffle{ value: entranceFee }();

        uint256 participantsLength = raffle.getNumberOfParticipants();

        assertEq(participantsLength, 1);
    }


    function testUniqueParticipantsCanEnter() external {

        uint160 numberOfParticipants = 10;

        for(uint160 i = 0; i < numberOfParticipants; i++) {

            hoax(address(i), 1 ether);

            raffle.enterRaffle{ value: entranceFee }();
        }

        uint256 participantsLength = raffle.getNumberOfParticipants();

        uint256 contractBalance = address(raffle).balance;

        assertEq(participantsLength, numberOfParticipants);

        assertEq(contractBalance, entranceFee * numberOfParticipants);
    }


    function testIfPayLessThanEntranceFeeItShouldRevert() external {

        vm.prank(USER);

        vm.expectRevert(Raffle__Less_than_entrance_fee.selector);

        raffle.enterRaffle{ value: 0.0099 ether }();

        uint256 participantsLength = raffle.getNumberOfParticipants();

        uint256 contractBalance = address(raffle).balance;

        assertEq(participantsLength, 0);

        assertEq(contractBalance, 0);
    }


    function testItShouldNotLetAnyOneEnterInRaffleIfRaffleStateIsCalculating() external enteredRaffle {

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        raffle.performUpkeep("0x00");

        vm.expectRevert(Raffle__Not_open.selector);

        raffle.enterRaffle{ value: entranceFee }();
    }


    function testItShouldNotRunPerformUpkeepIfCheckUpkeepIsFalse() external onlyRunOnTestNetwork {

        assertEq(raffle.getNumberOfParticipants(), 0);

        assertEq(address(raffle).balance, 0);
        
        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        vm.expectRevert(abi.encodeWithSelector(Raffle__Upkeep_not_needed.selector, uint256(raffle.getRaffleState()), raffle.getNumberOfParticipants(), address(raffle).balance));

        raffle.performUpkeep("0x00");
        

        rewind(chainlinkAutomationInterval + 1);
        
        assertEq(block.timestamp, 1);

        raffle.enterRaffle{ value: entranceFee }();

        vm.expectRevert(abi.encodeWithSelector(Raffle__Upkeep_not_needed.selector, uint256(raffle.getRaffleState()), raffle.getNumberOfParticipants(), address(raffle).balance));

        raffle.performUpkeep("0x00");


        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);
        
        assertEq(block.timestamp, chainlinkAutomationInterval + 2);

        raffle.performUpkeep("0x00");

        assertEq(uint256(raffle.getRaffleState()), 1);

        vm.expectRevert(abi.encodeWithSelector(Raffle__Upkeep_not_needed.selector, uint256(raffle.getRaffleState()), raffle.getNumberOfParticipants(), address(raffle).balance));

        raffle.performUpkeep("0x00");
    }


    function testItShouldRunPerformUpkeepIfCheckUpkeepIsTrue() external enteredRaffle {

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        assertEq(uint256(raffle.getRaffleState()), 0);

        assert((block.timestamp - raffle.getLastTimeStamp()) > chainlinkAutomationInterval);

        assert(raffle.getNumberOfParticipants() > 0);

        assert(address(raffle).balance > 0);

        raffle.performUpkeep("0x00");

        assertEq(uint256(raffle.getRaffleState()), 1);
    }


    function testPerformUpkeepShouldEmitAnEvent() external enteredRaffle onlyRunOnTestNetwork {

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        vm.expectEmit();

        emit RequestedRandomNumber(1);

        raffle.performUpkeep("0x00");
    }


    function testFulfillRandomWordsShouldPickARandomWinner() external enteredRaffle onlyRunOnTestNetwork {

        assertEq(USER.balance, 10 ether - entranceFee);

        assertEq(raffle.getNumberOfParticipants(), 1);

        assertEq(raffle.getParticipant(0), USER);

        assertEq(raffle.getCurrentPrizePool(), raffle.getNumberOfParticipants() * entranceFee);

        assertEq(uint256(raffle.getRaffleState()), 0);

        uint256 lastTimeStampBefore = raffle.getLastTimeStamp();

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        vm.recordLogs();

        emit RequestedRandomNumber(1);

        raffle.performUpkeep("0x00");

        assertEq(uint256(raffle.getRaffleState()), 1);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 requestId = uint256(entries[0].topics[1]);

        vrfCoordinatorV2Mock.fulfillRandomWords(requestId, address(raffle));

        uint256 lastTimeStampAfter = raffle.getLastTimeStamp();

        assertEq(raffle.getRecentRaffleWinner(), USER);

        assertEq(USER.balance, 10 ether);

        assertEq(raffle.getNumberOfParticipants(), 0);

        assertEq(raffle.getCurrentPrizePool(), 0);

        assertEq(address(raffle).balance, 0);

        assertEq(uint256(raffle.getRaffleState()), 0);

        assert(lastTimeStampAfter > lastTimeStampBefore);
    }


    function testFulfillRandomWordsShouldEmitAnEvent() external enteredRaffle onlyRunOnTestNetwork {

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        vm.recordLogs();

        emit RequestedRandomNumber(1);

        raffle.performUpkeep("0x00");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 requestId = uint256(entries[0].topics[1]);

        uint256 prizePool = raffle.getCurrentPrizePool();

        vm.expectEmit();

        emit WinnerPicked(USER, prizePool);

        vrfCoordinatorV2Mock.fulfillRandomWords(requestId, address(raffle));
    }


    function testFulfillRandomWordsShouldPickARandomWinnerWithMultipleParticipants() external enteredRaffle onlyRunOnTestNetwork {

        address USER_ONE = makeAddr("USER_ONE");

        vm.deal(USER_ONE, entranceFee);

        vm.prank(USER_ONE);

        raffle.enterRaffle{ value: entranceFee }();

        address USER_TWO = makeAddr("USER_TWO");

        vm.deal(USER_TWO, entranceFee);

        vm.prank(USER_TWO);

        raffle.enterRaffle{ value: entranceFee }();

        address USER_THREE = makeAddr("USER_THREE");

        vm.deal(USER_THREE, entranceFee);

        vm.prank(USER_THREE);

        raffle.enterRaffle{ value: entranceFee }();

        address USER_FOUR = makeAddr("USER_FOUR");

        vm.deal(USER_FOUR, entranceFee);

        vm.prank(USER_FOUR);

        raffle.enterRaffle{ value: entranceFee }();

        address USER_FIVE = makeAddr("USER_FIVE");

        vm.deal(USER_FIVE, entranceFee);

        vm.prank(USER_FIVE);

        raffle.enterRaffle{ value: entranceFee }();

        uint256 numberOfParticipantsInRaffle = raffle.getNumberOfParticipants();

        assertEq(numberOfParticipantsInRaffle, 6);

        assertEq(raffle.getCurrentPrizePool(), raffle.getNumberOfParticipants() * entranceFee);

        assertEq(address(raffle).balance, raffle.getCurrentPrizePool());

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        vm.recordLogs();

        emit RequestedRandomNumber(1);

        raffle.performUpkeep("0x00");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 requestId = uint256(entries[0].topics[1]);

        vrfCoordinatorV2Mock.fulfillRandomWords(requestId, address(raffle));

        assertEq(raffle.getNumberOfParticipants(), 0);

        assertEq(raffle.getCurrentPrizePool(), 0);

        assertEq(address(raffle).balance, raffle.getCurrentPrizePool());

        assertEq(raffle.getRecentRaffleWinner(), USER_FIVE);

        assertEq(USER_FIVE.balance, numberOfParticipantsInRaffle * entranceFee);
    }


    function testGetKeyHashFunction() external {

        bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

        assertEq(raffle.getKeyHash(), keyHash);
    }


    function testGetRequestNumberOfConfirmationsFunction() external {

        uint16 requestNumberOfConfirmations = 3;

        assertEq(raffle.getRequestNumberOfConfirmations(), requestNumberOfConfirmations);
    }


    function testGetCallbackGasLimitFunction() external {

        uint32 callbackGasLimit = 500000;

        assertEq(raffle.getCallbackGasLimit(), callbackGasLimit);
    }


    function testGetNumberOfWordsFunction() external {

        uint32 numberOfWords = 1;

        assertEq(raffle.getNumberOfWords(), numberOfWords);
    }


    function testGetVRFCoordinatorV2InterfaceFunction() external {

        assertEq(address(raffle.getVRFCoordinatorV2Interface()), address(vrfCoordinatorV2Mock));
    }


    function testGetSubscriptionIdFunction() external {

        assertEq(raffle.getSubscriptionId(), subscriptionId);
    }


    function testGetEntranceFeeFunction() external {

        assertEq(raffle.getEntranceFee(), entranceFee);
    }
}