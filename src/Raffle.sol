// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Raffle is Ownable {
    /* ERRORS */
    /* TYPES */
    /* IMMUTABLES */
    /* STORAGE */
    address private lastWinner;

    /* EVENTS */
    /* MODIFIERS */
    /* CONSTRUCTOR */
    constructor(address owner) Ownable(owner) {}
    /* EXTERNAL FUNCTIONS */
    /* PUBLIC FUNCTIONS */
    /* INTERNAL FUNCTIONS */
    /* PRIVATE FUNCTIONS */
}
