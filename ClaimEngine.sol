// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./AccessControlled.sol";
import "./ProviderRegistry.sol";
import "./Enrollment.sol";
import "./Rules.sol";
import "./Bank.sol";

/**
 * Minimal-leakage + immediate-settlement engine:
 * - patientId (bytes32) is used for checks/counters but NEVER emitted and NOT stored in per-claim records.
 * - year is YYYY only (no month/day).
 * - per-code rules read from Rules: enabled, price, maxPerYear(0=unlimited).
 * - auto-increment visit index per (patientId, year, code).
 * - idempotency uses computed visit index to prevent accidental double-pays.
 * - immediate Bank.pay() on success.
 * - owner can pause/unpause submissions.
 */
contract ClaimEngine is AccessControlled {
    ProviderRegistry public providers;
    Enrollment      public enrollment;
    Rules           public rules;
    Bank            public bank;

    bool public paused;

    // visit counts: patientId => year => code => count
    mapping(bytes32 => mapping(uint16 => mapping(uint16 => uint32))) private _count;

    uint256 private _nextId = 1;
    mapping(bytes32 => bool)  private _usedKey;

    // Optional: lightweight lookup without leaking patientId
    mapping(uint256 => bytes32) public claimKeyOf;

    // NOTE: patientId intentionally omitted from events to minimize leakage
    event ClaimPaid(
        uint256 indexed id,
        bytes32 indexed claimKey,
        address indexed provider,
        uint16 code,
        uint16 year,
        uint256 amount,
        uint32 visitIndex
    );
    event ClaimRejected(bytes32 indexed claimKey, address indexed provider, uint16 code, uint16 year, string reason);
    event PausedSet(bool paused);

    constructor(ProviderRegistry _p, Enrollment _e, Rules _r, Bank _b) {
        providers  = _p;
        enrollment = _e;
        rules      = _r;
        bank       = _b;
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit PausedSet(p);
    }

    /**
     * @param patientId Pseudonymous bytes32 known only to payer/provider off-chain
     * @param code      App-defined code (e.g., 1=Telehealth, 2=Annual)
     * @param year      YYYY only (1900..9999)
     */
    function submit(bytes32 patientId, uint16 code, uint16 year) external {
        require(!paused, "paused");
        require(patientId != bytes32(0), "patientId=0");
        require(year >= 1900 && year <= 9999, "bad year");

        // Eligibility
        if (!ProviderRegistry(providers).isActive(msg.sender, year)) {
            return _rej(patientId, code, year, "provider inactive");
        }
        if (!Enrollment(enrollment).isCovered(patientId, year)) {
            return _rej(patientId, code, year, "not covered");
        }

        // Rules / pricing
        (bool enabled, uint256 price, uint16 maxPerYear) = rules.getRule(code);
        if (!enabled || price == 0) {
            return _rej(patientId, code, year, "code disabled/price=0");
        }

        // per-year cap: 0 = unlimited; else enforce maximum per patient/year/code
        uint32 cur = _count[patientId][year][code];
        if (maxPerYear != 0 && cur >= maxPerYear) {
            return _rej(patientId, code, year, "max per year reached");
        }

        uint32 nextVisit = cur + 1;

        // Idempotency keyed by computed next visit index (prevents double-submits of the same visit)
        bytes32 key = keccak256(
            abi.encodePacked(msg.sender, patientId, code, year, nextVisit, block.chainid, address(this))
        );
        if (_usedKey[key]) { emit ClaimRejected(key, msg.sender, code, year, "duplicate"); return; }
        _usedKey[key] = true;

        // Optional UX hint (soft reject instead of revert if unfunded)
        try bank.vaultBalance() returns (uint256 bal) {
            if (bal < price) { return _rej(patientId, code, year, "bank underfunded"); }
        } catch {
            // ignore hint failures; Bank.pay will enforce anyway
        }

        // Persist & bump counter (note: we do NOT store patientId in any per-claim record)
        _count[patientId][year][code] = nextVisit;

        uint256 id = _nextId++;
        claimKeyOf[id] = key; // optional, public, non-PHI lookup

        // Immediate settlement
        bank.pay(msg.sender, price, id);

        emit ClaimPaid(id, key, msg.sender, code, year, price, nextVisit);
    }

    // Build deterministic rejection key without advancing counters; avoids leaking patientId in logs.
    function _rej(bytes32 patientId, uint16 code, uint16 year, string memory why) internal {
        uint32 cur = _count[patientId][year][code];
        bytes32 key = keccak256(abi.encodePacked(msg.sender, patientId, code, year, cur, block.chainid, address(this)));
        emit ClaimRejected(key, msg.sender, code, year, why);
    }
}
