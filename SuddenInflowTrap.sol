// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata collectOutputs) external pure returns (bool, bytes memory);
}

interface IERC20View {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/// SuddenInflowTrap (Hoodi PoC)
/// - TOKEN: 0x9A7B8CAeAfADBEc42700CE4c71640909C6521292
/// - SAFE (monitored): 0xCBdc71d4E2A3f6DEe40250739c5b30763D66Cf8E
/// - Trigger: latestBalance > prevBalance + THRESHOLD (10_000 tokens)
contract SuddenInflowTrap is ITrap {
    address public constant TOKEN  = 0x9A7B8CAeAfADBEc42700CE4c71640909C6521292;
    address public constant SAFE   = 0xCBdc71d4E2A3f6DEe40250739c5b30763D66Cf8E;

    // threshold base: 10_000 tokens (scaled by decimals in collect())
    uint256 public constant THRESHOLD_BASE = 10_000;

    // Max decimals clamp to avoid huge exponents
    uint8 public constant MAX_DECIMALS = 36;

    // collect() returns: abi.encode(balance, blockNumber, decimals)
    function collect() external view override returns (bytes memory) {
        uint8 dec = 18;
        uint256 bal = 0;
        uint256 blk = block.number;

        address t = TOKEN;
        uint256 size;
        assembly { size := extcodesize(t) }

        if (size > 0) {
            // try decimals
            try IERC20View(t).decimals() returns (uint8 d) {
                dec = d > MAX_DECIMALS ? MAX_DECIMALS : d;
            } catch {
                dec = 18;
            }
            // try balanceOf
            try IERC20View(t).balanceOf(SAFE) returns (uint256 b) {
                bal = b;
            } catch {
                bal = 0;
            }
        } else {
            // not a contract
            bal = 0;
            dec = 18;
        }

        return abi.encode(bal, blk, dec);
    }

    // safe scale: compute 10 ** dec (dec <= MAX_DECIMALS)
    function _scale(uint8 dec) internal pure returns (uint256) {
        if (dec > MAX_DECIMALS) dec = MAX_DECIMALS;
        uint256 s = 1;
        for (uint8 i = 0; i < dec; i++) {
            s *= 10;
        }
        return s;
    }

    // shouldRespond expects two non-empty samples in collectOutputs
    // each sample: abi.encode(balance, sampleBlock, decimals)
    // returns (true, abi.encode(token, safe, influxAmount)) when triggered
    function shouldRespond(bytes[] calldata collectOutputs) external pure override returns (bool, bytes memory) {
        if (collectOutputs.length < 2) return (false, "");
        if (collectOutputs[0].length == 0 || collectOutputs[1].length == 0) return (false, "");

        (uint256 aBal, uint256 aBlk, uint8 aDec) = abi.decode(collectOutputs[0], (uint256, uint256, uint8));
        (uint256 bBal, uint256 bBlk, uint8 bDec) = abi.decode(collectOutputs[1], (uint256, uint256, uint8));

        // determine decimals: prefer equal, else pick non-zero, else fallback to 18
        uint8 dec;
        if (aDec == bDec) {
            dec = aDec;
        } else if (aDec != 0 && bDec == 0) {
            dec = aDec;
        } else if (bDec != 0 && aDec == 0) {
            dec = bDec;
        } else {
            // both nonzero and different -> pick smaller to be conservative
            dec = aDec < bDec ? aDec : bDec;
        }
        if (dec == 0) dec = 18;
        if (dec > MAX_DECIMALS) dec = MAX_DECIMALS;

        // normalize by block numbers
        bool aIsLatest = aBlk >= bBlk;
        uint256 latestBal = aIsLatest ? aBal : bBal;
        uint256 prevBal   = aIsLatest ? bBal : aBal;

        // sanity
        if (latestBal <= prevBal) return (false, "");
        if (prevBal == 0) {
            // if previous is zero, treat any incoming > threshold as trigger
            // compute threshold scaled
            uint256 scale = _scale(dec);
            uint256 threshold = THRESHOLD_BASE * scale;
            uint256 influx = latestBal - prevBal;
            if (influx > threshold) {
                return (true, abi.encode(TOKEN, SAFE, influx));
            }
            return (false, "");
        }

        // compute scaled threshold safely
        uint256 scale = _scale(dec);
        uint256 thresholdScaled = THRESHOLD_BASE * scale;

        // compute influx
        uint256 influxAmount = latestBal - prevBal;

        if (influxAmount > thresholdScaled) {
            // payload returns (token, safe, influxAmount)
            return (true, abi.encode(TOKEN, SAFE, influxAmount));
        }

        return (false, "");
    }
}
