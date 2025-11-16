// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Low {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract InflowResponder {
    address public owner;
    address public caller; // set to TrapConfig after drosera apply
    address public coldWallet;

    event AlertEmitted(address indexed token, address indexed safe, uint256 influxAmount, address reporter);
    event TransferAttempt(address indexed token, address indexed from, address indexed to, uint256 amount, bool success, bytes data);
    event OwnerChanged(address oldOwner, address newOwner);
    event CallerChanged(address oldCaller, address newCaller);
    event ColdWalletChanged(address oldCold, address newCold);

    modifier onlyOwner() {
        require(msg.sender == owner, "not-owner");
        _;
    }

    modifier onlyCaller() {
        require(caller == address(0) || msg.sender == caller || msg.sender == owner, "not-caller");
        _;
    }

    constructor(address initialOwner) {
        owner = initialOwner;
        emit OwnerChanged(address(0), initialOwner);
    }

    // owner functions
    function setOwner(address newOwner) external onlyOwner {
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    // set the trapConfig address printed by drosera apply
    function setCaller(address c) external onlyOwner {
        emit CallerChanged(caller, c);
        caller = c;
    }

    // set cold wallet address where inflows will be moved (optional)
    function setColdWallet(address w) external onlyOwner {
        emit ColdWalletChanged(coldWallet, w);
        coldWallet = w;
    }

    /// respondToInflow(token, safe, influxAmount)
    /// - only callable by configured caller (or owner)
    /// - emits AlertEmitted
    /// - attempts to move `influxAmount` from `safe` -> `coldWallet` if coldWallet is set and SAFE has approved this contract
    function respondToInflow(address token, address safe, uint256 influxAmount) external onlyCaller {
        emit AlertEmitted(token, safe, influxAmount, msg.sender);

        // if coldWallet not set, skip transfer attempt
        if (coldWallet == address(0)) {
            return;
        }

        // attempt low-level transferFrom(safe -> coldWallet)
        (bool ok, bytes memory data) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", safe, coldWallet, influxAmount));
        // don't revert if transfer failed; emit event for auditing
        emit TransferAttempt(token, safe, coldWallet, influxAmount, ok, data);
    }
}
