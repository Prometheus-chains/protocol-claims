// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./AccessControlled.sol";

/**
 * Whitelists provider addresses with optional active-year windows.
 * year==0 in start/end means "open".
 */
contract ProviderRegistry is AccessControlled {
    struct Provider { bool active; uint16 startYear; uint16 endYear; } // 0 = open-ended
    mapping(address => Provider) private _p;

    event ProviderSet(address indexed provider, bool active, uint16 startYear, uint16 endYear);

    function setProvider(address provider, bool active, uint16 startYear, uint16 endYear)
        external onlyOwner
    {
        _p[provider] = Provider(active, startYear, endYear);
        emit ProviderSet(provider, active, startYear, endYear);
    }

    function isActive(address provider, uint16 year) external view returns (bool) {
        Provider memory pr = _p[provider];
        if (!pr.active) return false;
        if (pr.startYear != 0 && year < pr.startYear) return false;
        if (pr.endYear   != 0 && year > pr.endYear)   return false;
        return true;
    }
}
