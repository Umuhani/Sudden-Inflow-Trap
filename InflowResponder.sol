// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract AutoTopUpResponder {
    address public owner;
    address public caller;               // Drosera trap address
    IERC20 public token;                 // monitored token
    address public safe;                 // wallet to protect
    address public fundingWallet;        // wallet that pre-approved this responder
    uint256 public threshold;            // scaled threshold
    uint256 public previousBalance;      // for falling-edge detection

    event TopUpExecuted(
        uint256 beforeBalance,
        uint256 afterBalance,
        uint256 amountSent
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "not-owner");
        _;
    }

    modifier onlyCaller() {
        require(
            msg.sender == caller || msg.sender == owner,
            "not-caller"
        );
        _;
    }

    constructor(
        address _token,
        address _safe,
        address _fundingWallet,
        uint256 _rawThreshold
    ) {
        owner = msg.sender;
        token = IERC20(_token);
        safe = _safe;
        fundingWallet = _fundingWallet;

        // Safe decimals scaling without overflows
        uint8 dec = 18;
        try token.decimals() returns (uint8 d) { dec = d; } catch {}

        uint256 scale = 1;
        for (uint8 i = 0; i < dec; i++) {
            scale = scale * 10;
        }

        threshold = _rawThreshold * scale;
    }

    function setCaller(address _caller) external onlyOwner {
        caller = _caller;
    }

    // ✔ Main function called by trap (ABI match with TOML)
    function respondToInflow(
        address _token,
        address _safe,
        uint256 currentBalance
    ) external onlyCaller {
        _handle(currentBalance);
    }

    // ✔ Optional fallback route (if you ever switched TOML to respond(bytes))
    function respond(bytes calldata) external onlyCaller {
        uint256 bal = token.balanceOf(safe);
        _handle(bal);
    }

    // ========================= INTERNAL LOGIC ==============================

    function _handle(uint256 bal) internal {

        // Falling-edge detection:
        // Trigger only when crossing FROM >= threshold TO < threshold
        if (previousBalance >= threshold && bal < threshold) {
            uint256 needed = threshold - bal;

            bool ok = token.transferFrom(fundingWallet, safe, needed);

            // Do not revert (operators get slashed on revert)
            if (ok) {
                emit TopUpExecuted(previousBalance, token.balanceOf(safe), needed);
            } else {
                emit TopUpExecuted(previousBalance, bal, 0);
            }
        }

        previousBalance = bal;
    }
}
