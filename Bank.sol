// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./AccessControlled.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/**
 * ERC-20 vault (e.g., USDC on Base testnet). Only the ClaimEngine can instruct payments.
 */
contract Bank is AccessControlled {
    IERC20 public immutable token;
    address public engine;

    event EngineSet(address indexed engine);
    event PaymentExecuted(uint256 indexed claimId, address indexed to, uint256 amount, uint256 vaultBalanceAfter);
    event Recovered(address indexed token, address indexed to, uint256 amount);
    event RecoveredETH(address indexed to, uint256 amount);

    constructor(IERC20 _token) { token = _token; }

    function setEngine(address e) external onlyOwner {
        require(e != address(0), "engine=0");
        engine = e;
        emit EngineSet(e);
    }

    function pay(address to, uint256 amount, uint256 claimId) external {
        require(msg.sender == engine, "only engine");
        require(token.transfer(to, amount), "transfer failed");
        emit PaymentExecuted(claimId, to, amount, token.balanceOf(address(this)));
    }

    function vaultBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // Ops: recover stray tokens (not the primary vault token)
    function recoverToken(address other, address to, uint256 amount) external onlyOwner {
        require(other != address(token), "cannot recover vault token");
        require(to != address(0), "to=0");
        bool ok = IERC20(other).transfer(to, amount);
        require(ok, "recover transfer failed");
        emit Recovered(other, to, amount);
    }

    // Ops: recover native ETH if accidentally sent
    function recoverETH(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        (bool s, ) = to.call{value: amount}("");
        require(s, "recover eth failed");
        emit RecoveredETH(to, amount);
    }

    receive() external payable {}
}
