// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;


import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract HelperConfig is Script {

    address public vrfCoordinatorV2_5;

    uint96 private BASE_FEE = 0.25 ether;   // 0.25 Link

    uint96 private GAS_PRICE_LINK = 1e9;   // 1,000,000,000,000,000,000 (1e18) Juels are equal to 1 Link.

    uint256 public SUBSCRIPTION_ID;

    uint96 private FUND_AMOUNT_LINK = 2 ether;

    int256 private WEI_PER_UNIT_LINK = 4471314402500153;


    constructor() {

        if(block.chainid == 11155111) {

            (vrfCoordinatorV2_5, SUBSCRIPTION_ID) = getSepoliaNetworkConfig();

        } else if(block.chainid == 31337) {

            (vrfCoordinatorV2_5, SUBSCRIPTION_ID) = getAnvilNetworkConfig();
        }
    }


    function getSepoliaNetworkConfig() public returns(address, uint256) {

        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = VRFCoordinatorV2_5Mock(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        uint256 subscriptionId = 20103093368965145253148836226806256887630955207626038505659267421988237245727;

        vm.stopBroadcast();

        return (address(vrfCoordinatorV2_5Mock), subscriptionId);
    }


    function getAnvilNetworkConfig() public returns(address, uint256) {

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);

        vm.stopBroadcast();

        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();

        vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, FUND_AMOUNT_LINK);

        return (address(vrfCoordinatorV2_5Mock), subscriptionId);
    }
}