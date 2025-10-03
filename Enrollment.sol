// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./AccessControlled.sol";

/**
 * Coverage by pseudonymous patientId with optional active-year windows.
 */
contract Enrollment is AccessControlled {
    struct Coverage { bool active; uint16 startYear; uint16 endYear; } // 0 = open-ended
    mapping(bytes32 => Coverage) private _c; // patientId -> coverage

    event CoverageSet(bytes32 indexed patientId, bool active, uint16 startYear, uint16 endYear);

    function setCoverage(bytes32 patientId, bool active, uint16 startYear, uint16 endYear)
        external onlyOwner
    {
        require(patientId != bytes32(0), "patientId=0");
        _c[patientId] = Coverage(active, startYear, endYear);
        emit CoverageSet(patientId, active, startYear, endYear);
    }

    function isCovered(bytes32 patientId, uint16 year) external view returns (bool) {
        Coverage memory cv = _c[patientId];
        if (!cv.active) return false;
        if (cv.startYear != 0 && year < cv.startYear) return false;
        if (cv.endYear   != 0 && year > cv.endYear)   return false;
        return true;
    }
}
