import Web3 from "web3";
import crypto from "crypto";
import { SmartContractInstance } from "@saturn-chain/smart-contract";
import { EthProviderInterface } from "@saturn-chain/dlt-tx-data-functions";
import soCashContracts from "@so-cash/sc-so-cash"
import { blockTimestamp } from "./dates";
import { map } from "./utils";

export const contractsNames = {
  bank: "SoCashBank",
  account: "SoCashAccount",
  ibanCalc: "IBANCalculator",
  amm: "CPAMM",
  iBank: "ISoCashBank",
  iAccount: "ISoCashOwnedAccount",
}

export async function createAccount(name: string, inBank: SmartContractInstance, owner: EthProviderInterface): Promise<SmartContractInstance> {
  const accountContract = soCashContracts.get(contractsNames.account);
  const account = await accountContract.deploy(owner.newi(), name);
  map(account.deployedAt, name);
  await account.transferOwnership(owner.send(), inBank.deployedAt);
  await inBank.registerAccount(owner.send(), account.deployedAt);
  return account;
}

export async function createHTLCData() {
  const secret = crypto.randomBytes(32).toString("hex");
  const cancelSecret = crypto.randomBytes(32).toString("hex");
  const hash = Web3.utils.soliditySha3(secret) || "";
  const cancelHash = Web3.utils.soliditySha3(cancelSecret) || "";
  const tradeId = crypto.randomUUID();
  const blockTime = await blockTimestamp();
  const timeout = blockTime + 120; // 2 minute
  const id = ""; // to be filled later
  return { id, secret, cancelSecret, hash, cancelHash, tradeId, timeout };
}