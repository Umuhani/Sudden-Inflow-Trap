// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract AutoTopUpResponder {
    address public owner;
    address public caller;              // drosera trap contract
    IERC20 public token;                // token monitored
    address public safe;                // destination safe
    address public fundingWallet;       // pre-approved funding wallet

    uint256 public threshold;           // decimals-scaled threshold
    uint256 public previousBalance;     // for rising-edge detection

    event RespondExecuted(uint256 beforeBalance, uint256 afterBalance, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not-owner");
        _;
    }

    modifier onlyCaller() {
        // FIXED: responder is now *closed* by default
        require(msg.sender == caller || msg.sender == owner, "not-caller");
        _;
    }

    constructor(
        address _token,
        address _safe,
        address _fundingWallet,
        uint256 _rawThreshold       // e.g. "10000" for 10k tokens
    ) {
        owner = msg.sender;
        token = IERC20(_token);
        safe = _safe;
        fundingWallet = _fundingWallet;

        // Try reading decimals — default to 18 if token misbehaves
        uint8 dec;
        try token.decimals() returns (uint8 d) { dec = d; }
        catch { dec = 18; }

        threshold = _rawThreshold * (10 ** dec);   // decimals-aware threshold
    }

    function setCaller(address _caller) external onlyOwner {
        caller = _caller;
    }

    // Called by the Drosera trap when threshold is exceeded
    function respond(bytes calldata) external onlyCaller {
        uint256 bal = token.balanceOf(safe);

        // RISING-EDGE LOGIC:
        // Only trigger when previous ≤ threshold AND now > threshold
        if (previousBalance <= threshold && bal > threshold) {
            uint256 refillAmount = bal - threshold; // amount above threshold
            // Pull from the funding wallet (must have approved us)
            require(
                token.transferFrom(fundingWallet, safe, refillAmount),
                "transferFrom failed"
            );

            emit RespondExecuted(previousBalance, token.balanceOf(safe), refillAmount);
        }

        previousBalance = bal;
    }
}
