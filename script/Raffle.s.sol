// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;


import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";


contract RaffleScript is Script {

    uint256 private entranceFee = 0.01 ether;

    bytes32 private keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint16 private requestNumberOfConfirmations = 3;

    uint32 private callbackGasLimit = 500000;

    uint32 private numberOfWords = 1;

    uint256 private chainlinkAutomationInterval = 30 seconds;


    function run() external returns(Raffle) {

        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinatorV2_5 = helperConfig.vrfCoordinatorV2_5();

        uint256 subscriptionId = helperConfig.SUBSCRIPTION_ID();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Raffle raffle = new Raffle(entranceFee, vrfCoordinatorV2_5, keyHash, subscriptionId, requestNumberOfConfirmations, callbackGasLimit, numberOfWords, chainlinkAutomationInterval);

        vm.stopBroadcast();

        return raffle;
    }
}