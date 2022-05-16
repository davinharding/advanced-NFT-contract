import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import MerkleTree from "merkletreejs";
import keccak256 from "keccak256";
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

describe("Mushy", () => {
  let mushyContract: Contract;
  let owner: SignerWithAddress;
  let address1: SignerWithAddress;
  let address2: SignerWithAddress;
  let address3: SignerWithAddress;
  let root: any;
  let tree: MerkleTree;

  beforeEach(async () => {
    const MushyFactory = await ethers.getContractFactory("Mushy");
    [owner, address1, address2, address3] = await ethers.getSigners();

    const leaves = [owner.address, address1.address, address2.address].map(
      (v) => keccak256(v)
    );
    tree = new MerkleTree(leaves, keccak256, { sort: true });
    root = tree.getHexRoot();

    mushyContract = await MushyFactory.deploy(root);
  });

  it("Should initialize Mushy Contract and check mint price is .08", async () => {
    const inWei = await mushyContract.item_price_public();
    expect(parseFloat(web3.utils.fromWei(inWei.toString(), "ether"))).to.equal(
      0.08
    );
  });

  it("Should set the right owner", async () => {
    expect(await mushyContract.owner()).to.equal(await owner.address);
  });

  it("Should allow whitelisted address to execute whitelist mint using proof, mint address balance should match # of mints executed", async () => {
    const leaf = keccak256(address1.address);
    const proof = tree.getHexProof(leaf);

    mushyContract.setAllowlistMintActive(true);

    mushyContract.connect(address1).allowlistMint(proof, 1, {
      value: ethers.utils.parseEther(".08"),
    });

    const balance = await mushyContract.balanceOf(address1.address);
    expect(balance.toNumber()).to.equal(1);
  });

  it("Should not allow more allowlist mints than allowlist_mint_max_per_tx allows", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    mushyContract.setAllowlistMintActive(true);

    await expect(
      mushyContract.allowlistMint(proof, 4, {
        value: ethers.utils.parseEther(".32"),
      })
    ).to.be.revertedWith("Requested mint amount invalid");
  });

  it("Should not allow whitelist mints with incorrect payment value", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    mushyContract.setAllowlistMintActive(true);

    await expect(
      mushyContract.allowlistMint(proof, 1, {
        value: ethers.utils.parseEther(".1"),
      })
    ).to.be.revertedWith("Not sufficient ETH to mint this number of NFTs");
  });

  it("Should not allow whitelist mints with invalid proof/root/leaf", async () => {
    const leaf = keccak256(address3.address); // address3 is not in the merkle tree
    const proof = tree.getHexProof(leaf);

    mushyContract.setAllowlistMintActive(true);

    await expect(
      mushyContract.allowlistMint(proof, 1, {
        value: ethers.utils.parseEther(".08"),
      })
    ).to.be.revertedWith("Invalid proof");
  });

  it("Should not allow whitelist mint if whitelist mint is not active", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    await expect(
      mushyContract.allowlistMint(proof, 2, {
        value: ethers.utils.parseEther(".16"),
      })
    ).to.be.revertedWith("Allowlist mint not active");
  });

  xit("Should not allow whitelist mint if if # of mints exceeds total supply - reservations", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    await expect(
      mushyContract.allowlistMint(proof, 3, {
        value: ethers.utils.parseEther(".24"),
      })
    ).to.be.revertedWith("Mint Amount Exceeds Total Allowed Mints");
  });

  xit("Should allow public mint from any address, mint address balance should match # of mints executed, max public mint per tx should not be exceeded", async () => {
    mushyContract.setPublicMintActive(true);

    await expect(
      mushyContract.publicMint(1, {
        value: ethers.utils.parseEther(".07"),
      })
    );

    const balance = await mushyContract.balanceOf(owner.address);
    expect(balance.toNumber()).to.equal(1);

    await expect(
      mushyContract.publicMint(2, {
        value: ethers.utils.parseEther(".14"),
      })
    ).to.be.reverted;
  });

  xit("Should not exceed max public mint per tx #", async () => {
    mushyContract.setPublicMintActive(true);

    await expect(
      mushyContract.publicMint(2, {
        value: ethers.utils.parseEther(".14"),
      })
    ).to.be.revertedWith("Requested Mint Amount Exceeds Limit Per Tx");
  });

  xit("Should not allow max supply to be exceeded during public mint", async () => {
    mushyContract.setPublicMintActive(true);

    mushyContract.publicMint(1, {
      value: ethers.utils.parseEther(".07"),
    });

    mushyContract.connect(address1).publicMint(1, {
      value: ethers.utils.parseEther(".07"),
    });

    await expect(
      mushyContract.connect(address2).publicMint(1, {
        value: ethers.utils.parseEther(".07"),
      })
    ).to.be.revertedWith("Mint Amount Exceeds Total Allowed Mints");
  });

  xit("Should not be allowed to public mint if it is not active", async () => {
    await expect(
      mushyContract.publicMint(1, {
        value: ethers.utils.parseEther(".07"),
      })
    ).to.be.revertedWith("mushy Public Mint Not Active");
  });

  xit("Should not be allowed to public mint with incorrect payment value", async () => {
    mushyContract.setPublicMintActive(true);

    await expect(
      mushyContract.publicMint(1, {
        value: ethers.utils.parseEther(".08"),
      })
    ).to.be.revertedWith("Incorrect Payment");
  });

  xit("Should allow reservation mint from any address inside reservations mapping, mint address balance should match # of mints executed", async () => {
    await expect(mushyContract.reservationMint(1));

    const balance = await mushyContract.balanceOf(owner.address);

    expect(balance.toNumber()).to.equal(1);
  });

  xit("Should not exceed allowance # of reservation mints", async () => {
    await expect(mushyContract.reservationMint(2)).to.be.revertedWith(
      "No Reservation for requested amount"
    );
  });

  xit("Should not exceed total reserved # of reservation mints ", async () => {
    mushyContract.reservationMint(1);

    await expect(
      mushyContract.connect(address1).reservationMint(1)
    ).to.be.revertedWith("Amount Exceeds Total Reserved");
  });

  xit("Should return unrevealerdURI if is_revealed === false", async () => {
    mushyContract.reservationMint(1);

    const testURI = await mushyContract.tokenURI(0);

    expect(testURI).to.equal("unrevealedURI.ipfs/");
  });

  xit("Should return revealerdURI + tokenID + .json if is_revealed === true", async () => {
    mushyContract.reservationMint(1);

    mushyContract.setIsRevealed(true);

    const testURI = await mushyContract.tokenURI(0);

    expect(testURI).to.equal("revealedURI.ipfs/0.json");
  });

  xit("Any ETH or ERC20 txns should be reverted", async () => {
    await expect(
      address1.sendTransaction({
        to: mushyContract.address,
        value: ethers.utils.parseEther("1"),
      })
    ).to.be.revertedWith(
      "Contract does not allow receipt of ETH or ERC-20 tokens"
    );
  });
});
