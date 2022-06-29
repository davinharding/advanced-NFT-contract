# Advanced NFT Contract

This project is an extension of the ERC721A standard NFT contract to be used for clients of [Palm Tree NFT](https://www.palmtreenft.com/).  

# Features

- Internal (free) Mint with reservation system
- Allowlist mint w support for different price and tracking via Merkle Tree for memory optimization
- Public mint
- Metadata shuffle mechanism using Fisher-Yates algorithm to randomize mint at owner's discretion
- Several DAO controls
    - Refund mechanism w ability to turn on/off
    - Ability for DAO to revoke membership (take back NFT)
    - One token per wallet
    - Switch to allow/disallow transfers (soulbound NFT)
- Automatic withdraw to multiple wallets
- Revert upon receipt of ERC20 tokens or incorrect funciton call
- Moonbirds style cumulative staking per token
- Full test suite testing revert statements and core functionality
- Function based error messages for memory optimization