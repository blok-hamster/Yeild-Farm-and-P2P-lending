pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Credit.sol";

contract P2PLending is Ownable  {

    using SafeMath for uint;

    struct Credits {
        uint requestedAmount;
        uint requestedRepayments;
        uint interest;
        string description;
        address borrower;
        uint fraudVoteCount;
    }

    struct User {
        bool credited;
        Credit activeCredit;
        bool fraudStatus;
        Credit[] allCredits;
    }

    mapping (address => mapping (Credit => bool)) creditFraudVote;
    mapping (Credit => Credits) public creditsMap;
    mapping(address => User) public users;
    
    Credit[] public credits;
    Credits[] public creditlog;

    event CreditCreated(Credit indexed _address, address indexed _borrower, uint indexed timestamp);
    event CreditActiveChanged(Credit indexed _address, bool indexed active, uint indexed timestamp);
    event UserSetFraud(address indexed _address, bool fraudStatus, uint timestamp);


    function applyForCredit(uint requestedAmount, uint repaymentsCount, uint interest, string calldata creditDescription) public returns(Credit _credit) {
        require(users[msg.sender].credited == false);
        require(users[msg.sender].fraudStatus == false);
        users[msg.sender].credited = true;

        Credit credit = new Credit(requestedAmount, repaymentsCount, interest, creditDescription, msg.sender);
        Credits memory newCredits = creditsMap[credit];
        newCredits = Credits(requestedAmount, repaymentsCount, interest, creditDescription, msg.sender, 0);
        creditlog.push(newCredits);

        users[msg.sender].activeCredit = credit;
        credits.push(credit);
        users[msg.sender].allCredits.push(credit);

        emit CreditCreated(credit, msg.sender, block.timestamp);

        return credit;
    }

    function getCredits() public view returns (Credit[] memory) {
        return credits;
    }

    function getUserCredits() public view returns (Credit[] memory) {
        return users[msg.sender].allCredits;
    }

    function setFraudStatus(address _borrower) public returns (bool) {
        // Update user fraud status.
        users[_borrower].fraudStatus = true;

        return users[_borrower].fraudStatus;
    }

    function changeCreditState (address _credit) public onlyOwner {
        Credit credit = Credit(_credit);
        bool active = credit.toggleActive();

        emit CreditActiveChanged(credit, active, block.timestamp);
    }

    /** @dev Function for voting the borrower as fraudster.
     */
    function fraudVote(Credit _credit) external {
       
        Credit credit = Credit(_credit);
        address[] memory lendersLog = credit.getLenders();
        address borrower = creditsMap[_credit].borrower;
        
        for(uint lendersIndex = 0; lendersIndex < lendersLog.length; lendersIndex++){
            require(msg.sender == lendersLog[lendersIndex], "You arenot a lender");
            creditFraudVote[msg.sender][_credit] = true;
            creditsMap[_credit].fraudVoteCount++;
                
            if(creditsMap[_credit].fraudVoteCount == lendersLog.length){
                users[borrower].fraudStatus = true;

                emit UserSetFraud(borrower, users[borrower].fraudStatus, block.timestamp);
            }
        }
    }
}