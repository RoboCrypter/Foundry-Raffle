// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, Vm, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";


contract RaffleStagingTest is Test {

    Raffle private raffle;

    VRFCoordinatorV2Mock private vrfCoordinatorV2Mock;

    LinkTokenInterface private linkTokenInterface;

    uint256 private FUND_AMOUNT_LINK = 3 ether;

    uint256 private entranceFee;

    address private USER = makeAddr("USER");

    address private USER_TWO = makeAddr("USER_TWO");

    address private USER_THREE = makeAddr("USER_THREE");


    modifier onlyRunOnForkNetwork() {

        if(block.chainid == 31337) {

            return;
        }

        _;
    }


    modifier isForkActive() {

        try vm.activeFork() returns(uint256) {

            return;
        }

        catch {

            _;
        }
    }


    function setUp() external onlyRunOnForkNetwork {

        raffle = Raffle(0x0358530Ce39E335156cf6E78d29EFDA4D5537E6a);

        address vrfCoordinatorV2Interface = address(raffle.getVRFCoordinatorV2Interface());

        vrfCoordinatorV2Mock = VRFCoordinatorV2Mock(vrfCoordinatorV2Interface);

        linkTokenInterface = LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);

        uint64 subscriptionId = raffle.getSubscriptionId();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        linkTokenInterface.transferAndCall(address(vrfCoordinatorV2Mock), FUND_AMOUNT_LINK, abi.encode(subscriptionId));

        vrfCoordinatorV2Mock.addConsumer(subscriptionId, address(raffle));

        vm.stopBroadcast();

        entranceFee = raffle.getEntranceFee();

        vm.deal(USER, 10 ether);

        vm.deal(USER_TWO, 10 ether);

        vm.deal(USER_THREE, 10 ether);
    }


    function testStagingParticipantsCanEnterRaffleAndFulfillRandomWordsWillPickARandomWinner() external onlyRunOnForkNetwork isForkActive {

        vm.prank(USER);

        raffle.enterRaffle{ value: entranceFee }();

        vm.prank(USER_TWO);

        raffle.enterRaffle{ value: entranceFee }();

        vm.prank(USER_THREE);

        raffle.enterRaffle{ value: entranceFee }();

        uint256 chainlinkAutomationInterval = raffle.getChainlinkAutomationInterval();

        vm.warp(block.timestamp + chainlinkAutomationInterval + 1);

        vm.roll(block.number + 1);
        
        vm.recordLogs();

        raffle.performUpkeep("0x00");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 requestId = uint256(entries[1].topics[1]);

        vrfCoordinatorV2Mock.fulfillRandomWords(requestId, address(raffle));

        assertEq(raffle.getRecentRaffleWinner(), USER);

        assertEq(raffle.getCurrentPrizePool(), 0);

        assertEq(address(raffle).balance, raffle.getCurrentPrizePool());

        assertEq(raffle.getNumberOfParticipants(), 0);

        assertEq(uint256(raffle.getRaffleState()), 0);

        assertEq(raffle.getLastTimeStamp(), block.timestamp);
    }
}