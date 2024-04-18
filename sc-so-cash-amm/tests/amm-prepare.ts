import Web3 from "web3";

import soCashContracts from "@so-cash/sc-so-cash";
import ammContracts from "../build";
import { map, traceEventLog, contractsNames, createAccount, getNewWallet  } from "@so-cash/sc-shared";


export async function prepareContracts(web3: Web3, ccy1: string="EUR", ccy2: string="USD", subs:boolean=true) {
  // check all contracts are present
  const contractNames = soCashContracts.names().concat(ammContracts.names());
  // console.log("Compilations contracts", contractNames);
  
  for (const contractName of Object.values(contractsNames)) {
    if (!contractNames.includes(contractName) ) {
      throw new Error(`Contract ${contractName} not found`);
    }
  }
  const bankContract = soCashContracts.get(contractsNames.bank);
  const accountContract = soCashContracts.get(contractsNames.account);
  const ibanCalcContract = soCashContracts.get(contractsNames.ibanCalc);
  const ammContract = ammContracts.get(contractsNames.amm);
  
  const bo1User = await getNewWallet(web3, "bankWallet1", true);
  const bank1Address = await bo1User.account();

  // subscribe and display all events
  const BankSubs = subs? bankContract.allEvents(bo1User.sub(), {}): undefined;
  if (BankSubs) BankSubs.on("log", traceEventLog("BK"));
  const AccountSubs = subs? accountContract.allEvents(bo1User.sub(), {}): undefined;
  if (AccountSubs) AccountSubs.on("log", traceEventLog("AC"));
  const AMMSubs = subs? ammContract.allEvents(bo1User.sub(), {}): undefined;
  if (AMMSubs) AMMSubs.on("log", traceEventLog("AMM"));

  // deploy the bank contracts

  const bank1 = await bankContract.deploy(bo1User.newi(), Buffer.from("AGRIFRPP"), Buffer.from("30002"), Buffer.from("05728"), Buffer.from(ccy1), 2);
  map(bank1.deployedAt, "Bank"+ccy1);
  const bank2 = await bankContract.deploy(bo1User.newi(), Buffer.from("AGRIFRPP"), Buffer.from("30002"), Buffer.from("05728"), Buffer.from(ccy2), 2);
  map(bank2.deployedAt, "Bank"+ccy2);

  // Add the IBAN calculator
  const ibanCalc = await ibanCalcContract.deploy(bo1User.newi());
  map(ibanCalc.deployedAt, "IBANCalc");
  await bank1.setIBANCalculator(bo1User.send(), ibanCalc.deployedAt);
  await bank2.setIBANCalculator(bo1User.send(), ibanCalc.deployedAt);

  // create the AMM accounts
  const ammAccount1 = await createAccount("AMM"+ccy1, bank1, bo1User);
  const ammAccount2 = await createAccount("AMM"+ccy2, bank2, bo1User);
  const amm = await ammContract.deploy(bo1User.newi(), ammAccount1.deployedAt, ammAccount2.deployedAt);
  map(amm.deployedAt, "AMM");
  // whitelist the AMM on its accounts
  await ammAccount1.whitelist(bo1User.send(), amm.deployedAt);
  await ammAccount2.whitelist(bo1User.send(), amm.deployedAt);

  // create a liquidity provider and its accounts
  const lpUser = await getNewWallet(web3, "lpWallet");
  const lpAddress = await lpUser.account();
  const lpAccount1 = await createAccount("LP"+ccy1, bank1, bo1User);
  const lpAccount2 = await createAccount("LP"+ccy2, bank2, bo1User);
  // whitelist the LP on its accounts
  await lpAccount1.whitelist(bo1User.send(), lpAddress);
  await lpAccount2.whitelist(bo1User.send(), lpAddress);

  // create a user account that will use the AMM and its accounts
  const user1 = await getNewWallet(web3, "userWallet1");
  const user1Address = await user1.account();
  const userAccount1 = await createAccount("User1"+ccy1, bank1, bo1User);
  const userAccount2 = await createAccount("User1"+ccy2, bank2, bo1User);
  // whitelist the user on its accounts
  await userAccount1.whitelist(bo1User.send(), user1Address);
  await userAccount2.whitelist(bo1User.send(), user1Address);

  return { bankContract, accountContract, ammContract, bank1, bank2, user1, lpUser, bank1Address, lpAddress, user1Address, bo1User, BankSubs, AccountSubs, AMMSubs, amm, ammAccount1, ammAccount2, lpAccount1, lpAccount2, userAccount1, userAccount2};
}
