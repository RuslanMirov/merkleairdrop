pragma solidity ^0.4.24;

interface IERC20 {
  function transfer(address to, uint256 value) external returns (bool);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender)
    external view returns (uint256);

  function transferFrom(address from, address to, uint256 value)
    external returns (bool);
}

import "./MerkleProof.sol";
/**
 * @title MerkleProof
 * @dev Merkle proof verification based on
 * https://github.com/ameensol/merkle-tree-solidity/blob/master/src/MerkleProof.sol
 */
contract MerkleProofAirdrop {
  event Drop(string ipfs, address indexed rec, uint amount);

  struct Airdrop {
    address owner;
    bytes32 root;
    address tokenAddress;
    uint total;
    uint claimed;
    mapping(address => bool) claimedRecipients;
  }

  mapping(bytes32 => Airdrop) public airdrops;

  function createNewAirdrop(bytes32 _root, address _tokenAddress, uint _total, string _ipfs) public {
    bytes32 ipfsHash = keccak256(abi.encodePacked(_ipfs));
    IERC20 token = IERC20(_tokenAddress);
    require(token.allowance(msg.sender, address(this)) >= _total, "this contract must be allowed to spend tokens");

    airdrops[ipfsHash] = Airdrop({
      owner: msg.sender,
      root: _root,
      tokenAddress: _tokenAddress,
      total: _total,
      claimed: 0
    });
  }

  function cancelAirdrop(string _ipfs) public {
    bytes32 ipfsHash = keccak256(abi.encodePacked(_ipfs));
    Airdrop airdrop = airdrops[ipfsHash];
    require(msg.sender == airdrop.owner);
    uint left = airdrop.total - airdrop.claimed;
    require(left > 0);

    IERC20 token = IERC20(airdrop.tokenAddress);
    require(token.balanceOf(address(this)) >= left, "not enough tokens");
    token.transfer(msg.sender, left);

  }

  function drop(bytes32[] proof, address _recipient, uint256 _amount, string _ipfs) public {
    bytes32 leaf = keccak256(keccak256(abi.encode(_recipient, _amount)));
    bytes32 ipfsHash = keccak256(abi.encodePacked(_ipfs));
    Airdrop airdrop = airdrops[ipfsHash];

    require(verify(proof, airdrop.root, leaf));
    require(airdrop.claimedRecipients[_recipient] == false, "double spend");
    airdrop.claimedRecipients[_recipient] = true;
    airdrop.claimed += _amount;

    IERC20 token = IERC20(airdrop.tokenAddress);
    require(token.allowance(airdrop.owner, address(this)) >= _amount, "this contract must be allowed to spend tokens");
    token.transferFrom(airdrop.owner, _recipient, _amount);

    // transfer tokens
    emit Drop(_ipfs, _recipient, _amount);
  }

  // function dropAll(
  //   bytes32[] _merkleProofs,
  //   uint256[] _indexesProofs,
  //   address[] _receipent,
  //   uint256[] _amount
  // ) public {

  // }

  function verify(
    bytes32[] proof,
    bytes32 root,
    bytes32 leaf
  )
    public
    pure
    returns (bool)
  {
    return MerkleProof.verify(proof, root, leaf);
  }

  function verifyProofs(
    uint[] start,
    uint[] length,
    bytes32[] proofs,
    bytes32 root,
    bytes32[] leafs
  )
    public
    pure
    returns (bool)
  {
    uint previous = 0;
    // [0], [4], [....], root, [leaf1]
    // [0,4], [4,4], [.... ....], root, [leaf1, leaf2]
    for(uint256 i = 0; i < leafs.length; i++) {
      bytes32 computedHash = leafs[i];
      if(i != 0) {
        previous += length[i];
      }
      for (uint256 j = start[i]; j < previous + length[i]; j++) {
        bytes32 proofElement = proofs[j];

        if (computedHash < proofElement) {
          computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
        } else {
          computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
        }
      }
      require(computedHash == root, "not match");
    }
    return true;
  }

}
