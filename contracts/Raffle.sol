// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
//import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

//enter raffle by paying entree fee
//pick a random winner (randomness using chainlink)
//select winner every x minutes
error Raffle__InsufficientEntryFees();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/**@title A sample Raffle contract
 * @author Zohan
 * @notice the contract is an autonomous decentralized lottery
 */
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    //Type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // State Variables
    uint256 private immutable i_entranceFees;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint256 private s_lastTimestamp;
    uint256 private immutable i_interval;

    //Lottery variables
    address private s_recentWinner;
    RaffleState private s_raffleState;

    //Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestID);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 _entraceFees,
        bytes32 _i_keyHash,
        uint64 _i_subscriptionId,
        uint32 _i_callbackGasLimit,
        uint256 _i_interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFees = _entraceFees;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_keyHash = _i_keyHash;
        i_subscriptionId = _i_subscriptionId;
        i_callbackGasLimit = _i_callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;
        i_interval = _i_interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFees) revert Raffle__InsufficientEntryFees();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__NotOpen();
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This function is called by chainlink keeper nodes
     *
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    /**
     *
     * @dev This function is called by chainlink keepers
     */
    function performUpkeep(bytes calldata /*performData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash, //gasLane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        } else {
            emit WinnerPicked(recentWinner);
        }
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFees;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
