// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A Sample Raffle Contract
 * @author Dev_horla
 * @dev Implements chainlink VRF2
 * @notice This contract is for creating simple raffle draw contract
 */
contract Raffle is VRFConsumerBaseV2 {
    // Error
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();

    /** Type declaration */
    enum RaffleSate {
        OPEN,
        CALCULATING
    }
    // State Variable

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint64 private immutable i_subscriptionId;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_Players;
    uint256 private s_lastTimeStamp;
    RaffleSate private s_raffleState;
    address private recentWinner;
    // Events
    event EnteredRaffle(address indexed player);
    event pickedWinner(address indexed winner);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address coordinator,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint64 subscriptionId
    ) VRFConsumerBaseV2(coordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(coordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleSate.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleSate.OPEN) {
            revert Raffle__NotOpen();
        }
        s_Players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        s_raffleState = RaffleSate.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 winnerIndex = _randomWords[0] % s_Players.length;
        address payable winner = s_Players[winnerIndex];
        recentWinner = winner;
        s_raffleState = RaffleSate.OPEN;
        s_Players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit pickedWinner(winner);
    }

    /*** Getter ****/

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
