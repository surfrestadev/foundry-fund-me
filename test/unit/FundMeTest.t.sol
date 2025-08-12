// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // Give USER some ether
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4); // Assuming the price feed version is 4
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert("You need to spend more ETH!");
        fundMe.fund(); // Attempt to fund with no ETH sent
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}(); // Fund the contract
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}(); // Fund the contract
        address funder = fundMe.getFunder(0); // Get the first funder
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}(); // Fund the contract
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw(); // USER tries to withdraw, should fail
    }

    // Arrange-Act-Assert pattern

    function testWithdrawWithASingleFunder() public funded {
        //Arrange

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0); // FundMe balance should be zero
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance); // Owner's balance should increase by the FundMe balance
    }

    function testWithdrawFromMultipleFunders() public {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // Start from 1 to avoid using the deploy
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // Create a new funder with SEND_VALUE
            fundMe.fund{value: SEND_VALUE}(); // Fund the contract
        }

        //Act
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0); // FundMe balance should be zero
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance); // Owner's balance should increase by the FundMe balance
    }

    function testWithdrawFromMultipleFundersCheaper() public {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // Start from 1 to avoid using the deploy
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // Create a new funder with SEND_VALUE
            fundMe.fund{value: SEND_VALUE}(); // Fund the contract
        }

        //Act
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0); // FundMe balance should be zero
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance); // Owner's balance should increase by the FundMe balance
    }
}
