// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


import {ISoCashOwnedAccount} from "@so-cash/sc-so-cash/src/intf/so-cash-account.sol";
import {CPAMM} from "../impl/cp-amm.sol";

contract FXOp {
    CPAMM public cpAmm;
    constructor(CPAMM _cpAmm) {
        cpAmm = _cpAmm;
    }

    function transferWithFx(ISoCashOwnedAccount from, uint256 amount, ISoCashOwnedAccount to) public {
      cpAmm.swap(from, amount, to);
    }
}