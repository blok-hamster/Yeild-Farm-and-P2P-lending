pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Credit is Ownable{
    
    using SafeMath for uint;

    event CreditCreated(address indexed borrower, uint indexed time);
    event ChangeReturned(address indexed lender, uint indexed extraFund, uint indexed time);
    event CreditStateChanged(CreditState indexed state, uint indexed time);
    event LenderInvestment(address lender, uint indexed investment, uint indexed time);
    event BorrowerRepaymentInstallment(address indexed borrower, uint indexed installment, uint indexed time);
    event BorrowerRepaymentFinished(address indexed borrower, uint indexed time);
    event BorrowerWithdrawal(address indexed borrower, uint indexed amount, uint indexed time);
    event CreditStateActiveChanged(bool indexed active, uint indexed time);
    event LenderWithdrawal(address indexed borrower, uint indexed lenderReturnAmount, uint indexed time);
    event LenderRefunded(address indexed lender, uint indexed lendersInvestedAmount, uint indexed time);
    event LenderVoteForRevoking(address indexed lender, uint indexed time);
    event BorrowerIsFraud(address indexed borrower, uint indexed time);
    event LenderVoteForFraud(address indexed lender, uint indexed time);

    enum CreditState { 
        INVESTMENT, 
        REPAYMENT, 
        INTREST_RETURNS, 
        EXPIRED, 
        REVOCKED, 
        FRAUD 
    }

    CreditState state;

    mapping (string => uint) countMap;
    mapping (string => uint) uintMap;

    address creditFactory;
    address borrower;
    uint repaidAmount;
    uint requestedDate;
    uint lastRepaymentDate;
    uint revokeTimeNeeded = block.timestamp + 1 seconds;

    
    string description;
    bool active = true;
  

    mapping(address => bool) revokeVoters;
    
    mapping(address => bool) public lenders;

    mapping(address => uint) lendersInvestedAmount;

    address[] public lendersLog;

    modifier isActive() {
        require(active == true);
        _;
    }

    modifier onlyBorrower() {
        require(msg.sender == borrower);
        _;
    }

    modifier onlyLender() {
        require(lenders[msg.sender] == true);
        _;
    }

    modifier canAskForInterest() {
        require(state == CreditState.INTREST_RETURNS);
        require(lendersInvestedAmount[msg.sender] > 0);
        _;
    }

    modifier canInvest() {
        require(state == CreditState.INVESTMENT);
        _;
    }

    modifier canRepay() {
        require(state == CreditState.REPAYMENT);
        _;
    }

    modifier canWithdraw() {
        require(address(this).balance >= uintMap["requestedAmount"]);
        _;
    }

    modifier isNotFraud() {
        require(state != CreditState.FRAUD);
        _;
    }

    modifier isRevokable() {
        require(block.timestamp >= revokeTimeNeeded);
        require(state == CreditState.INVESTMENT);
        _;
    }

    modifier isRevoked() {
        require(state == CreditState.REVOCKED);
        _;
    }

    constructor (uint _requestedAmount, uint _requestedRepayments, uint _interest, string memory _description, address _borrower) {
        
        borrower = _borrower; 
        uintMap["intrest"] = _interest;
        uintMap["requestedAmount"] = _requestedAmount;
        uintMap["requestedRepayments"] = _requestedRepayments;
        uintMap["remainingRepayments"] = _requestedRepayments;
        uintMap["returnAmount"]  = _requestedAmount.add(_interest);
        uintMap["repaymentInstallment"] = uintMap["returnAmount"].div(_requestedRepayments);
        description = _description;
        requestedDate = block.timestamp;
        creditFactory = msg.sender;
        countMap["lendersCount"] = 0;
        countMap["revokeVotes"] = 0;
        state = CreditState.INVESTMENT;
        emit CreditCreated(_borrower, block.timestamp);
    }

    function invest() public payable canInvest {
        uint lendersCount = countMap["lendersCount"];
        uint extraFund = 0;

        if (address(this).balance >= uintMap["requestedAmount"]) {
            extraFund = address(this).balance.sub(uintMap["requestedAmount"]);
            if (extraFund > 0) {

                (bool pc, ) = payable(msg.sender).call{value: extraFund}("");
                require(pc);
             
                emit ChangeReturned(msg.sender, extraFund, block.timestamp);
            
            }

            state = CreditState.REPAYMENT;
            
            emit CreditStateChanged(state, block.timestamp);
        }

        
        lenders[msg.sender] = true;
        lendersLog.push(msg.sender);
        lendersCount++;
        lendersInvestedAmount[msg.sender] = lendersInvestedAmount[msg.sender].add(msg.value.sub(extraFund));

        emit LenderInvestment(msg.sender, msg.value.sub(extraFund), block.timestamp);
    }

    function repay() public onlyBorrower canRepay payable {
        require(uintMap["remainingRepayments"] > 0);
        require(msg.value >= uintMap["repaymentInstallment"]);

        uintMap["remainingRepayments"]--;
        lastRepaymentDate = block.timestamp;

        uint extraFund = 0;
        if (msg.value > uintMap["repaymentInstallment"]) {
            extraFund = msg.value.sub(uintMap["repaymentInstallment"]);
            
            (bool os, ) = payable(msg.sender).call{value: extraFund}("");
            require(os);
        }

        emit BorrowerRepaymentInstallment(msg.sender, msg.value.sub(extraFund), block.timestamp);

        repaidAmount = repaidAmount.add(msg.value.sub(extraFund));
        if (repaidAmount == uintMap["returnAmount"]) {
            emit BorrowerRepaymentFinished(msg.sender, block.timestamp);
            state = CreditState.INTREST_RETURNS;

            emit CreditStateChanged(state, block.timestamp);
        }
    }

    function withdraw() public isActive onlyBorrower canWithdraw isNotFraud {

        state = CreditState.REPAYMENT;
        emit CreditStateChanged(state, block.timestamp);
        emit BorrowerWithdrawal(msg.sender, address(this).balance, block.timestamp);
        (bool os, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(os);
    }

    /** @dev Request interest function.
      * It can only be executed while contract is in active state.
      * It is only accessible to lenders.
      * It is only accessible if lender funded 1 or more wei.
      * It can only be executed once.
      * Transfers the lended amount + interest to the lender.
      */
    function requestInterest() public isActive onlyLender canAskForInterest {
        
        uint newlendersCount = countMap["lendersCount"];
        
        uint lenderReturnAmount = uintMap["returnAmount"] / newlendersCount;
        assert(address(this).balance >= lenderReturnAmount);
        payable(msg.sender).transfer(lenderReturnAmount);
       
        emit LenderWithdrawal(msg.sender, lenderReturnAmount, block.timestamp);

        if (address(this).balance == 0) {

            
            active = false;
            emit CreditStateActiveChanged(active, block.timestamp);
            state = CreditState.EXPIRED;

            emit CreditStateChanged(state, block.timestamp);
        }
    }


    function revokeVote() public isActive isRevokable onlyLender {
        require(revokeVoters[msg.sender] == false);
        uint voteCounts = countMap["revokeVotes"];
        uint lendersCount = countMap["lendersCount"];
        voteCounts++;
        revokeVoters[msg.sender] == true;

        emit LenderVoteForRevoking(msg.sender, block.timestamp);

        if (lendersCount == voteCounts) {
            revoke();
        }
    }

    
    function revoke() internal {
        state = CreditState.REVOCKED;
        emit CreditStateChanged(state, block.timestamp);

    }

    /** @dev Function for refunding people. */
    function refund() public isActive onlyLender isRevoked {

        uint investedAmount = lendersInvestedAmount[msg.sender];
        
        require(address(this).balance >= investedAmount);
        payable(msg.sender).transfer(investedAmount);
        emit LenderRefunded(msg.sender, investedAmount, block.timestamp);
        
        if (address(this).balance == 0) {
            active = false;
            emit CreditStateActiveChanged(active, block.timestamp);
            state = CreditState.EXPIRED;
            emit CreditStateChanged(state, block.timestamp);
        }
    }

    function changeState(CreditState _state) external onlyOwner {
        state = _state;
        emit CreditStateChanged(state, block.timestamp);
    }

    
    function toggleActive() external onlyOwner returns (bool) {
        active = !active;
        emit CreditStateActiveChanged(active, block.timestamp);
        return active;
    }

    function getCreditInfo() public view returns (address, string memory, uint, uint, uint, uint, uint, uint, CreditState, bool, uint) {
       
        return 
            (borrower, 
            description, 
            uintMap["requestedAmount"], 
            uintMap["requestedRepayments"], 
            uintMap["repaymentInstallment"], 
            uintMap["remainingRepayments"], 
            uintMap["intrest"], 
            uintMap["returnAmount"], 
            state, 
            active,
            address(this).balance
        );
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getLenders() external view onlyOwner returns(address[] memory){
        return lendersLog;
    }


}