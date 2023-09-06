// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";


contract RaffleScript is Script {

    uint256 private entranceFee = 0.01 ether;

    bytes32 private keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    uint16 private requestNumberOfConfirmations = 3;

    uint32 private callbackGasLimit = 500000;

    uint32 private numberOfWords = 1;

    uint256 private chainlinkAutomationInterval = 30 seconds;


    function run() external returns(Raffle) {

        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinatorV2Interface = helperConfig.vrfCoordinatorV2Interface();

        uint64 subscriptionId = helperConfig.SUBSCRIPTION_ID();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Raffle raffle = new Raffle(entranceFee, vrfCoordinatorV2Interface, keyHash, subscriptionId, requestNumberOfConfirmations, callbackGasLimit, numberOfWords, chainlinkAutomationInterval);

        vm.stopBroadcast();

        return raffle;
    }
}