// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./P2PLending.sol";
import "./Wallet.sol";

contract YieldFarm is Ownable, P2PLending, Wallet {
    using SafeMath for uint;
    // mapping token address -> staker address -> amount

    event NewTokenAdded(address indexed token);
    event TokenStaked(address indexed staker, address indexed token, uint indexed amount);
    event TokenUnstaked(address indexed staker, address indexed token);
    event RewardTokenIssued(uint indexed time);

    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMap;
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public TST;

    constructor(address _TSTAddress) {
        TST = IERC20(_TSTAddress);
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);

        emit NewTokenAdded(_token);
    }

    function setPriceFeedAddress(address _token, address _priceFeed) public onlyOwner {
        tokenPriceFeedMap[_token] = _priceFeed;
    }

    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount has to be greater than zero (0)");
        require(tokenIsAllowed(_token), "Token is currrently not allowed");
        
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] = stakingBalance[_token][msg.sender] + _amount;
        
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }

        emit TokenStaked(msg.sender, _token, _amount);

    }

    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    function unstakeToken(address _token) public {
        uint balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Stacking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;

        emit TokenUnstaked(msg.sender, _token);
    }

    function issueRewardTokens() public onlyOwner {
        for ( uint stakersIndex = 0; stakersIndex < stakers.length; stakersIndex++) {
            
            address recipient = stakers[stakersIndex];
            uint userTotalValue = getUserTotalValue(recipient);
            TST.transfer(recipient, userTotalValue);
            // send them a token reward based on their total value locked

            emit RewardTokenIssued(block.timestamp);
        }
    }

    function getUserTotalValue(address _user) public view returns (uint) {
        uint totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        for (uint allowedTokensIndex = 0; allowedTokensIndex < allowedTokens.length; allowedTokensIndex++) {
            totalValue = totalValue + getUserSingleTokenValue( _user, allowedTokens[allowedTokensIndex] );
        }
        
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token) public view returns (uint){
        
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        // this gives us the price of the token
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return ((stakingBalance[_token][_user] * price) / (10**decimals));
    }

    function getTokenValue(address _token) public view returns (uint, uint)
    {
        //price feed address
        address priceFeedAddress = tokenPriceFeedMap[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface( priceFeedAddress );
        
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint decimals = uint(priceFeed.decimals());
        
        return (uint(price), decimals);
    }

    
    function tokenIsAllowed(address _token) view public returns (bool) {
        for ( uint allowedTokensIndex = 0; allowedTokensIndex < allowedTokens.length; allowedTokensIndex++ ) {
            
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        
        return false;
    }
}