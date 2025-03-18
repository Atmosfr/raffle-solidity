// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is AutomationCompatibleInterface, VRFConsumerBaseV2Plus {
    /* ERRORS */
    error Raffle__AlreadyEntered();
    error Raffle__NotEnoughFunds();
    error Raffle__NotOpened();
    error Raffle__FailedToPay();

    /* TYPES */
    enum State {
        Opened,
        Closed
    }

    /* STORAGE */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    /// @dev 0.1%
    uint256 private constant OWNER_FEE = 1000;

    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_minEntryFee;
    uint256 private immutable i_subscriptionId;

    State private s_state;
    uint8 private s_participantsCount;
    uint256 private s_valueToPayToWinner;
    uint256 private s_feesCollected;
    address payable private s_lastWinner;
    address payable[] private s_participants;
    mapping(address participant => bool entered) private s_participantsEntered;

    /* EVENTS */
    event ParticipantEntered(address indexed participant, uint256 amount);
    event FeeCollected(uint256 amount);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event WinnerPaid(address indexed winner, uint256 amount);

    /* MODIFIERS */
    /* CONSTRUCTOR */
    constructor(
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint8 participantsCount,
        uint256 subscriptionId,
        uint256 minEntryFee
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        s_participantsCount = participantsCount;
        i_subscriptionId = subscriptionId;
        i_minEntryFee = minEntryFee;
    }

    /* EXTERNAL FUNCTIONS */

    function setMinParticipantsCount(
        uint8 participantsCount
    ) external onlyOwner {
        s_participantsCount = participantsCount;
    }

    function enterRaffle() external payable {
        address payable entrant = payable(msg.sender);
        uint256 amount = msg.value;

        require(s_state == State.Opened, Raffle__NotOpened());
        require(!s_participantsEntered[entrant], Raffle__AlreadyEntered());
        require(amount >= i_minEntryFee, Raffle__NotEnoughFunds());

        s_participants.push(entrant);

        if (s_participants.length == s_participantsCount) {
            s_state = State.Closed;
        }

        s_participantsEntered[entrant] = true;
        uint256 feeCollected = _collectFee(amount);
        s_valueToPayToWinner += amount - feeCollected;
        emit ParticipantEntered(entrant, amount);
    }

    function withdrawFees(address to) external onlyOwner {
        uint256 amount = s_feesCollected;
        s_feesCollected = 0;
        (bool success, ) = to.call{value: amount}("");
        require(success, Raffle__FailedToPay());
        emit FeeWithdrawn(to, amount);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = _checkConditions();
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if (_checkConditions()) {
            s_vrfCoordinator.requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: i_keyHash,
                    subId: i_subscriptionId,
                    requestConfirmations: REQUEST_CONFIRMATIONS,
                    callbackGasLimit: i_callbackGasLimit,
                    numWords: NUM_WORDS,
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            );
        }
    }

    function getLastWinner() external view returns (address) {
        return s_lastWinner;
    }

    function getKeyHash() external view returns (bytes32) {
        return i_keyHash;
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }

    function getMinEntryFee() external view returns (uint256) {
        return i_minEntryFee;
    }

    function getFeesCollected() external view returns (uint256) {
        return s_feesCollected;
    }

    function getParticipantsCount() external view returns (uint8) {
        return s_participantsCount;
    }

    function getParticipants()
        external
        view
        returns (address payable[] memory)
    {
        return s_participants;
    }

    function getParticipantEntered(
        address participant
    ) external view returns (bool) {
        return s_participantsEntered[participant];
    }

    /* PUBLIC FUNCTIONS */
    /* INTERNAL FUNCTIONS */

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {
        uint256 randomNumber = randomWords[0];
        address payable winner = s_participants[
            randomNumber % s_participants.length
        ];
        s_lastWinner = winner;
        uint256 amountToPay = s_valueToPayToWinner;

        _clearState();
        (bool success, ) = winner.call{value: amountToPay}("");
        require(success, Raffle__FailedToPay());
        emit WinnerPaid(winner, amountToPay);
    }

    /* PRIVATE FUNCTIONS */
    function _collectFee(uint256 amount) private returns (uint256 fee) {
        fee = amount / OWNER_FEE;
        s_feesCollected += fee;
        emit FeeCollected(fee);
    }

    function _clearState() private {
        s_state = State.Opened;
        s_valueToPayToWinner = 0;
        uint256 participantsCount = s_participants.length;
        for (uint256 i; i < participantsCount; ++i) {
            delete s_participantsEntered[s_participants[i]];
        }
        delete s_participants;
    }

    function _checkConditions() private view returns (bool) {
        bool closed = s_state == State.Closed;
        bool participantsFull = s_participants.length >= s_participantsCount;
        return closed && participantsFull;
    }
}
