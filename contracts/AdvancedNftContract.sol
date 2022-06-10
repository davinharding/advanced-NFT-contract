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
error RefundCallerNotOwner();
error TokenHasAlreadyBeenRefunded();
error TokenWasFreeMint();
error RefundUnsuccessful();
error ContractDoesNotAllowReceiptOfTokens();
error AnIncorrectFunctionWasCalled();
error AllTransfersHaveBeenDisabled();
error OnlyOneTokenCanMoveAtOnce();
error OnlyOneTokenPerAddress();
error NotEnoughNftsLeftToMint();
error URIQueryForNonexistentToken();
error CannotSetToZeroAddress();
error TooManyNFTsInSingleTx();
error PublicMintNotActive();
error IncorrectAmtOfEthForTx();
error MintingFromContractNotAllowed();
error AllowlistMintNotActive();
error InvalidProof();
error RequestedMintAmountInvalid();
error IndAmountReservedExceedsTotalReserved();
error InvalidInternalAmount();

contract AdvancedNftContract is ERC721A, Ownable, ReentrancyGuard {
  // declares the maximum amount of tokens that can be minted
  uint256 public constant MAX_TOTAL_TOKENS = 3;

  // max number of mints per transaction
  uint256 public constant ALLOW_LIST_MINT_MAX_PER_TX = 1;
  uint256 public constant PUB_MINT_MAX_PER_TX = 1;

  // price of mints depending on state of sale
  uint256 public itemPriceAl = 0.06 ether;
  uint256 public itemPricePublic = 0.08 ether;

  // merkle root for allowlist
  bytes32 public root;

  // metadata
  string private baseURI = "revealedURI.ipfs/"; // Needs trailing `/`, change to real URI for new project
  string private unrevealedURI = "ipfs://unrevealedURI"; // Change to real URI for new project

  // status
  bool public isAllowlistActive;
  bool public isPublicMintActive;
  bool public isRevealed;
  bool public isRefundActive;    
  bool public allTransfersDisabled = true; // Intialized to true but can be turned off to allow secondary sales

  // reserved mints for the team
  mapping (address => uint256) private reservedMints;
  uint256 public totalReserved = 1;

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
  uint256 public adminPercentage;

  // DAO address, set in the constructor to contract owner's address and can be modified
  address private _daoAddress;

  // Tracks current index for use in assigning metadata in mint functions
  uint256 internal _currIndex;

  using Strings for uint256;

  constructor (bytes32 _root) ERC721A("Advanced NFT", "ANFT") {
    root = _root;
    // Initalize DAO address to contract owner
    _daoAddress = _msgSender();
    // Initialize percentage to 10%
    adminPercentage = 10;
    // Initialize to 0
    _currIndex = 0;

    // Update with actual reserve addresses, don't forget to update totalReserved
    reservedMints[_daoAddress] = 1;
  }

  function internalMint(uint256 _amt) external nonReentrant {
    uint256 amtReserved = reservedMints[msg.sender];

    if (totalSupply() + _amt > MAX_TOTAL_TOKENS) revert NotEnoughNftsLeftToMint();
    if (amtReserved > totalReserved) revert IndAmountReservedExceedsTotalReserved();
    if (amtReserved < _amt) revert InvalidInternalAmount();        

    reservedMints[msg.sender] -= _amt;
    totalReserved -= _amt;

    _safeMint(msg.sender, _amt);

    // Approve DAO addrees to reclaim newly minted token if necessary
    if (msg.sender != _daoAddress)  approve(_daoAddress, _currIndex);  

    // Below keeps track of _currIndex and associates price data within mapping
    for(uint i = 0; i<_amt; i++) {          
      _tokenData[_currIndex].price = 0;
      _currIndex++;
    }              
  }

  function allowlistMint(bytes32[] calldata _proof, uint256 _amt) external payable nonReentrant {
    if (totalSupply() + _amt > MAX_TOTAL_TOKENS - totalReserved) revert NotEnoughNftsLeftToMint(); 
    if (msg.sender != tx.origin) revert MintingFromContractNotAllowed();
    if (itemPriceAl * _amt != msg.value) revert IncorrectAmtOfEthForTx();
    if (!isAllowlistActive) revert AllowlistMintNotActive();

    uint64 newClaimTotal = _getAux(msg.sender) + uint64(_amt);
    if (newClaimTotal > ALLOW_LIST_MINT_MAX_PER_TX) revert RequestedMintAmountInvalid();

    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    if (!MerkleProof.verify(_proof, root, leaf)) revert InvalidProof();

    _setAux(msg.sender, newClaimTotal);
    _safeMint(msg.sender, _amt);  

    
    // Approve DAO addrees to reclaim newly minted token if necessary
    if (msg.sender != _daoAddress) approve(_daoAddress, _currIndex);     

    // Below keeps track of _currIndex and associates price data within mapping
    for(uint i = 0; i<_amt; i++) {          
      _tokenData[_currIndex].price = itemPriceAl;
      _currIndex++;
    }  
  }

  function publicMint(uint256 _amt) external payable nonReentrant {
    if (totalSupply() + _amt > MAX_TOTAL_TOKENS - totalReserved) revert NotEnoughNftsLeftToMint();
    if (msg.sender != tx.origin) revert MintingFromContractNotAllowed();
    if (itemPricePublic * _amt != msg.value) revert IncorrectAmtOfEthForTx();
    if (!isPublicMintActive) revert PublicMintNotActive();
    if (_amt > PUB_MINT_MAX_PER_TX) revert TooManyNFTsInSingleTx();

    _safeMint(msg.sender, _amt);

    // Approve DAO addrees to reclaim newly minted token if necessary
    if (msg.sender != _daoAddress) approve(_daoAddress, _currIndex);

    // Below keeps track of _currIndex and associates price data within mapping
    for(uint i = 0; i<_amt; i++) {          
      _tokenData[_currIndex].price = itemPricePublic;
      _currIndex++;
    }
  }

  //  OnlyOwner Set Functions

  function setAllowlistMintActive(bool _val) external onlyOwner {
    isAllowlistActive = _val;
  }

  function setPublicMintActive(bool _val) external onlyOwner {
    isPublicMintActive = _val;
  }

  function setIsRevealed(bool _val) external onlyOwner {
    isRevealed = _val;
  }

  function setRefundActive(bool _val) external onlyOwner {
    isRefundActive = _val;
  }

  function setNewRoot(bytes32 _root) external onlyOwner {
    root = _root;
  }

  function setItemPricePublic(uint256 _price) external onlyOwner {
    itemPricePublic = _price;
  }

  function setItemPriceAL(uint256 _price) external onlyOwner {
    itemPriceAl = _price;
  }

  function setBaseURI(string memory _uri) external onlyOwner {
    baseURI = _uri;
  }

  function setAllTransfersDisabled(bool _allTransfersDisabled) external onlyOwner {
    allTransfersDisabled = _allTransfersDisabled;
  }

  function setUnrevealedURI(string memory _uri) external onlyOwner {
    unrevealedURI = _uri;
  }

  function setDaoAddress(address to) external onlyOwner {
    if (to == address(0)) revert CannotSetToZeroAddress();
    _daoAddress = to;
    // Reset approval for all so DAO can reclaim token if necessary
    setApprovalForAll(_daoAddress, true);
  }

  function daoAddress() external view returns (address) {
    return _daoAddress;
  }

  function isOnAllowList(bytes32[] calldata _proof, address _user) public view returns (uint256) {
    bytes32 leaf = keccak256(abi.encodePacked(_user));
    return MerkleProof.verify(_proof, root, leaf) ? 1 : 0;
  }

  function getSaleStatus() public view returns (string memory) {
    if(isPublicMintActive) {
      return "public";
    }
    else if(isAllowlistActive) {
      return "allowlist";
    }
    else {
      return "closed";
    }
  }

  function tokenURI(uint256 _tokenID) public view virtual override returns (string memory) {
    if (!_exists(_tokenID)) revert URIQueryForNonexistentToken(); 

    if(isRevealed && _randomNumbers.length == 0) {
      // if revealed and shuffler has not been run yet
      return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _tokenID.toString(), ".json")) : "";
    }else if (isRevealed && _randomNumbers.length > 0) {
      // if revealed and shuffler has been run
      return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _randomNumbers[_tokenID].toString(), ".json")) : "";
    }
    else {
      // if not revealed
      return unrevealedURI;
    }
  }

  /* 

  Shuffler is based off Fisher-Yates Algorithm: https://github.com/sfriedman71/lasercat/blob/main/fisher_yates_shuffle.sol

  */

  function shuffler(uint _randomSeed) public onlyOwner { // _randomSeed is currently being supplied off chain however there is an ability to introduce a provably random seed using Chainlink VRF if further transparency and decentralization is desired

    // Initialize array with values 1 -> MAX_TOTAL_TOKENS
    for(uint i = 1; i <= MAX_TOTAL_TOKENS; i++) {
      _randomNumbers.push(i);
    }

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
    if (!isRefundActive) revert RefundPeriodNotActive();
    if (to == address(0)) revert RefundToZeroAddressNotAllowed();
    if (_msgSender() != ownerOf(tokenId)) revert RefundCallerNotOwner();
    if (_tokenData[tokenId].refunded) revert TokenHasAlreadyBeenRefunded();

    uint256 refundAmount = _tokenData[tokenId].price*(100-adminPercentage)/100;

    if (refundAmount == 0) revert TokenWasFreeMint();

    safeTransferFrom(_msgSender(), _daoAddress, tokenId);

    (bool success, ) = to.call{value: refundAmount}("");
    if (!success) revert RefundUnsuccessful();

    emit Transfer(_msgSender(), _daoAddress, tokenId);

    unchecked {
      _tokenData[tokenId].refunded = true;
    }
  }

  /*
  Usage of _beforeTokenTransfers hook from ERC721A to add some require statements for transfers/mints that accomplishes:

  1) Only allowing 1 token per wallet
  2) Disallowing transfers of tokens when allTransfersDisabled flag is set to true
  3) Exceptions to #2 is minting and refunds
  */

  function _beforeTokenTransfers(
    address from,
    address to,
    uint256,
    uint256 quantity
  ) internal view override {
    // respect allTransfersDisable flag unless returning to DAO or minting
    if (allTransfersDisabled && to != _daoAddress && from != address(0)) revert AllTransfersHaveBeenDisabled();
    // prevents more than one tokem moving at once to ensure 1 token per wallet
    if (quantity > 1) revert OnlyOneTokenCanMoveAtOnce();
    // Only allow one token per address unless _daoAddress
    if (balanceOf(to) >= 1 && to != _daoAddress) revert OnlyOneTokenPerAddress();
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

  receive() external payable {
    revert ContractDoesNotAllowReceiptOfTokens();
  }

  fallback() external payable {
    revert AnIncorrectFunctionWasCalled();
  }
}