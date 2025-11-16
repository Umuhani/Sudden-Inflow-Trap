# Sudden Inflow Trap — Hoodi PoC

Monitors token `0x9A7B8CAeAfADBEc42700CE4c71640909C6521292` for sudden incoming inflows to `0xCBdc71d4E2A3f6DEe40250739c5b30763D66Cf8E`.  
Triggers when an incoming amount in a collection window exceeds **10,000 tokens** (scaled by token decimals).

## Files
- `src/SuddenInflowTrap.sol` — Trap (Drosera-compatible)
- `src/InflowResponder.sol` — Response contract (owner + setCaller + setColdWallet)
- `drosera.toml` — config snippet (update response_contract)
- This README
<img width="1576" height="728" alt="image" src="https://github.com/user-attachments/assets/7cfb9d96-09bf-4b5e-859d-2a67d90dc240" />



# TokenBalanceTrap -- Hoodi Network 

### *Auto-refill trigger when SAFE balance drops below 10,000 HOODI tokens*

## 📌 Overview

This PoC uses **Drosera Network Traps** to monitor the balance of a
specific ERC-20 token on Hoodi Network testnet.

If the SAFE wallet balance drops **below 10,000 HOODI**, the trap
triggers a response.

## 📍 Parameters

-   **Token:** `0x9A7B8CAeAfADBEc42700CE4c71640909C6521292`
-   **SAFE:** `0xCBdc71d4E2A3f6DEe40250739c5b30763D66Cf8E`
-   **Threshold:** 10,000 tokens
-   **Network:** Hoodi Testnet

## 🧠 Trap Logic

The trap: 1. Reads token balance of SAFE 2. Compares to threshold 3.
Triggers response when below threshold

