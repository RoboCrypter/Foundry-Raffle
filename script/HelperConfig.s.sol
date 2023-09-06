// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract HelperConfig is Script {

    address public vrfCoordinatorV2Interface;

    uint96 private BASE_FEE = 0.25 ether;   // 0.25 Link

    uint96 private GAS_PRICE_LINK = 1e9;   // 1,000,000,000,000,000,000 (1e18) Juels are equal to 1 Link.

    uint64 public SUBSCRIPTION_ID;

    uint96 private FUND_AMOUNT_LINK = 2 ether;


    constructor() {

        if(block.chainid == 11155111) {

            (vrfCoordinatorV2Interface, SUBSCRIPTION_ID) = getSepoliaNetworkConfig();

        } else if(block.chainid == 31337) {

            (vrfCoordinatorV2Interface, SUBSCRIPTION_ID) = getAnvilNetworkConfig();
        }
    }


    function getSepoliaNetworkConfig() public returns(address, uint64) {

        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = VRFCoordinatorV2Mock(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        uint64 subscriptionId;

        if(SUBSCRIPTION_ID == 0) {

            subscriptionId = vrfCoordinatorV2Mock.createSubscription();
            
        } else {

            subscriptionId = SUBSCRIPTION_ID;
        }

        vm.stopBroadcast();

        return (address(vrfCoordinatorV2Mock), subscriptionId);
    }


    function getAnvilNetworkConfig() public returns(address, uint64) {

        vm.startBroadcast();

        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(BASE_FEE, GAS_PRICE_LINK);

        vm.stopBroadcast();

        uint64 subscriptionId = vrfCoordinatorV2Mock.createSubscription();

        vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT_LINK);

        return (address(vrfCoordinatorV2Mock), subscriptionId);
    }
}