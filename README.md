# protocol-claims — Prometheus Chains
Solidity contracts for **claims adjudication & instant settlement** (optimized for Ethereum L2, e.g. Base).

![License](https://img.shields.io/badge/license-Apache--2.0-blue)

> **Status:** Experimental / not audited. Use at your own risk.

---

## ✨ What this is
A minimal-leakage on-chain engine for paying healthcare claims in seconds:

- **Provider submits** a coded claim for a **pseudonymous** patient (`bytes32`).
- **Engine validates** (provider whitelist, coverage, rules/caps).
- **Bank pays** immediately from an ERC-20 vault (e.g., USDC on Base).
- **Privacy by design:** no per-claim on-chain storage of patient identity.

---

## 📦 Contracts
- **`AccessControlled.sol`** – simple owner access pattern.
- **`ProviderRegistry.sol`** – whitelist providers with optional active year windows.  
  `setProvider(provider, active, startYear, endYear)` · `isActive(provider, year)`
- **`Enrollment.sol`** – coverage by `patientId: bytes32` with optional year windows.  
  `setCoverage(patientId, active, startYear, endYear)` · `isCovered(patientId, year)`
- **`Rules.sol`** – per-code pricing & caps.  
  `setRule(code, enabled, price, maxPerYear, label)` · `getRule(code) → (enabled, price, maxPerYear)`
- **`Bank.sol`** – ERC-20 vault; only the engine can instruct payments.  
  `setEngine(addr)` · `pay(to, amount, claimId)` · `vaultBalance()`  
  _Ops_: `recoverToken`, `recoverETH` (guarded; cannot recover primary vault token)
- **`ClaimEngine.sol`** – the brain.  
  `submit(patientId, code, year)` → **pays** or **rejects**  
  Admin: `setPaused(bool)` · View: `paused()`, `claimKeyOf(id)`

---

## 🧠 Engine behavior (at a glance)
- **Eligibility:** provider must be active for `year`; patient must have coverage for `year`.
- **Rules:** each `code` has `{enabled, price, maxPerYear}`; `maxPerYear=0` means unlimited.
- **Idempotency:** visit index is computed per `(patientId, year, code)`; a **deterministic key** prevents accidental duplicate payments.
- **Immediate settlement:** calls `Bank.pay()` on success.
- **Soft rejections:** if vault is underfunded, emits a rejection (no revert), so ops can top-up and retry.
- **Pause switch:** owner can pause submissions in emergencies.
- **Minimal leakage:** events exclude patient identity; `claimKeyOf[id]` is an optional non-PHI lookup.

**Possible rejection reasons** (event payload):  
`"provider inactive"`, `"not covered"`, `"code disabled/price=0"`, `"max per year reached"`, `"bank underfunded"`, `"duplicate"`.

---

## 🧾 Events
```solidity
event ClaimPaid(
  uint256 indexed id,
  bytes32 indexed claimKey,
  address indexed provider,
  uint16 code,
  uint16 year,
  uint256 amount,
  uint32 visitIndex
);

event ClaimRejected(
  bytes32 indexed claimKey,
  address indexed provider,
  uint16 code,
  uint16 year,
  string reason
);
