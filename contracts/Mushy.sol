// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";

import "hardhat/console.sol";

pragma solidity ^0.8.0;

// Error functions - converted form require strings to save memory

error RefundPeriodNotActive();
error RefundToZeroAddressNotAllowed();
error RefundCalledNotOwner();
error TokenHasAlreadyBeenRefunded();
error TokenWasFreeMint();
error RefundUnsuccessful();
error ContractDoesNotAllowReceiptOfTokens();
error AnIncorrectFunctionWasCalled();
error AllTransfersHaveBeenDisabled();

contract Mushy is ERC721A, Ownable, ReentrancyGuard {
    // declares the maximum amount of tokens that can be minted
    uint256 public constant MAX_TOTAL_TOKENS = 5555;

    // max number of mints per transaction
    uint256 public allowlist_mint_max_per_tx = 3;
    uint256 public pub_mint_max_per_tx = 3;

    // price of mints depending on state of sale
    uint256 public item_price_al = 0.06 ether;
    uint256 public item_price_public = 0.08 ether;

    // merkle root for allowlist
    bytes32 public root;

    // metadata
    string private baseURI = "test"; // Change to real base URI for new project
    string private unrevealedURI = "ipfs://QmbTe5jr8jJoTHtMVLH6dYmaHD7iGm2HdUNV3dRT5Fjeo8";

    // status
    bool public is_allowlist_active;
    bool public is_public_mint_active;
    bool public is_revealed;
    bool public is_refund_active;    
    bool public allTransfersDisabled;

    // reserved mints for the team
    mapping (address => uint256) reserved_mints;
    uint256 public total_reserved = 675;

    // array that will be created by shuffler function to randomly associated token id to metadata index
    uint256[] private _randomNumbers;

    // Define tokenData data structure
    struct TokenData {
      // Has token been refunded already?
      bool refunded;
      // What price was paid by minter
      uint256 price;
    }

    // Mapping of tokenId to tokenData
    mapping(uint256 => TokenData) internal _tokenData;

    // Refund admin fee, an integer representing a percentage should probably not be changeable to increase trust
    uint256 public admin_percentage;

    // Return address for refunded NFTs, set in the constructor to contract owner's address
    address private _return_address;

    // Tracks current index for use in assigning metadata in mint functions
    uint256 internal _currIndex;

    using Strings for uint256;

    constructor (bytes32 _root) ERC721A("Mushy NFT", "Mushy") {
        root = _root;
        // Initalize refund address to contract owner
        _return_address = _msgSender();
        // Initialize percentage to 10%
        admin_percentage = 10;
        // Initialize to 0
        _currIndex = 0;

      // Commented below as it is resource intensive and easier to test other functionality with out it for now

      // // Initialize array with values 1 -> MAX_TOTAL_TOKENS
      // for(uint i = 1; i <= MAX_TOTAL_TOKENS; i++) {
      //     _randomNumbers.push(i);
      // }

        // don't forget to update total_reserved
        reserved_mints[0x4Ac2bD3b9Af192456A416de78E9E124d4FA6c399] = 120;
        reserved_mints[0x10b5B489E9b4d220Ab6e4a0E7276c54D5bf837cD] = 555;
    }

    function internalMint(uint256 _amt) external nonReentrant {
        uint256 amt_reserved = reserved_mints[msg.sender];

        require(totalSupply() + _amt <= MAX_TOTAL_TOKENS, "Not enough NFTs left to mint");
        require(amt_reserved >= _amt, "Invalid reservation amount");
        require(amt_reserved <= total_reserved, "Amount exceeds total reserved");

        reserved_mints[msg.sender] -= _amt;
        total_reserved -= _amt;

        _safeMint(msg.sender, _amt);

        // Below keeps track of _currIndex and associates price data within mapping
        for(uint i = 0; i<_amt; i++) {          
          _tokenData[_currIndex].price = 0;
          _currIndex++;
        }        
    }

    function allowlistMint(bytes32[] calldata _proof, uint256 _amt) external payable nonReentrant {
        require(totalSupply() + _amt <= MAX_TOTAL_TOKENS - total_reserved, "Not enough NFTs left to mint");
        require(msg.sender == tx.origin, "Minting from contract not allowed");
        require(item_price_al * _amt == msg.value,  "Not sufficient ETH to mint this number of NFTs");
        require(is_allowlist_active, "Allowlist mint not active");

        uint64 new_claim_total = _getAux(msg.sender) + uint64(_amt);
        require(new_claim_total <= allowlist_mint_max_per_tx, "Requested mint amount invalid");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_proof, root, leaf), "Invalid proof");

        _setAux(msg.sender, new_claim_total);
        _safeMint(msg.sender, _amt);

        // Below keeps track of _currIndex and associates price data within mapping
        for(uint i = 0; i<_amt; i++) {          
          _tokenData[_currIndex].price = item_price_al;
          _currIndex++;
        }  
    }

    function publicMint(uint256 _amt) external payable nonReentrant {
        require(totalSupply() + _amt <= MAX_TOTAL_TOKENS - total_reserved, "Not enough NFTs left to mint");
        require(msg.sender == tx.origin, "Minting from contract not allowed");
        require(item_price_public * _amt == msg.value, "Not sufficient ETH to mint this number of NFTs");
        require(is_public_mint_active, "Public mint not active");
        require(_amt <= pub_mint_max_per_tx, "Too many NFTs in single transaction");

        _safeMint(msg.sender, _amt);

        // Below keeps track of _currIndex and associates price data within mapping
        for(uint i = 0; i<_amt; i++) {          
          _tokenData[_currIndex].price = item_price_public;
          _currIndex++;
        }
    }

    function setAllowlistMintActive(bool _val) external onlyOwner {
        is_allowlist_active = _val;
    }

    function setPublicMintActive(bool _val) external onlyOwner {
        is_public_mint_active = _val;
    }

    function setIsRevealed(bool _val) external onlyOwner {
        is_revealed = _val;
    }

    function setRefundActive(bool _val) external onlyOwner {
        is_refund_active = _val;
    }

    function setNewRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function setAllowlistMintAmount(uint256 _amt) external onlyOwner {
        allowlist_mint_max_per_tx = _amt;
    }

    function setItemPricePublic(uint256 _price) external onlyOwner {
        item_price_public = _price;
    }

    function setItemPriceAL(uint256 _price) external onlyOwner {
        item_price_al = _price;
    }

    function setMaxMintPerTx(uint256 _amt) external onlyOwner {
        pub_mint_max_per_tx = _amt;
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }

    // function setallTransfersDisabled(bool _allTransfersDisabled) external onlyOwner {
    //     allTransfersDisabled = _allTransfersDisabled;
    // }

    function setUnrevealedURI(string memory _uri) external onlyOwner {
        unrevealedURI = _uri;
    }

    function setReturnAddress(address to) external onlyOwner {
        if (to == address(0)) revert("Cannot set to 0 address");
        _return_address = to;
    }

    function returnAddress() external view returns (address) {
        return _return_address;
    }

    function isOnAllowList(bytes32[] calldata _proof, address _user) public view returns (uint256) {
        bytes32 leaf = keccak256(abi.encodePacked(_user));
        return MerkleProof.verify(_proof, root, leaf) ? 1 : 0;
    }

    function getSaleStatus() public view returns (string memory) {
        if(is_public_mint_active) {
            return "public";
        }
        else if(is_allowlist_active) {
            return "allowlist";
        }
        else {
            return "closed";
        }
    }

    function tokenURI(uint256 _tokenID) public view virtual override returns (string memory) {
      require(_exists(_tokenID), "ERC721Metadata: URI query for nonexistent token");

      if(is_revealed) {
          return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _randomNumbers[_tokenID].toString(), ".json")) : "";
      }
      else {
          return unrevealedURI;
      }
  }

  /* 

  Shuffler is based off Fisher-Yates Algorithm: https://github.com/sfriedman71/lasercat/blob/main/fisher_yates_shuffle.sol

  */

  function shuffler(uint _randomSeed) public onlyOwner { // _randomSeed is currently being supplied off chain however there is an ability to introduce a provably random seed using Chainlink VRF if further transparency and decentralization is desired

    console.log("random numbers", _randomNumbers.length); // Checkes that the _randomNumbers array is created successfully, can be removed once local testing is complete

    uint temp; // keeps track of current number
    uint r; // random index based on current number and _randomSeed

    for (uint i = MAX_TOTAL_TOKENS-1; i > 1; i--) { // loop through entire _randomNumbers array     
      temp = _randomNumbers[i]; // current number in loop
      r = _randomSeed % i; // random index per current index in loop
      _randomNumbers[i] = _randomNumbers[r]; // swap current number with random number
      _randomNumbers[r] = temp; // swap random number with current nunmber
    }
  }

  function refund(address to, uint256 tokenId) external {
    if (!is_refund_active) revert RefundPeriodNotActive();
    if (to == address(0)) revert RefundToZeroAddressNotAllowed();
    if (_msgSender() != ownerOf(tokenId)) revert RefundCalledNotOwner();
    if (_tokenData[tokenId].refunded) revert TokenHasAlreadyBeenRefunded();

    uint256 refundAmount = _tokenData[tokenId].price*(100-admin_percentage)/100;

    if (refundAmount == 0) revert TokenWasFreeMint();

    safeTransferFrom(_msgSender(), _return_address, tokenId);

    (bool success, ) = to.call{value: refundAmount}("");
    if (!success) revert RefundUnsuccessful();

    emit Transfer(_msgSender(), _return_address, tokenId);

    unchecked {
        _tokenData[tokenId].refunded = true;
    }
  }

  // Usage of _beforeTokenTransfers hook from ERC721A to add some require statements for transfers/mints

  function _beforeTokenTransfers(
    address,
    address,
    uint256,
    uint256
) internal view override {
    if (allTransfersDisabled) revert AllTransfersHaveBeenDisabled();
}

  //  Below function exists strictly for local testing and should be removed before deploying to testnet/mainnet

  function getRandomNumbersArray() public view onlyOwner returns (uint256[] memory) {
    return _randomNumbers;
  }

    function withdrawEth() public onlyOwner nonReentrant {
        uint256 total = address(this).balance;

        require(payable(0x452A89F1316798fDdC9D03f9af38b0586F8142e5).send((total * 5) / 100));
        require(payable(0x10b5B489E9b4d220Ab6e4a0E7276c54D5bf837cD).send((total * 15) / 100));
        require(payable(0x41e1c9116667Fcc9dd640287796fB5eBDB1DB70E).send((total * 20) / 100));
        require(payable(0x5C2ce2d9eFAA4361aB129f77Bdad019A9a1b1cbe).send((total * 20) / 100));
        require(payable(0x6D9d741BC5Bca227070C43a23977E2FDE6B971e9).send((total * 20) / 100));
        require(payable(0x94Eb23cC87c4826DF76158151e0C3e94c18f02bB).send((total * 20) / 100));
    }

    receive() payable external {
        revert ContractDoesNotAllowReceiptOfTokens();
    }

    fallback() payable external {
        revert AnIncorrectFunctionWasCalled();
    }
}