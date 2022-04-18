pragma solidity 0.8.7;

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


 /** Stages that every credit contract gets trough.
      *   INVESTMENT - During this state only investments are allowed.
      *   REPAYMENT - During this stage only repayments are allowed.
      *   INTREST_RETURNS - This stage gives investors opportunity to request their returns.
      *   EXPIRED - This is the stage when the contract is finished its purpose.
      *   FRAUD - The borrower was marked as fraud.
    */
    enum CreditState { 
        INVESTMENT, 
        REPAYMENT, 
        INTREST_RETURNS, 
        EXPIRED, 
        REVOCKED, 
        FRAUD 
    }

    CreditState state;

    address creditFactory;

    // Borrower is the person who generated the credit contract.
    address borrower;

    // Amount requested to be funded (in wei).
    uint requestedAmount;

    // Amount that will be returned by the borrower (including the interest).
    uint returnAmount;

    // Currently repaid amount.
    uint repaidAmount;

    // Credit interest.
    uint interest;

    // Requested number of repayment installments.
    uint requestedRepayments;

    // Remaining repayment installments.
    uint remainingRepayments;

    // The value of the repayment installment.
    uint repaymentInstallment;

    // The timestamp of credit creation.
    uint requestedDate;

    // The timestamp of last repayment date.
    uint lastRepaymentDate;

       // Store the lenders count, later needed for revoke vote.
    uint lendersCount = 0;

    // Revoke votes count.
    uint revokeVotes = 0;

    // Time needed for a revoke voting to start.
    uint revokeTimeNeeded = block.timestamp + 1 seconds;

    // Description of the credit.
    string description;

    // Active state of the credit.
    bool active = true;
  
    // Revoke voters.
    mapping(address => bool) revokeVoters;
    
    // Storing the lenders for this credit.
    mapping(address => bool) public lenders;

    // Storing the invested amount by each lender.
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
        require(address(this).balance >= requestedAmount);
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
        interest = _interest;
        requestedAmount = _requestedAmount;
        requestedRepayments = _requestedRepayments;
        remainingRepayments = _requestedRepayments;
        returnAmount = requestedAmount.add(interest);
        repaymentInstallment = returnAmount.div(requestedRepayments);
        description = _description;
        requestedDate = block.timestamp;
        creditFactory = msg.sender;
        state = CreditState.INVESTMENT;
        emit CreditCreated(_borrower, block.timestamp);
    }

    function invest() public payable canInvest {
        
        uint extraFund = 0;

        if (address(this).balance >= requestedAmount) {

            // Calculate the extra money that may have been sent.
            extraFund = address(this).balance.sub(requestedAmount);

            // Check if extra money is greater than 0 wei.
            if (extraFund > 0) {

                payable(msg.sender).transfer(extraFund);
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
        require(remainingRepayments > 0);
        require(msg.value >= repaymentInstallment);

        remainingRepayments--;

        lastRepaymentDate = block.timestamp;

        uint extraFund = 0;

        if (msg.value > repaymentInstallment) {

            extraFund = msg.value.sub(repaymentInstallment);

            payable(msg.sender).transfer(extraFund);
        }

        emit BorrowerRepaymentInstallment(msg.sender, msg.value.sub(extraFund), block.timestamp);

        repaidAmount = repaidAmount.add(msg.value.sub(extraFund));

        if (repaidAmount == returnAmount) {

            emit BorrowerRepaymentFinished(msg.sender, block.timestamp);

            state = CreditState.INTREST_RETURNS;

            emit CreditStateChanged(state, block.timestamp);
        }
    }

    /** @dev Withdraw function.
      * It can only be executed while contract is in active state.
      * It is only accessible to the borrower.
      * It is only accessible if the needed amount is gathered in the contract.
      * It can only be executed once.
      * Transfers the gathered amount to the borrower.
      */
    function withdraw() public isActive onlyBorrower canWithdraw isNotFraud {

        state = CreditState.REPAYMENT;

        emit CreditStateChanged(state, block.timestamp);

        emit BorrowerWithdrawal(msg.sender, address(this).balance, block.timestamp);

        payable(borrower).transfer(address(this).balance);
    }

    /** @dev Request interest function.
      * It can only be executed while contract is in active state.
      * It is only accessible to lenders.
      * It is only accessible if lender funded 1 or more wei.
      * It can only be executed once.
      * Transfers the lended amount + interest to the lender.
      */
    function requestInterest() public isActive onlyLender canAskForInterest {

        // Calculate the amount to be returned to lender.
        uint lenderReturnAmount = returnAmount / lendersCount;

        // Assert the contract has enough balance to pay the lender.
        assert(address(this).balance >= lenderReturnAmount);

        // Transfer the return amount with interest to the lender.
        payable(msg.sender).transfer(lenderReturnAmount);

        emit LenderWithdrawal(msg.sender, lenderReturnAmount, block.timestamp);

        if (address(this).balance == 0) {

            // Set the active state to false.
            active = false;

            // Log active state change.
            emit CreditStateActiveChanged(active, block.timestamp);

            state = CreditState.EXPIRED;

            emit CreditStateChanged(state, block.timestamp);
        }
    }

    /** @dev Function for revoking the credit.
      */
    function revokeVote() public isActive isRevokable onlyLender {
        require(revokeVoters[msg.sender] == false);
        revokeVotes++;
        revokeVoters[msg.sender] == true;

        emit LenderVoteForRevoking(msg.sender, block.timestamp);

        if (lendersCount == revokeVotes) {
            revoke();
        }
    }

    /** @dev Revoke internal function.
      */
    function revoke() internal {
        state = CreditState.REVOCKED;
        emit CreditStateChanged(state, block.timestamp);

    }

    /** @dev Function for refunding people. */
    function refund() public isActive onlyLender isRevoked {
        require(address(this).balance >= lendersInvestedAmount[msg.sender]);

        payable(msg.sender).transfer(lendersInvestedAmount[msg.sender]);

        emit LenderRefunded(msg.sender, lendersInvestedAmount[msg.sender], block.timestamp);
        
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
       
        return (
        borrower,
        description,
        requestedAmount,
        requestedRepayments,
        repaymentInstallment,
        remainingRepayments,
        interest,
        returnAmount,
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