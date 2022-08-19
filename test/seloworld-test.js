const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("SeloWorld contract", function () {
  async function deployTokenFixture() {
    let seloWrld;
    let owner;
    let acc1;
    let acc2;

    const createAuction = async (_seloWrld, _acc) => {
      const baseURI = "https://token1.com/";
      const minPrice = ethers.utils.parseEther("1");
      const buyPrice = ethers.utils.parseEther("1");
      const tx = await seloWrld
        .connect(_acc)
        .CreateAuction(baseURI, minPrice, buyPrice);
      await tx.wait();
      return tx;
    };

    const SeloWrld = await ethers.getContractFactory("Seloworld");
    [owner, acc1, acc2] = await ethers.getSigners();
    seloWrld = await SeloWrld.deploy();
    return { SeloWrld, seloWrld, owner, acc1, acc2, createAuction };
  }

  it("should set the owner as a seller", async function () {
    const { owner, seloWrld } = await loadFixture(deployTokenFixture);
    expect(await seloWrld.salesMen(owner.address)).to.equal(true);
  });

  it("acc1 should mint 1 NFT", async function () {
    const { acc1, owner, seloWrld, createAuction } = await loadFixture(
      deployTokenFixture
    );
    const tx1 = await seloWrld.connect(acc1).GiveRightToAuction(acc1.address);
    await tx1.wait();
    expect(await seloWrld.salesMen(acc1.address)).to.equal(true);
    expect(await seloWrld.balanceOf(acc1.address)).to.equal(0);
    const tx2 = await createAuction(seloWrld, acc1);
    await tx2.wait();
    expect(await seloWrld.balanceOf(seloWrld.address)).to.equal(1);
  });
});
