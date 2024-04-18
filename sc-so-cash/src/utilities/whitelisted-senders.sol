// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IWhitelistedSenders {
    function isWhitelisted(address sender) external view returns (bool);
    function whitelist(address newSender) external;
    function blacklist(address oldSender) external;
}

contract WhitelistedSenders is Ownable {
    mapping(address => bool) private _whitelistedSenders;
    event Whitelisted(address indexed account, bool status);
    constructor() {
    }

    modifier onlyWhitelisted() {
        require(
            msg.sender == owner() || 
            _whitelistedSenders[msg.sender],
            "WLS: Caller not allowed to perform the action"
        );
        _;
    }

    function isWhitelisted(address a) public view virtual returns (bool) {
        return a == owner() || _whitelistedSenders[a];
    }

    function whitelist(address newSender) onlyWhitelisted() public virtual onlyWhitelisted {
        _whitelistedSenders[newSender] = true;
        emit Whitelisted(newSender, true);
    }

    function blacklist(address oldSender) onlyWhitelisted() public virtual onlyWhitelisted {
        _whitelistedSenders[oldSender] = false;
        emit Whitelisted(oldSender, false);
    }
}
