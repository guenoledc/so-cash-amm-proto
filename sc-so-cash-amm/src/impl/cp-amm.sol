// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISoCashOwnedAccount} from "@so-cash/sc-so-cash/src/intf/so-cash-account.sol";

/**
 * @title Constant Product AMM Smart contract
 * @author Al-Qa'qa'
 * @notice This contract works as a simple AMM using Constant product (XY = K) Algorism
 */
contract CPAMM {
  event LiquidityAdded(
    address provider,
    uint256 token0AmountAdded,
    uint256 token1AmountAdded
  );

  event Swapped(
    address swapper,
    address tokenIn,
    uint256 amountIn,
    address tokenOut,
    uint256 amountOut
  );

  event LiquidityRemoved(
    address provider,
    uint256 token0AmountRemoved,
    uint256 token1AmountRemoved
  );

  //////////////
  /// Errors ///
  //////////////

  error CPAMM__InvalidToken(address token);
  error CPAMM__SharesEqualZero(uint256 shares);
  error CPAMM__InputAmountEqualZero();
  error CPAMM__PriceWillChange(uint256 amount0, uint256 amount1);
  error CPAMM__OneAmountEqualZero(uint256 amount0, uint256 amount1);

  /////////////////
  /// Variables ///
  /////////////////

  ISoCashOwnedAccount private immutable _i_account0;
  ISoCashOwnedAccount private immutable _i_account1;

  uint256 private _reserve0;
  uint256 private _reserve1;

  uint256 private _totalSupply;

  mapping(address => uint256) public balanceOf;

  /////////////////////////////////
  /// Modifiers and Constructor ///
  /////////////////////////////////

  /**
   * @notice deploy the contract and add the two token addresses provider to be in the pool
   *
   * @param _account0 The first so cash account of the pair
   * @param _account1 The second so cash account of the pair
   */
  constructor(ISoCashOwnedAccount _account0, ISoCashOwnedAccount _account1) {
    _i_account0 = _account0;
    _i_account1 = _account1;
  }

  ///////////////////////////////////////////////
  //////// external and public function /////////
  ///////////////////////////////////////////////

  function swapPrice(bool _isToken0, uint256 _amountIn) public view returns (uint256 amountOut, uint256 feeIn) {

    (uint256 resIn, uint256 resOut) = _isToken0
      ? (_reserve0, _reserve1)
      : (_reserve1, _reserve0);

    // Calculate amount out + our fees (0.5% fee)
    uint256 amountInWithFees = (_amountIn * 995) / 1000;
    feeIn = _amountIn - amountInWithFees;

    // We determine the amountOut by this equaltion {dy = (dx * Y) / (x + dx)}
    // For more information review constant product AMM Algorism
    amountOut = ((amountInWithFees * resOut) / (resIn + amountInWithFees));
  }

  /**
   * @notice swap token in the pool for the other token
   * @dev token must be one of the two token addresses we definied in the constructor
   *
   * @param _accountIn the token that will be swapped
   * @param _amountIn the amount of tokens to swap
   */
  function swap(
    ISoCashOwnedAccount _accountIn,
    uint256 _amountIn,
    ISoCashOwnedAccount _accountOut
  ) external returns (uint256 amountOut) {
    bool isToken0 = compareAccount(_accountIn, _i_account0);
    bool isToken1 = compareAccount(_accountIn, _i_account1);
    if (!isToken0 && !isToken1) {
      revert CPAMM__InvalidToken(address(_accountIn));
    }
    // the output token must be the other one
    if (isToken0 && !compareAccount(_accountOut, _i_account1)) {
      revert CPAMM__InvalidToken(address(_accountOut));
    }
    if (isToken1 && !compareAccount(_accountOut, _i_account0)) {
      revert CPAMM__InvalidToken(address(_accountOut));
    }
    
    if (_amountIn == 0) {
      revert CPAMM__InputAmountEqualZero();
    }

    /*
      - There is no condition to check liquidity before swapping
      - If you swapped with 0 liquidity your tokens will be taken for nothing, and you can't change the liquidity price again
      - So you must add a liquidity (valid liquidity) before doing a swap function
    */

    (ISoCashOwnedAccount tokenIn, ISoCashOwnedAccount tokenOut, uint256 resIn) = isToken0
      ? (_i_account0, _i_account1, _reserve0)
      : (_i_account1, _i_account0, _reserve1);

    // Transfer token In. The AMM address should be approved to transfer the token
    _accountIn.transferFrom(msg.sender, address(tokenIn), _amountIn);
    uint256 amountIn = tokenIn.balanceOf(address(this)) - resIn; // This should be equal to `_amountIn` value

    // Calculate amount out + our fees (0.5% fee)
    (amountOut, ) = swapPrice(isToken0, amountIn);

    // Transfer tokens to the user
    tokenOut.transfer(address(_accountOut), amountOut);

    // update `reserve0` and `reserve1`
    _update(
      _i_account0.balanceOf(address(this)),
      _i_account1.balanceOf(address(this))
    );

    // console.log("CPAMM token0 balance:", tokenIn.balanceOf(address(this)));
    // console.log("CPAMM token1 balance:", tokenOut.balanceOf(address(this)));
    // console.log("reserve0:", getReserve0());
    // console.log("reserve1:", getReserve1());
    // console.log("Swapper token0 balance:", tokenIn.balanceOf(msg.sender));
    // console.log("Swapper token1 balance:", tokenOut.balanceOf(msg.sender));
    // console.log("totalSupply", getTotalSupply());

    emit Swapped(
      msg.sender,
      address(tokenIn),
      _amountIn,
      address(tokenOut),
      amountOut
    );
  }

  /**
   * @notice add new tokens into the liquidity pool
   * @dev This contract behaves that token0 and token1 are swaped in ration 1 : 1
   *
   * @param _amount0 first token amount to add to the liquidity pool
   * @param _amount1 secnod token amount to add to the liquidity pool
   */
  function addLiquidity(
    ISoCashOwnedAccount _account0,
    uint256 _amount0,
    ISoCashOwnedAccount _account1,
    uint256 _amount1
  ) external returns (uint256 shares) {
    // ensure token compatibility first
    if (!compareAccount(_account0, _i_account0)) {
      revert CPAMM__InvalidToken(address(_account0));
    }
    if (!compareAccount(_account1, _i_account1)) {
      revert CPAMM__InvalidToken(address(_account1));
    } 
    // Transfer tokens to our accounts
    _account0.transferFrom(msg.sender, address(_i_account0), _amount0);
    _account1.transferFrom(msg.sender, address(_i_account1), _amount1);

    /*
      dy / dx = y = x
    */

    // If one scammer made the pair to zero it will make a bug, but making swapping to zero value is non-sense
    if (_reserve0 > 0 || _reserve1 > 0) {
      if (_reserve0 * _amount1 != _reserve1 * _amount0) {
        revert CPAMM__PriceWillChange(_amount0, _amount1);
      }
    }

    /*
      Mint Shares
      f(x, y) = value of liquidiy = sqrt(xy)
      s = (dx / x) * T = (dy / y) * T
    */

    if (_totalSupply == 0) {
      // shares are the square root of the  product of the two token pairs
      shares = _sqrt(_amount0 * _amount1);
    } else {
      // If there is already a liquidity, you don't have to take the swuare root, to save some gas
      // But you should check the price will not change when adding liquidity
      shares = _min(
        (_amount0 * _totalSupply) / _reserve0,
        (_amount1 * _totalSupply) / _reserve1
      );
    }

    if (shares <= 0) revert CPAMM__SharesEqualZero(shares);

    // Add new tokens to the user who called the addLiquidity function
    _mint(msg.sender, shares);

    // Update the reserved value in our contract
    _update(
      _i_account0.balanceOf(address(this)),
      _i_account1.balanceOf(address(this))
    );

    // console.log("Liquidity Provider token0:", _i_account0.balanceOf(msg.sender));
    // console.log("Liquidity Provider token1:", _i_account1.balanceOf(msg.sender));
    // console.log("Liquidity Provider shares:", balanceOf[msg.sender]);

    emit LiquidityAdded(msg.sender, _amount0, _amount1);
  }

  /**
   * @notice remove pair of tokens from the liquidity pool
   *
   * @param _shares Amount of tokens (from the two tokens) that will be removed
   * @return amount0 The removed value of the first token
   * @return amount1 The removed value of the second token
   */
  function removeLiquidity(
    uint256 _shares,
    ISoCashOwnedAccount _account0,
    ISoCashOwnedAccount _account1
  ) external returns (uint256 amount0, uint256 amount1) {
    // ensure token compatibility first
    if (!compareAccount(_account0, _i_account0)) {
      revert CPAMM__InvalidToken(address(_account0));
    }
    if (!compareAccount(_account1, _i_account1)) {
      revert CPAMM__InvalidToken(address(_account1));
    }

    if (balanceOf[msg.sender] == 0) {
      revert CPAMM__SharesEqualZero(balanceOf[msg.sender]);
    }
    /*
      dx = (s * x) / T
      dy = (s * y) / T
    */

    uint256 bal0 = _i_account0.balanceOf(address(this));
    uint256 bal1 = _i_account1.balanceOf(address(this));

    amount0 = (bal0 * _shares) / _totalSupply;
    amount1 = (bal1 * _shares) / _totalSupply;

    if (amount0 == 0 && amount1 == 0) {
      revert CPAMM__OneAmountEqualZero(amount0, amount1);
    }

    _burn(msg.sender, _shares);
    _update(bal0 - amount0, bal1 - amount1);

    _i_account0.transfer(address(_account0), amount0);
    _i_account1.transfer(address(_account1), amount1);

    emit LiquidityRemoved(msg.sender, amount0, amount1);
  }

  ///////////////////////////////////////////////
  //////// private and internal function ////////
  ///////////////////////////////////////////////

  /**
   * @notice mint new tokens and add it to a given address
   * @dev there is no acutal minting in token, just the user info updated in our contracr
   * @dev minting increases the `totalSupply` of the contract
   *
   * @param _to Address that will receive the minted tokens
   * @param _amount the amount of tokens to be minted
   */
  function _mint(address _to, uint256 _amount) private {
    // console.log("The Amount to be added to ", _to, ": ", _amount);
    balanceOf[_to] += _amount;
    _totalSupply += _amount;
  }

  /**
   * @notice burn  tokens and remove it from a given address
   * @dev there is no acutal burning in token, just the user info updated in our contracr
   * @dev burning decreases the `totalSupply` of the contract
   *
   * @param _from Address that the tokens will be burned from
   * @param _amount the amount of tokens to be burned
   */
  function _burn(address _from, uint256 _amount) private {
    balanceOf[_from] -= _amount;
    _totalSupply -= _amount;
  }

  /**
   * @notice update the value of the reserved tokens
   *
   * @param _res0 new value of the first token pair reserved value
   * @param _res1 new value of the second token pair reserved value
   */
  function _update(uint256 _res0, uint256 _res1) private {
    _reserve0 = _res0;
    _reserve1 = _res1;
  }

  /**
   * @notice getting square root of the given number
   *
   * @param y the number to get its square root
   */
  function _sqrt(uint y) private pure returns (uint z) {
    if (y > 3) {
      z = y;
      uint x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }

  function _min(uint x, uint y) private pure returns (uint) {
    return x <= y ? x : y;
  }

  ///////////////////////////////////////////////
  /////// Getter, View, and Pure function ///////
  ///////////////////////////////////////////////

  function compareAccount(ISoCashOwnedAccount _our, ISoCashOwnedAccount _their) private view returns (bool) {
    bool symbolOk = keccak256(abi.encodePacked(_our.symbol())) == keccak256(abi.encodePacked(_their.symbol()));
    bool decimalsOk = _our.decimals() == _their.decimals();
    return symbolOk && decimalsOk;
  }

  // returns the address of the socash account of the first token
  function getToken0Address() public view returns (address) {
    return address(_i_account0);
  }

  // returns the address of the socash account of the second token
  function getToken1Address() public view returns (address) {
    return address(_i_account1);
  }

  /// @notice returns the totalSupply of tokens in the contract
  /// @dev this supply represends first pair + second pair supply
  function getTotalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  /// @notice return the value of tokens of the first pair
  function getReserve0() public view returns (uint256) {
    return _reserve0;
  }

  /// @notice return the value of tokens of the second pair
  function getReserve1() public view returns (uint256) {
    return _reserve1;
  }
}