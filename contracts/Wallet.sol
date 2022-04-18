// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Wallet is Ownable {
    using SafeMath for uint;
    
    event TokenAdded(address, bytes32);
    
    struct Tokens{
        address tokenAddress;
        bytes32 symbol;
    }
    
    bytes32[] tokenList;
    mapping(address => mapping(bytes32 => uint)) tokenBalance;
    mapping(bytes32 => Tokens) tokenMap;

    modifier tokenExist(bytes32 symbol){
        require(tokenMap[symbol].tokenAddress != address(0), "Not a valid token");
        _;
    }


    function addToken(address tokenAddress, bytes32 symbol) external onlyOwner returns(bool success){
        require(tokenAddress != address(0), "Invalid Token Address");
        tokenMap[symbol] = Tokens(tokenAddress, symbol);
        tokenList.push(symbol);
        return success;
    }

    function depositToken(bytes32 symbol, uint _amount) external tokenExist(symbol) {
        tokenBalance[msg.sender][symbol] = tokenBalance[msg.sender][symbol].add(_amount);
        IERC20(tokenMap[symbol].tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function approveDeposit(uint amount, bytes32 symbol) external {
        IERC20(tokenMap[symbol].tokenAddress).approve(address(this), amount);
    }
    
    function withdrawToken(uint _amount, bytes32 symbol) public tokenExist(symbol) {
        require(tokenBalance[msg.sender][symbol] >= _amount, "Balance Not Sufficent");
        tokenBalance[msg.sender][symbol] = tokenBalance[msg.sender][symbol].sub(_amount);
        IERC20(tokenMap[symbol].tokenAddress).transfer(msg.sender, _amount);
    }

    function depositEth () external payable {
        tokenBalance[msg.sender][bytes32("ETH")] = tokenBalance[msg.sender][bytes32("ETH")].add(msg.value);
    
    }

    function withdrawEth (uint _amount) external returns(bool success){
        require(tokenBalance[msg.sender][bytes32("ETH")] >= _amount);
        tokenBalance[msg.sender][bytes32("ETH")] = tokenBalance[msg.sender][bytes32("ETH")].sub(_amount);
        msg.sender.call{value: _amount};
        return success;
    }

    function getBalance(bytes32 symbol) public view returns(uint){
        return tokenBalance[msg.sender][symbol];
    }

}