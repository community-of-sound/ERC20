
pragma solidity ^0.4.18;

interface token {
    function transfer(address receiver, uint amount) external;
}
/**
 * Math operations with safety checks
 */
contract SafeMath {

    function safeMul(uint a, uint b)pure internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b)pure internal returns (uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function safeSub(uint a, uint b)pure internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b)pure internal returns (uint) {
        uint c = a + b;
        assert(c>=a && c>=b);
        return c;
    }
}

contract ContractReceiver {
     
    struct TKN {
        address sender;
        uint value;
        bytes data;
        bytes4 sig;
    }
    function tokenFallback(address _from, uint _value, bytes _data) public pure {
        TKN memory tkn;
        tkn.sender = _from;
        tkn.value = _value;
        tkn.data = _data;
        uint32 u = uint32(_data[3]) + (uint32(_data[2]) << 8) + (uint32(_data[1]) << 16) + (uint32(_data[0]) << 24);
        tkn.sig = bytes4(u);
    
    /* tkn variable is analogue of msg variable of Ether transaction
    *    tkn.sender is person who initiated this token transaction     (analogue of msg.sender)
    *    tkn.value the number of tokens that were sent     (analogue of msg.value)
    *    tkn.data is data of token transaction     (analogue of msg.data)
    *    tkn.sig is 4 bytes signature of function
    *    if data of token transaction is a function execution
    */
    }
}

contract CoSoundCrowdsale is SafeMath, ContractReceiver{
    address public owner;
    address public webOwner;
    uint public startDate;
    uint public endDate;
    uint public price;
    uint public minPurchase;
    uint8 public decimals;

    uint public fundingGoal;
    uint public amountRaised;
    
    token public tokenReward;
    mapping(address => uint256) public balanceOf;
    bool fundingGoalReached = false;
    bool crowdsaleClosed = false;

    event GoalReached(address recipient, uint totalAmountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }
    modifier isWebOwner() {
        require(msg.sender == webOwner);
        _;
    }

    /**
     * Constructor function
     *
     * Setup the owner
     */
    constructor() public{
        owner = msg.sender;
        webOwner = msg.sender;
        decimals = 18;
        startDate = safeAdd(now,safeMul(48,1 days));
        endDate = safeAdd(now,safeMul(78,1 days));
        fundingGoal = safeMul(50000000,10 ** uint256(decimals));
        price = 8330000000000;
        minPurchase = safeMul(100000,1 szabo);
        tokenReward = token(0x5D78c9C2c31982aDa68bCD588B500F9696F409f0);
    }

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable public{
        require(msg.value > 0 && msg.value >= minPurchase);
        uint unitsBought = safeMul(safeDiv(msg.value, price),10 ** uint256(decimals));
        require(!crowdsaleClosed);
        require(now >= startDate && now <= endDate);
         // ensure user is not trying to buy more than sufficient token
        require(fundingGoal > amountRaised && unitsBought <= safeSub(fundingGoal,amountRaised));

        balanceOf[msg.sender] = safeAdd(balanceOf[msg.sender], msg.value);
        
        amountRaised = safeAdd(amountRaised, unitsBought);  
        if(amountRaised >= fundingGoal){
            fundingGoalReached = true;
            crowdsaleClosed = true;
        }
        tokenReward.transfer(msg.sender, unitsBought);
        emit FundTransfer(msg.sender, unitsBought, true);
    }

    modifier afterDeadline() { if (now >= endDate) _; }

    modifier crowdsaleActive() { if (now >= startDate && now <= endDate) _; }

    /**
     * Check if goal was reached
     *
     * Checks if the goal or time limit has been reached and ends the campaign
     */
    function checkGoalReached() afterDeadline public{
        if (amountRaised >= fundingGoal){
            fundingGoalReached = true;
            emit GoalReached(owner, amountRaised);
        }
        crowdsaleClosed = true;
    }


    /**
     * Withdraw the funds
     *
     * Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the owner. If goal was not reached, each contributor can withdraw
     * the amount they contributed.
     */
    function safeWithdrawal() afterDeadline isOwner public{
        if (fundingGoalReached && owner == msg.sender) {
            if (owner.send(amountRaised)) {
                emit FundTransfer(owner, amountRaised, false);
            } else {
                //If we fail to send the funds to owner, unlock funders balance
                fundingGoalReached = false;
            }
        }
    }
    /* transfer balance to owner */
    function withdrawEther(uint256 amount) isOwner public{
        uint oldamount = amountRaised;
        if(owner.send(amount)){
            amountRaised = safeSub(amountRaised, amount);
            emit FundTransfer(owner, amount, false);
        }else{
            amountRaised = oldamount;
        }
    }

    function setOwner(address _owner) isOwner public {
        owner = _owner;      
    }
    function setWebOwner(address _owner) isOwner public {
        webOwner = _owner;      
    }

    function setStartDate(uint256 _startDate) isOwner public {
        startDate =  now + (_startDate * 1 days);      
    }

    function setEndtDate(uint256 _endDate) isOwner public {
        endDate =  now + (_endDate * 1 days);  
    }
    
    function setPrice(uint256 _price) isOwner public {
        price = _price;      
    }

    function setToken(address _token) isOwner public {
        tokenReward = token(_token);      
    }

    function sendToken(address _to, uint256 _value) isOwner public {
        tokenReward.transfer(_to, _value);      
    }
    /**
     * This method will be used by the Web Crowdsale App to send token after successful purchase
     * This address must be different from the owner address to avoid exposing owner private key
     * to the web attack.
     */
    function sendWebToken(address _to, uint256 _value) isWebOwner crowdsaleActive public{
        uint value = safeMul(_value,10 ** uint256(decimals));
        require(value > 0 && value >= minPurchase);
        require(!crowdsaleClosed);
         // ensure user is not trying to buy more than sufficient token
        require(fundingGoal > amountRaised && value <= safeSub(fundingGoal,amountRaised));

        amountRaised = safeAdd(amountRaised, value); 
        if(amountRaised >= fundingGoal){
            fundingGoalReached = true;
            crowdsaleClosed = true;
        }
        tokenReward.transfer(_to, _value);
        emit FundTransfer(_to, value, true);
    }

    function endCrowdsale() isOwner public{
        selfdestruct(owner);
    }

    function kill() isOwner public{
        selfdestruct(owner);
    }

}