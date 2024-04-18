import chai, { expect } from "chai";
import chaiAsPromised from "chai-as-promised";
chai.use(chaiAsPromised);

import Web3 from "web3";
import { cleanStruct, ganacheProvider, getLogs, receipientInfo } from "../../shared/utils";
import { prepareContracts } from "./amm-prepare";
import ammContracts from "../build";

describe('Test Constant Product AMM', function() {
  this.timeout(10000);

  const web3 = new Web3(ganacheProvider() as any);
  let g: Awaited<ReturnType<typeof prepareContracts>> = {} as any;

  this.beforeEach(async () => {
    g = await prepareContracts(web3);
  })
  this.afterEach(()=> {
    if (g.BankSubs) g.BankSubs.removeAllListeners();
    if (g.AccountSubs) g.AccountSubs.removeAllListeners();
    if (g.AMMSubs) g.AMMSubs.removeAllListeners();
  })

  async function placeLiquidity(amount1: number, amount2: number) {
    // credit the liquidity provider accounts
    await g.bank1.credit(g.bo1User.send(), g.lpAccount1.deployedAt, amount1, "credit");
    await g.bank2.credit(g.bo1User.send(), g.lpAccount2.deployedAt, amount2, "credit"); 

    // allow the amm to transfer the funds
    await g.lpAccount1.approve(g.lpUser.send(), g.amm.deployedAt, amount1);
    await g.lpAccount2.approve(g.lpUser.send(), g.amm.deployedAt, amount2);
    // place the liquidity in the AMM
    await g.amm.addLiquidity(g.lpUser.send(), g.lpAccount1.deployedAt, amount1, g.lpAccount2.deployedAt, amount2);
  }
  
  it('Can place liquidity', async () => {
    // place the liquidity in the AMM
    // 1 USD = 1.1 EUR
    await placeLiquidity(1_000_000, 1_100_000);

    // check the share received
    const shares = await g.amm.balanceOf(g.lpUser.call(), g.lpAddress);
    console.log("shares", shares);
    
  });

  it('Can make a swap', async () => {
    // place the liquidity in the AMM
    // 1 USD = 1.1 EUR
    await placeLiquidity(1_000_000, 1_100_000);
    
    // have user get a credit to its account
    await g.bank1.credit(g.bo1User.send(), g.userAccount1.deployedAt, 1_000, "credit");

    let [userEUR, userUSD, ammEUR, ammUSD] = await Promise.all([
      g.userAccount1.balance(g.user1.call()),
      g.userAccount2.balance(g.user1.call()),
      g.ammAccount1.balance(g.user1.call()),
      g.ammAccount2.balance(g.user1.call())
    ]);
    console.log("Before Swap:\n", "userEUR", userEUR, "userUSD", userUSD, "ammEUR", ammEUR, "ammUSD", ammUSD);

    // approve the AMM to transfer the funds
    await g.userAccount1.approve(g.bo1User.send(), g.amm.deployedAt, 1_000);

    // check the swapPrice
    let swapPrice = await g.amm.swapPrice(g.user1.call(), true, 1_000);
    console.log("swapPrice EUR/USD", swapPrice);
    swapPrice = await g.amm.swapPrice(g.user1.call(), false, 1_000);
    console.log("swapPrice USD/EUR", swapPrice);
    

    // swap 10 EUR to USD
    await g.amm.swap(g.user1.send(), g.userAccount1.deployedAt, 1_000, g.userAccount2.deployedAt);

    [userEUR, userUSD, ammEUR, ammUSD] = await Promise.all([
      g.userAccount1.balance(g.user1.call()),
      g.userAccount2.balance(g.user1.call()),
      g.ammAccount1.balance(g.user1.call()),
      g.ammAccount2.balance(g.user1.call())
    ]);
    console.log("After Swap:\n", "userEUR", userEUR, "userUSD", userUSD, "ammEUR", ammEUR, "ammUSD", ammUSD);

  });


  it('Can make a payment in one currency to another currency (PFX)', async () => {
    // deploy the FX OP contract
    const pFXContract = ammContracts.get("FXOp");
    const pFX = await pFXContract.deploy(g.user1.newi(), g.amm.deployedAt);

    // place the liquidity in the AMM
    await placeLiquidity(1_000_000, 1_100_000);

    // have user get a credit to its account in EUR
    await g.bank1.credit(g.bo1User.send(), g.userAccount1.deployedAt, 1_000, "credit");

    // make a transfer from the user EUR account to the USD account
    await g.userAccount1.approve(g.bo1User.send(), g.amm.deployedAt, 1_000);
    await pFX.transferWithFx(g.user1.send(), g.userAccount1.deployedAt, 1_000, g.userAccount2.deployedAt);
  });

});