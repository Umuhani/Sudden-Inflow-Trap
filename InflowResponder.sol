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

    event TopUpExecuted(uint256 beforeBalance, uint256 afterBalance, uint256 amountSent);
    event TopUpAttemptFailed(uint256 beforeBalance, uint256 attemptedAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not-owner");
        _;
    }

    modifier onlyCaller() {
        require(msg.sender == caller || msg.sender == owner, "not-caller");
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

        // Safe decimals scaling with clamp
        uint8 dec = 18;
        try token.decimals() returns (uint8 d) { dec = d; } catch {}
        if (dec > 36) dec = 36;

        uint256 scale = 1;
        for (uint8 i = 0; i < dec; i++) {
            scale = scale * 10;
        }

        threshold = _rawThreshold * scale;
    }

    function setCaller(address _caller) external onlyOwner {
        caller = _caller;
    }

    // Fix: keep ABI as expected by TOML and ignore the influx arg — read actual current balance
    function respondToInflow(address _token, address _safe, uint256 /*influxAmount*/) external onlyCaller {
        // sanity-check caller-supplied token/safe match configured values (protects against spoofed payloads)
        if (_token != address(token) || _safe != safe) {
            // mismatch: ignore but update previousBalance to actual on-chain value
            uint256 actual = token.balanceOf(safe);
            previousBalance = actual;
            return;
        }

        uint256 bal = token.balanceOf(safe);
        _handle(bal);
    }

    // fallback path if TOML is changed to respond(bytes)
    function respond(bytes calldata) external onlyCaller {
        uint256 bal = token.balanceOf(safe);
        _handle(bal);
    }

    // internal handler: only top up when we fell below threshold (falling-edge)
    function _handle(uint256 bal) internal {
        // Trigger only when crossing FROM >= threshold TO < threshold
        if (previousBalance >= threshold && bal < threshold) {
            uint256 needed = threshold - bal;

            bool ok;
            try token.transferFrom(fundingWallet, safe, needed) returns (bool res) {
                ok = res;
            } catch {
                ok = false;
            }

            if (ok) {
                emit TopUpExecuted(previousBalance, token.balanceOf(safe), needed);
            } else {
                emit TopUpAttemptFailed(previousBalance, needed);
            }
        }

        // Always update previousBalance to the latest observed on the chain
        previousBalance = bal;
    }
}
