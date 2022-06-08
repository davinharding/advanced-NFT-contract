import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import MerkleTree from "merkletreejs";
import keccak256 from "keccak256";
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

describe("AdvancedNftContract", () => {
  let advancedNftContractContract: Contract;
  let owner: SignerWithAddress;
  let address1: SignerWithAddress;
  let address2: SignerWithAddress;
  let address3: SignerWithAddress;
  let root: any;
  let tree: MerkleTree;

  beforeEach(async () => {
    const AdvancedNftContractFactory = await ethers.getContractFactory(
      "AdvancedNftContract"
    );
    [owner, address1, address2, address3] = await ethers.getSigners();

    const leaves = [owner.address, address1.address, address2.address].map(
      (v) => keccak256(v)
    );
    tree = new MerkleTree(leaves, keccak256, { sort: true });
    root = tree.getHexRoot();

    advancedNftContractContract = await AdvancedNftContractFactory.deploy(root);
  });

  xit("Should initialize AdvancedNftContract Contract and check mint price is .08", async () => {
    const inWei = await advancedNftContractContract.item_price_public();
    expect(parseFloat(web3.utils.fromWei(inWei.toString(), "ether"))).to.equal(
      0.08
    );
  });

  xit("Should set the right owner", async () => {
    expect(await advancedNftContractContract.owner()).to.equal(
      await owner.address
    );
  });

  xit("Should allow whitelisted address to execute whitelist mint using proof, mint address balance should match # of mints executed", async () => {
    const leaf = keccak256(address1.address);
    const proof = tree.getHexProof(leaf);

    advancedNftContractContract.setAllowlistMintActive(true);

    advancedNftContractContract.connect(address1).allowlistMint(proof, 1, {
      value: ethers.utils.parseEther(".08"),
    });

    const balance = await advancedNftContractContract.balanceOf(
      address1.address
    );
    expect(balance.toNumber()).to.equal(1);
  });

  xit("Should not allow more allowlist mints than allowlist_mint_max_per_tx allows", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    advancedNftContractContract.setAllowlistMintActive(true);

    await expect(
      advancedNftContractContract.allowlistMint(proof, 4, {
        value: ethers.utils.parseEther(".32"),
      })
    ).to.be.revertedWith("Requested mint amount invalid");
  });

  xit("Should not allow whitelist mints with incorrect payment value", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    advancedNftContractContract.setAllowlistMintActive(true);

    await expect(
      advancedNftContractContract.allowlistMint(proof, 1, {
        value: ethers.utils.parseEther(".1"),
      })
    ).to.be.revertedWith("Not sufficient ETH to mint this number of NFTs");
  });

  xit("Should not allow whitelist mints with invalid proof/root/leaf", async () => {
    const leaf = keccak256(address3.address); // address3 is not in the merkle tree
    const proof = tree.getHexProof(leaf);

    advancedNftContractContract.setAllowlistMintActive(true);

    await expect(
      advancedNftContractContract.allowlistMint(proof, 1, {
        value: ethers.utils.parseEther(".08"),
      })
    ).to.be.revertedWith("Invalid proof");
  });

  xit("Should not allow whitelist mint if whitelist mint is not active", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    await expect(
      advancedNftContractContract.allowlistMint(proof, 2, {
        value: ethers.utils.parseEther(".16"),
      })
    ).to.be.revertedWith("Allowlist mint not active");
  });

  xit("Should not allow whitelist mint if if # of mints exceeds total supply - reservations", async () => {
    const leaf = keccak256(owner.address);
    const proof = tree.getHexProof(leaf);

    await expect(
      advancedNftContractContract.allowlistMint(proof, 3, {
        value: ethers.utils.parseEther(".24"),
      })
    ).to.be.revertedWith("Mint Amount Exceeds Total Allowed Mints");
  });

  xit("Should allow public mint from any address, mint address balance should match # of mints executed, max public mint per tx should not be exceeded", async () => {
    advancedNftContractContract.setPublicMintActive(true);

    await expect(
      advancedNftContractContract.publicMint(1, {
        value: ethers.utils.parseEther(".08"),
      })
    );

    const balance = await advancedNftContractContract.balanceOf(owner.address);
    expect(balance.toNumber()).to.equal(1);

    await expect(
      advancedNftContractContract.publicMint(5, {
        value: ethers.utils.parseEther(".40"),
      })
    ).to.be.reverted;
  });

  xit("Should not exceed max public mint per tx #", async () => {
    advancedNftContractContract.setPublicMintActive(true);

    await expect(
      advancedNftContractContract.publicMint(2, {
        value: ethers.utils.parseEther(".14"),
      })
    ).to.be.revertedWith("Requested Mint Amount Exceeds Limit Per Tx");
  });

  xit("Should not allow max supply to be exceeded during public mint", async () => {
    advancedNftContractContract.setPublicMintActive(true);

    advancedNftContractContract.publicMint(1, {
      value: ethers.utils.parseEther(".08"),
    });

    advancedNftContractContract.connect(address1).publicMint(1, {
      value: ethers.utils.parseEther(".08"),
    });

    await expect(
      advancedNftContractContract.connect(address2).publicMint(1, {
        value: ethers.utils.parseEther(".08"),
      })
    ).to.be.revertedWith("Mint Amount Exceeds Total Allowed Mints");
  });

  xit("Should not be allowed to public mint if it is not active", async () => {
    await expect(
      advancedNftContractContract.publicMint(1, {
        value: ethers.utils.parseEther(".07"),
      })
    ).to.be.revertedWith("advancedNftContract Public Mint Not Active");
  });

  xit("Should not be allowed to public mint with incorrect payment value", async () => {
    advancedNftContractContract.setPublicMintActive(true);

    await expect(
      advancedNftContractContract.publicMint(1, {
        value: ethers.utils.parseEther(".08"),
      })
    ).to.be.revertedWith("Incorrect Payment");
  });

  xit("Should allow reservation mint from any address inside reservations mapping, mint address balance should match # of mints executed", async () => {
    await expect(advancedNftContractContract.reservationMint(1));

    const balance = await advancedNftContractContract.balanceOf(owner.address);

    expect(balance.toNumber()).to.equal(1);
  });

  xit("Should not exceed allowance # of reservation mints", async () => {
    await expect(
      advancedNftContractContract.reservationMint(2)
    ).to.be.revertedWith("No Reservation for requested amount");
  });

  xit("Should not exceed total reserved # of reservation mints ", async () => {
    advancedNftContractContract.reservationMint(1);

    await expect(
      advancedNftContractContract.connect(address1).reservationMint(1)
    ).to.be.revertedWith("Amount Exceeds Total Reserved");
  });

  xit("Should return unrevealerdURI if is_revealed === false", async () => {
    advancedNftContractContract.reservationMint(1);

    const testURI = await advancedNftContractContract.tokenURI(0);

    expect(testURI).to.equal("unrevealedURI.ipfs/");
  });

  xit("Should return revealerdURI + tokenID + .json if is_revealed === true", async () => {
    advancedNftContractContract.reservationMint(1);

    advancedNftContractContract.setIsRevealed(true);

    const testURI = await advancedNftContractContract.tokenURI(0);

    expect(testURI).to.equal("revealedURI.ipfs/0.json");
  });

  xit("Any ETH or ERC20 txns should be reverted", async () => {
    await expect(
      address1.sendTransaction({
        to: advancedNftContractContract.address,
        value: ethers.utils.parseEther("1"),
      })
    ).to.be.revertedWith(
      "Contract does not allow receipt of ETH or ERC-20 tokens"
    );
  });

  xit("Should should shuffle _randomNumbers array such that tokenURI function returns a different URI after shuffler is run", async () => {
    const randomSeed = ethers.BigNumber.from("7854166079704491"); // this can be supplied off chain or via chainliink vrf

    advancedNftContractContract.setPublicMintActive(true);

    await expect(
      advancedNftContractContract.publicMint(1, {
        value: ethers.utils.parseEther(".08"),
      })
    );

    await advancedNftContractContract.setIsRevealed(true);

    const tokenURI = await advancedNftContractContract.tokenURI(0);

    const oldArray = await advancedNftContractContract.getRandomNumbersArray();

    await advancedNftContractContract.shuffler(randomSeed);

    const newTokenURI = await advancedNftContractContract.tokenURI(0);

    const newArray = await advancedNftContractContract.getRandomNumbersArray();

    oldArray.forEach((e: number) => {
      // console.log(e, newArray[e - 1]);
      expect(e).to.not.equal(newArray[e - 1]);
    });

    expect(tokenURI).to.not.equal(newTokenURI);
  });

  it("Should refund such that owner receives eth and no longer owns token, refund_address now has token", async () => {
    advancedNftContractContract.setPublicMintActive(true);

    await advancedNftContractContract.connect(address1).publicMint(1, {
      value: ethers.utils.parseEther(".08"),
    });

    const balanceBefore = await ethers.provider.getBalance(address1.address);

    await advancedNftContractContract.setRefundActive(true);

    await advancedNftContractContract
      .connect(address1)
      .refund(address1.address, 0);

    const balanceAfter = await ethers.provider.getBalance(address1.address);

    // Asserts that after refund the current owner of token minted by address1 is returnAddress
    expect(await advancedNftContractContract.ownerOf(0)).to.equal(
      await advancedNftContractContract.returnAddress()
    );

    // Asserts that balanceBefore - balanceAfter is at least price * 2*admin_percentage
    expect(
      parseFloat(ethers.utils.formatEther(balanceAfter)) -
        parseFloat(ethers.utils.formatEther(balanceBefore))
    ).to.be.greaterThan(
      parseFloat(
        ethers.utils.formatEther(
          await advancedNftContractContract.item_price_public()
        )
      ) *
        // Double admin fee is to account for gas spend during txns
        ((100 - 2 * (await advancedNftContractContract.admin_percentage())) /
          100)
    );
  });

  /*

  New Tests to add to Complete Refund Mechanism

  1)  Test _tokenData's ability to hold multiple prices

  */

  it("Should refund the correct amount regardless of mint price", async () => {
    /*     
      PUBLIC MINT/REFUND BLOCK
    */
    advancedNftContractContract.setPublicMintActive(true);
    await advancedNftContractContract.connect(address1).publicMint(1, {
      value: ethers.utils.parseEther(".08"),
    });
    const balanceBeforeAdd1 = await ethers.provider.getBalance(
      address1.address
    );
    await advancedNftContractContract.setRefundActive(true);
    await advancedNftContractContract
      .connect(address1)
      .refund(address1.address, 0);
    const balanceAfterAdd1 = await ethers.provider.getBalance(address1.address);
    /*
      END PUBLIC BLOCK
    */
    /*
      ALLOWLIST MINT/REFUND BLOCK
    */
    advancedNftContractContract.setAllowlistMintActive(true);
    const leaf = keccak256(address2.address);
    const proof = tree.getHexProof(leaf);
    await advancedNftContractContract
      .connect(address2)
      .allowlistMint(proof, 1, {
        value: ethers.utils.parseEther(".06"),
      });
    const balanceBeforeAdd2 = await ethers.provider.getBalance(
      address2.address
    );

    await advancedNftContractContract
      .connect(address2)
      .refund(address2.address, 1);
    const balanceAfterAdd2 = await ethers.provider.getBalance(address2.address);
    /*
      END ALLOWLIST BLOCK
    */
    /*
      ASSERTIONS BLOCK
    */
    // Asserts that after refund the current owner of tokens minted is returnAddress
    expect(await advancedNftContractContract.ownerOf(0)).to.equal(
      await advancedNftContractContract.returnAddress()
    );

    expect(await advancedNftContractContract.ownerOf(1)).to.equal(
      await advancedNftContractContract.returnAddress()
    );

    // Asserts that balanceBefore - balanceAfter is at least price * 2*admin_percentage - Public Mint Example
    expect(
      parseFloat(ethers.utils.formatEther(balanceAfterAdd1)) -
        parseFloat(ethers.utils.formatEther(balanceBeforeAdd1))
    ).to.be.greaterThan(
      parseFloat(
        ethers.utils.formatEther(
          await advancedNftContractContract.item_price_public()
        )
      ) *
        // Double admin fee is to account for gas spend during txns
        ((100 - 2 * (await advancedNftContractContract.admin_percentage())) /
          100)
    );

    // Asserts that balanceBefore - balanceAfter is at least price * 2*admin_percentage - Allowlist Mint Example
    expect(
      parseFloat(ethers.utils.formatEther(balanceAfterAdd2)) -
        parseFloat(ethers.utils.formatEther(balanceBeforeAdd2))
    ).to.be.greaterThan(
      parseFloat(
        ethers.utils.formatEther(
          await advancedNftContractContract.item_price_al()
        )
      ) *
        // Double admin fee is to account for gas spend during txns
        ((100 - 2 * (await advancedNftContractContract.admin_percentage())) /
          100)
    );
  });

  it("Should not allow transfers when switch is turned off", async () => {
    advancedNftContractContract.setPublicMintActive(true);

    await advancedNftContractContract.connect(address1).publicMint(1, {
      value: ethers.utils.parseEther(".08"),
    });

    await advancedNftContractContract.setAllTransfersDisabled(true);

    await expect(
      advancedNftContractContract
        .connect(address1)
        .transferFrom(address1.address, address2.address, 0)
    ).to.be.revertedWith("AllTransfersHaveBeenDisabled");
  });
});
