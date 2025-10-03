// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./AccessControlled.sol";

/**
 * Per-code rules:
 *  - enabled: toggle code
 *  - price: payout in token decimals (USDC = 6)
 *  - maxPerYear: 0 = unlimited; otherwise cap per patient/year
 *  - label: human-readable for UIs/logs
 *
 * Example (USDC 6 decimals):
 *  code 1 (Telehealth): enabled, price=250_000 (=$0.25), maxPerYear=0
 *  code 2 (Annual):     enabled, price=500_000 (=$0.50), maxPerYear=1
 */
contract Rules is AccessControlled {
    struct Rule {
        bool    enabled;
        uint256 price;
        uint16  maxPerYear; // 0 = unlimited
        string  label;
    }

    mapping(uint16 => Rule) private _ruleOf;

    event RuleSet(uint16 indexed code, bool enabled, uint256 price, uint16 maxPerYear, string label);
    event RuleToggled(uint16 indexed code, bool enabled);
    event RulePriceSet(uint16 indexed code, uint256 price);
    event RuleMaxPerYearSet(uint16 indexed code, uint16 maxPerYear);
    event RuleLabelSet(uint16 indexed code, string label);

    function setRule(uint16 code, bool enabled, uint256 price, uint16 maxPerYear, string calldata label)
        external onlyOwner
    {
        _ruleOf[code] = Rule(enabled, price, maxPerYear, label);
        emit RuleSet(code, enabled, price, maxPerYear, label);
    }

    function setEnabled(uint16 code, bool enabled) external onlyOwner {
        _ruleOf[code].enabled = enabled;
        emit RuleToggled(code, enabled);
    }

    function setPrice(uint16 code, uint256 price) external onlyOwner {
        _ruleOf[code].price = price;
        emit RulePriceSet(code, price);
    }

    function setMaxPerYear(uint16 code, uint16 maxPerYear) external onlyOwner {
        _ruleOf[code].maxPerYear = maxPerYear;
        emit RuleMaxPerYearSet(code, maxPerYear);
    }

    function setLabel(uint16 code, string calldata label) external onlyOwner {
        _ruleOf[code].label = label;
        emit RuleLabelSet(code, label);
    }

    // Engine reads this at adjudication time
    function getRule(uint16 code) external view returns (bool enabled, uint256 price, uint16 maxPerYear) {
        Rule memory r = _ruleOf[code];
        return (r.enabled, r.price, r.maxPerYear);
    }

    // Optional UI helper
    function getRuleFull(uint16 code) external view returns (Rule memory) { return _ruleOf[code]; }
}
