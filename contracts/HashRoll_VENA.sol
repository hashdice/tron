/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HashRoll: a Block Chain Gambling Game.

Don't trust anyone but the CODE!
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    - HashRoll 是HashDice系列合约之一，对roll游戏做了以下增强：

    1. 随机数来源于commit + reveal，并混杂了交易hash. 以验证玩家及平台方均不能作弊.
    2. 调整roll 游戏规则为可以设置上、下限, 范围限定在95之内. 
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/
pragma solidity ^0.4.20;

contract TRC20I {
  function balanceOf(address owner) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
}

contract HashRoll_TRC20 {  
  TRC20I private _trc20;
  //--------------------------------------------------------------------------------------------------
  // constants.
  uint constant HOUSE_EDGE = 15;
  uint constant MAX_RANGE = 95;
  uint constant BET_EXPIRATION_BLOCKS = 1024;

  // contants. (与币种相关)
  uint constant TOKEN_DECIMAL = 6;
  uint constant MAX_AMOUNT = 1048575 * (10 ** TOKEN_DECIMAL); //hex 0xFFFFF, 40 bits, max VENA amount to bet.

  address constant DUMMY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  //--------------------------------------------------------------------------------------------------
  // storage variables.  
  address public owner;
  address private nextOwner;
  address public croupier;
  address public secretSigner;

  uint public jackpot_modulo = 1000;
  uint128 public jackpotSize;
  uint128 public lockedInBets;

  // storage variables (与币种相关)
  uint public maxProfit = 8000 * (10 ** TOKEN_DECIMAL);
  uint public minBet = 80 * (10 ** TOKEN_DECIMAL);
  uint public minHouseEdge = 4 * (10 ** TOKEN_DECIMAL);

  uint public minJackpotBet = 1000 * (10 ** TOKEN_DECIMAL);
  uint public jackpotFee = 10 * (10 ** TOKEN_DECIMAL);
  
  struct Bet {
    // 投注额(以trx为单位).
    uint40 amount;
    // placeRoll 区块号.
    uint40 placeBlockNumber;
    // 投注范围下限
    uint8 lowerLimit;
    //投注范围上限
    uint8 upperLimit;
    // 投注者地址.
    address gambler;
  }
  // Mapping commit to bets.
  mapping (uint => Bet) private bets;
  
  //--------------------------------------------------------------------------------------------------
  // events.
  event OnCommit(uint commit);
  event OnPay(address indexed beneficiary, uint amount);
  event OnFailedPay(address indexed beneficiary, uint amount);
  event OnJackpotPay(address indexed beneficiary, uint amount);
  
  //--------------------------------------------------------------------------------------------------
  // Contract status management, freeze placeBet while upgrade contract.
  uint8 public status; // 1-active; 2-freezen.
  uint8 constant _ACTIVE = 1;
  uint8 constant _FREEZE = 2;
  
  modifier onlyActive {
    require (status == _ACTIVE, "placeBet Freezen.");
    _;
  }
  
  // Contract status changed.
  event OnFreeze();
  event OnActive();
  
  // Freeze placeBet.
  function freeze() public onlyOwner{
    emit OnFreeze();
    status = _FREEZE;
  }
  
  // Active placeBet.
  function active() public onlyOwner{
    emit OnActive();
    status = _ACTIVE;
  }
  
  //--------------------------------------------------------------------------------------------------
  // modifiers.  
  
  modifier onlyOwner {
    require (msg.sender == owner, "OnlyOwner methods called by non-owner.");
    _;
  }
  
  modifier onlyCroupier {
    require (msg.sender == croupier, "OnlyCroupier methods called by non-croupier.");
    _;
  }
  
  modifier onlyHuman {
    require (msg.sender == tx.origin, "Prohibition of smart contracts.");
    _;
  }
  //--------------------------------------------------------------------------------------------------
  // constructor and fallback.
  constructor () public{
    owner = msg.sender;
    status = _ACTIVE;
    secretSigner = DUMMY_ADDRESS;
    croupier = DUMMY_ADDRESS;
    
    _trc20 = TRC20I(address(0xD9358c1590Bbe1Cb2037D63576e46bFB15A36Ca2));    //shasta
  }
  
  // Fallback function deliberately left empty. It's primary use case
  // is to top up the bank roll.
  function () public payable {
  }
  
  //--------------------------------------------------------------------------------------------------
  // Public operation functions.
  
  // @dev 投注
  // @note 只有本合约签名的commit/reveal对才能进入.
  function placeRoll(uint amount, uint8 _lowerLimit, uint8 _upperLimit, uint _commit, bytes32 _r, bytes32 _s)
    payable
    public
    onlyHuman
    onlyActive
  {
    //验证_commit为"clean"状态.
    Bet storage bet = bets[_commit];
    require (bet.gambler == address(0), "Bet should be in a 'clean' state.");
    
    //验证签名.
    bytes32 signatureHash = keccak256(abi.encodePacked(_commit));
    require (secretSigner == ecrecover(signatureHash, 27, _r, _s), "ECDSA signature is not valid.");
    
    //验证数据范围.
    require (amount >= minBet && amount <= MAX_AMOUNT, "Amount should be within range.");
    
    //转账
    require (_trc20.transferFrom(msg.sender, address(this), amount),"Should approve at first.");
        
      // Winning amount and jackpot increase.
      uint possibleWinAmount;
      uint _jackpot_fee;
      
      (possibleWinAmount, _jackpot_fee) = getWinAmount(amount, _lowerLimit, _upperLimit);
      
      // Enforce max profit limit.
      require (possibleWinAmount <= amount + maxProfit, "maxProfit limit violation.");
      
      // Lock funds.
      lockedInBets += uint128(possibleWinAmount);
      jackpotSize += uint128(_jackpot_fee);
      
      // Check whether contract has enough funds to process this bet.
      require (jackpotSize + lockedInBets <= address(this).balance, "Cannot afford to lose this bet.");
      
      // Record commit in logs.
      emit OnCommit(_commit);
      
      // Store bet parameters on blockchain.
      bet.amount = uint40(amount / (10 ** TOKEN_DECIMAL));
      bet.placeBlockNumber = uint40(block.number);
      bet.lowerLimit = _lowerLimit;
      bet.upperLimit = _upperLimit;
      bet.gambler = msg.sender;
  }
    
  //@dev 开奖
  //@note 客户端将reveal揭示出来之后，开奖原则上可以由任何人触发.
  //  但为了规避风险，还是设置为仅荷官可以开奖.
  function settleBet(uint _reveal, bytes32 _txHash)
    public
    onlyCroupier
  {
      uint commit = uint(keccak256(abi.encodePacked(_reveal)));
      Bet storage bet = bets[commit];
      //验证 commit 状态.
      require(bet.gambler != address(0) && bet.amount > 0, "Bet should be in an 'active' state.");
      //验证 bet 未过期
      require (block.number > bet.placeBlockNumber, "settleBet in the same block as placeBet, or before.");
      require (block.number <= bet.placeBlockNumber + BET_EXPIRATION_BLOCKS, "Bet expired.");
      
      //开奖
      settleBetCore(bet, _reveal, _txHash);
  }
    
  // @dev 回撤
  // @note 如果在限定时间内没有完成开奖，可以回撤投注; 回撤可以由任何人调用.
  function withdraw(uint _commit)
    public
    onlyHuman
  {
    // Check that bet is in 'active' state.
    Bet storage bet = bets[_commit];
    uint amount = bet.amount;
      
    require (amount != 0, "Bet should be in an 'active' state");
      
    // Check that bet has already expired.
    require (block.number > bet.placeBlockNumber + BET_EXPIRATION_BLOCKS, "Bet not yet expired.");
      
    // Move bet into 'processed' state, release funds.
    bet.amount = 0;
      
    uint winAmount;
    uint _jackpot_fee;
    (winAmount, _jackpot_fee) = getWinAmount(amount, bet.lowerLimit, bet.upperLimit);
      
    assert(winAmount <= lockedInBets);
    lockedInBets -= uint128(winAmount);
    // If jackpotSize overflow, that's very few accident, we offered jackpot fee.
    if(_jackpot_fee <= jackpotSize)
      jackpotSize -= uint128(_jackpot_fee);
      
    // Send the refund.
    sendFunds(bet.gambler, amount, amount);
  }
    
  //--------------------------------------------------------------------------------------------------
  //helper functions.
    
  // Core settlement code for settleBet.
  function settleBetCore(Bet storage _bet, uint _reveal, bytes32 _entropyHash) internal {
    // Fetch bet parameters into local variables (to save gas).
    uint amount = _bet.amount * (10 ** TOKEN_DECIMAL);
    uint8 _lowerLimit = _bet.lowerLimit;
    uint8 _upperLimit = _bet.upperLimit;    
    address gambler = _bet.gambler;
      
    // Check that bet is in 'active' state.
    require (amount != 0, "Bet should be in an 'active' state");
      
    // Move bet into 'processed' state already.
    _bet.amount = 0;
      
    // The RNG - combine "reveal" and tx hash of placeBet using Keccak256. Miners
    // are not aware of "reveal" and cannot deduce it from "commit" (as Keccak256
    // preimage is intractable), and house is unable to alter the "reveal" after
    // placeBet have been mined (as Keccak256 collision finding is also intractable).
    bytes32 entropy = keccak256(abi.encodePacked(_reveal, _entropyHash));
      
    // Do a roll by taking a modulo of entropy. Compute winning amount.
    uint roll = uint(entropy) % 100 + 1;
      
    uint winAmount;
    uint _jackpot_fee;
    (winAmount, _jackpot_fee) = getWinAmount(amount, _lowerLimit, _upperLimit);
      
    uint rollWin = 0;
    uint jackpotWin = 0;
      
    // Determine roll outcome.
    if(roll >= _lowerLimit && roll <= _upperLimit){
      rollWin = winAmount;
    }
        
    // Unlock the bet amount, regardless of the outcome.
    assert(winAmount <= lockedInBets);
    lockedInBets -= uint128(winAmount);
        
    // Roll for a jackpot (if eligible).
    if (amount >= minJackpotBet) {
      // The second modulo, statistically independent from the "main" roll.
      // Effectively you are playing two games at once!
      uint jackpotRng = (uint(entropy)/100) % jackpot_modulo;
          
      // Bingo!
      if (jackpotRng == 0) {
        jackpotWin = jackpotSize;
        jackpotSize = 0;
      }
    }
        
    // Log jackpot win.
    if (jackpotWin > 0) {
      emit OnJackpotPay(gambler, jackpotWin);
    }
        
    // Send the funds to gambler.
    sendFunds(gambler, rollWin + jackpotWin == 0 ? 1 sun : rollWin + jackpotWin, rollWin);
  }
      
  // Get the expected win amount after house edge is subtracted.
  function getWinAmount(uint amount, uint8 lower, uint upper) internal view returns (uint winAmount, uint _jackpot_fee) {
    uint rollRange = uint(upper - lower + 1);    
    require ( lower > 0 &&
              upper >= lower && 
              upper <= 100 && 
              rollRange <= MAX_RANGE, "Bet out of range.");
        
    _jackpot_fee = amount >= minJackpotBet ? jackpotFee : 0;
        
    uint _house_edge = amount * HOUSE_EDGE / 1000;
        
    if (_house_edge < minHouseEdge) {
      _house_edge = minHouseEdge;
    }
        
    require (_house_edge + _jackpot_fee <= amount, "Bet doesn't even cover house edge.");
    winAmount = (amount - _house_edge - _jackpot_fee) * 100 / rollRange;
  }
      
  // Standard contract ownership transfer implementation,
  function approveNextOwner(address _nextOwner) public onlyOwner {
    require (_nextOwner != owner && _nextOwner != address(0), "Cannot approve current owner.");
    nextOwner = _nextOwner;
  }
      
  function acceptNextOwner() public {
    require (msg.sender == nextOwner, "Can only accept preapproved new owner.");
    owner = nextOwner;
  }
      
  // Helper routine to process the payment.
  function sendFunds(address beneficiary, uint amount, uint successLogAmount) private {
    if (_trc20.transfer(beneficiary, amount)) {
      emit OnPay(beneficiary, successLogAmount);
    } else {
      emit OnFailedPay(beneficiary, amount);
    }
  }
      
  // See comment for "secretSigner" variable.
  function setSecretSigner(address newSecretSigner) public onlyOwner {
    secretSigner = newSecretSigner;
  }
        
  // Change the croupier address.
  function setCroupier(address newCroupier) public onlyOwner {
    croupier = newCroupier;
  }
        
  // Change max bet reward. Setting this to zero effectively disables betting.
  function setMaxProfit(uint _maxProfit) public onlyOwner {
    require (_maxProfit < MAX_AMOUNT, "maxProfit should be a sane number.");
    maxProfit = _maxProfit;
  }

  function setMinBet(uint _input) public onlyOwner {    
    minBet = _input;
  }

  function setMinHouseEdge(uint _input) public onlyOwner {    
    minHouseEdge = _input;
  }

  function setMinJackpotBet(uint _input) public onlyOwner {    
    minJackpotBet = _input;
  }

  function setJackpotFee(uint _input) public onlyOwner {    
    jackpotFee = _input;
  }

  function setJackpotModulo(uint _input) public onlyOwner {    
    jackpot_modulo = _input;
  }

  // This function is used to bump up the jackpot fund. Cannot be used to lower it.
  function increaseJackpot(uint increaseAmount) public onlyOwner {
    require (increaseAmount <= _trc20.balanceOf(address(this)), "Increase amount larger than balance.");
    require (jackpotSize + lockedInBets + increaseAmount <= _trc20.balanceOf(address(this)), "Not enough funds.");
    jackpotSize += uint128(increaseAmount);
  }
        
  // Funds withdrawal to cover costs of HashDice operation.
  function withdrawFunds(address beneficiary, uint withdrawAmount) public onlyOwner {
    require (withdrawAmount <= _trc20.balanceOf(address(this)), "Increase amount larger than balance.");
    require (jackpotSize + lockedInBets + withdrawAmount <= _trc20.balanceOf(address(this)), "Not enough funds.");
    sendFunds(beneficiary, withdrawAmount, withdrawAmount);
  }
        
  // Contract may be destroyed only when there are no ongoing bets,
  // either settled or refunded. All funds are transferred to contract owner.
  function kill() public onlyOwner {
    require (lockedInBets == 0, "All bets should be processed (settled or refunded) before self-destruct.");
    selfdestruct(owner);
  }

  /**
  * @dev reset TRC20 contract address.
    */
  function resetNetwork(address _addr) 
    public
    onlyOwner
    returns(bool)
  {
    require (getCodeSize(_addr)>0);     
    _trc20 = TRC20I(_addr);
    return true;
  }

  /**
  * @dev get code size of appointed address.
    */
  function getCodeSize(address _addr) 
    internal 
    view 
    returns(uint _size) 
  {
    assembly {
      _size := extcodesize(_addr)
    }
  }
}      