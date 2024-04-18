# Use of so|cash in constant product AMM

## Introduction

This repo does not contains all the code needed to compile but shared enough information to understand the way so|cash can be used in an AMM

## What is so|cash (in short)

For more info look at https://githib.com/so-cash

In so|cash model, banks have a smart contract to hold account balance of their client.  
Each bank has one smart contract (`SoCashBank`) for each currency they open accounts with.

Each client account is a separate smart contract (`ISoCashAccount` or `ISoCashOwnedAccount`) that extends `IERC20Metadata` that is registered in the `SoCashBank` and the address of which is the owner of the actual balance in the bank. 

## Using so|cash in AMM

The basic of the AMM is to work with pure `IERC20` tokens where the AMM address and the users addresses are the owners of the tokens.

In so|cash the balances must be owned by `SoCashAccount`s. So the AMM must have 2 accounts, one for each of the tokens pools (the balance of these accounts being the pool size). The users must have accounts in each of the currency the AMM is working with.

The AMM is therefore modified to accept `SoCashAccount` instead of `IERC20` tokens.

The AMM is created with the address of the 2 accounts of the AMM pool. And when the user whant to swap or add or remove liquidity, the AMM functions must receive the address of the user `SoCashAccount`s instead of the user address.

And similarly, the user accounts must receive an approval for the AMM address before calling the AMM function to the AMM can instruct a transfer from the user account.

