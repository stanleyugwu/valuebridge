import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { ValueBridge, ValueBridge__factory, } from "../typechain-types";
import { solidity } from "ethereum-waffle";
import { BigNumberish } from "ethers";
import { JsonRpcSigner } from "@ethersproject/providers";

chai.use(solidity);

describe("ValueBridge contract", function () {
  // re-usable constants
  const utils = ethers.utils,
    provider = ethers.provider;

  // static constants to be used through out the test
  // Here, we setup and deploy the contract before any test is run
  let valueBridge: ValueBridge;
  let constructorArgs: [string, BigNumberish, BigNumberish] = [
    "Devvie",
    utils.parseEther("2"),
    utils.parseEther("3"),
  ];
  let VB: ValueBridge__factory, signer: JsonRpcSigner;

  this.beforeAll(async () => {
    signer = provider.getSigner(0);
    VB = await ethers.getContractFactory("ValueBridge", signer);
    valueBridge = await (await VB.deploy(...constructorArgs)).deployed();
  });

  it("Deployment should set deployer's name, wallet address, minimum transfer amount, and minimum withdrawal amount", async function () {
    expect(await valueBridge.ownerName()).to.equal(constructorArgs[0]);
    expect(await valueBridge.owner()).to.equal(await signer.getAddress());
    expect(await valueBridge.minTransferAmt()).to.equal(constructorArgs[1]);
    expect(await valueBridge.minWithdrawAmt()).to.equal(constructorArgs[2]);
  });

  it("Should receive ether that's up to the minimum amount successfully, through it's transfer function", async function () {
    const signer2 = provider.getSigner(1);

    const contractBalBeforeTransfer = await provider.getBalance(
      valueBridge.address
    );
    (
      await valueBridge
        .connect(signer2)
        .transfer("No Note", { value: utils.parseEther("4") })
    ).wait();
    const contractBalAfterTransfer = await provider.getBalance(
      valueBridge.address
    );

    // balance of contract after transfer should increase
    expect(contractBalBeforeTransfer.lt(contractBalAfterTransfer)).true;
  });

  it("Should reject funds not up to minimum transfer amount", async function () {
    // let's send fund lesser than 2 ether and make sure it rejects it
    // minimum is 2, let's send 1 and make sure it rejects
    await expect(
      valueBridge.transfer("No Note", { value: utils.parseEther("1") })
    ).to.be.revertedWith(
      `Sorry! you can only transfer ${constructorArgs[1]} Wei or more to ${constructorArgs[0]}`
    );
  });

  it("Should give error on withdrawal if the withdrawer is not the deployer", async function () {
    const anotherAcct = provider.getSigner(2);

    // let's stuff the contract with enough funds to be withdrawn
    await (
      await valueBridge.transfer("No note", { value: utils.parseEther("4") })
    ).wait();

    await expect(
      valueBridge.connect(anotherAcct).withdraw(utils.parseEther("15"))
    ).to.be.revertedWith(
      `Sorry! only ${constructorArgs[0]} can call this function`
    );
  });

  it("Should save some of the funds sent to it on behalf of the deployer", async function () {
    const ownerBal = await provider.getBalance(await signer.getAddress());
    const contractBal = await provider.getBalance(valueBridge.address);

    // we send 4 ether, then owner should be given two and contract saves two
    (
      await valueBridge
        .connect(provider.getSigner(3))
        .transfer("No note", { value: utils.parseEther("4") })
    ).wait();

    const newOwnerBal = await provider.getBalance(await signer.getAddress());
    const newContractBal = await provider.getBalance(valueBridge.address);

    expect(newOwnerBal.eq(ownerBal.add(utils.parseEther("2")))).to.true;
    expect(newContractBal.eq(contractBal.add(utils.parseEther("2")))).to.true;
  });

  it("Should withdraw funds to deployer on demand", async function () {
    const ownerBal = await provider.getBalance(await signer.getAddress());
    // await (await valueBridge.transfer("No Note", {value:utils.parseEther("10")})).wait();
    (await valueBridge.withdraw(utils.parseEther("1"))).wait();
    const newBal = await provider.getBalance(await signer.getAddress());

    // check if the previous bal is lesser than new balance
    expect(ownerBal.lt(newBal)).true;
    expect((await provider.getBalance(valueBridge.address)).isZero());
  });

  it("Should withdraw all contract balance if deployer request for more than the contract has", async function () {
    const ownerBal = await provider.getBalance(await signer.getAddress());
    await (
      await valueBridge.transfer("No Note", { value: utils.parseEther("10") })
    ).wait();
    (await valueBridge.withdraw(utils.parseEther("100000"))).wait();

    // check if the previous bal is lesser than new balance
    expect(ownerBal.lt(await provider.getBalance(await signer.getAddress())))
      .true;
  });

  it("Should reject withdrawal if the balance is not up to minimum withdrawal amount", async function () {
    // We re-deploy a fresh contract and try to withdraw
    valueBridge = await VB.deploy(...constructorArgs);

    // at this point the contract has 0 balance
    await expect(
      valueBridge.withdraw(utils.parseEther("5"))
    ).to.be.revertedWith(
      `Sorry! ${constructorArgs[0]} You can only withdraw when balance is up to ${constructorArgs[2]} Wei or more`
    );
  });
});
