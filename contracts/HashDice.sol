/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HashDice: a Block Chain Gambling Game.

Don't need to trust anyone but the CODE!
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    - HashDice是一个建立在以太坊区块链上的博彩平台，具有去中心化、公平、透明、可验证等优点，以及不受包括开发者在内的任何个人
    - 和组织操控的特性。

    - 游戏的核心业务逻辑来源于dice2.win的设计!
    - 对合约进行了一些优化：
    - 1) 将commit-reveal + block hash的随机数生成及传递机制,修改为：commit-reveal + tx hash. 
         优点是提高开奖确定性；
    - 2) 只有本合约签名的commit/reveal对才能投注，未签名和已经使用过的commit/reveal对禁入，因此存储不能清除；
    - 3) 增加合约状态管理功能;
    - 4) 处理潜在的溢出风险;
    - 5) 修改roll游戏逻辑;
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/
pragma solidity ^0.4.20;

contract HashDice {
  //--------------------------------------------------------------------------------------------------
  // constants.
  uint constant MAX_MODULO = 100;
  uint constant MAX_MASK_MODULO = 40;
  uint constant MAX_BET_MASK = 2 ** MAX_MASK_MODULO;
  
  uint constant POPCNT_MULT = 0x0000000000002000000000100000000008000000000400000000020000000001;
  uint constant POPCNT_MASK = 0x0001041041041041041041041041041041041041041041041041041041041041;
  uint constant POPCNT_MODULO = 0x3F;
  
  uint constant BET_EXPIRATION_BLOCKS = 1024;
  
  address constant DUMMY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  //--------------------------------------------------------------------------------------------------
  // storage variables.  
  address public owner;
  address private nextOwner;
  address public croupier;
  address public secretSigner;
  uint128 public lockedInBets;
  uint public maxRollRange = 95;
  uint public houseEdge = 25;

  // storage variables (与币种相关的部分)  
  uint constant MAX_AMOUNT = 100000000 trx;

  uint public maxProfit = 2000 trx;
  uint public minBet = 20 trx;
  uint public minHouseEdge = 0.5 trx;  

  //Jackpot
  uint public jackpotModulo = 10000;

  uint128 public goldenPotSize;
  uint public minGoldenPotBet = 500 trx;
  uint public goldenPotFee = 5 trx;
  
  uint128 public silverPotSize;
  uint public minSilverPotBet = 100 trx;
  uint public silverPotFee = 1 trx;

  struct Bet {
    // 投注额(以sun为单位).
    uint amount;
    // 游戏类别(取模值).
    uint8 modulo;
    // 赔率 (* modulo/rollRange),
    // 对于 modulo > MAX_MASK_MODULO 的游戏用 mask 代替.
    uint8 rollRange;
    // placeBet tx 区块号.
    uint40 placeBlockNumber;
    // 投注掩码.
    uint40 mask;
    // 投注者地址.
    address gambler;
  }
  // Mapping commit to bets.
  mapping (uint => Bet) public bets;
  
  //--------------------------------------------------------------------------------------------------
  // events.
  event OnCommit(uint commit);
  event OnPay(address indexed beneficiary, uint amount);
  event OnFailedPay(address indexed beneficiary, uint amount);
  event OnGoldenPotPay(address indexed beneficiary, uint amount);
  event OnSilverPotPay(address indexed beneficiary, uint amount);
  
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
  }
  
  // Fallback function deliberately left empty. It's primary use case
  // is to top up the bank roll.
  function () public payable {
  }
  
  //--------------------------------------------------------------------------------------------------
  // Public operation functions.
  
  // @dev 投注
  // @note 只有本合约签名的commit/reveal对才能进入.
  function placeBet(uint _betMask, uint _modulo, uint _commit, bytes32 _r, bytes32 _s)
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
    uint amount = msg.value;
    require (_modulo > 1 && _modulo <= MAX_MODULO, "Modulo should be within range.");
    require (amount >= minBet && amount <= MAX_AMOUNT, "Amount should be within range.");
    require (_betMask > 0 && _betMask < MAX_BET_MASK, "Mask should be within range.");

    uint rollRange;

    if (_modulo <= MAX_MASK_MODULO) {
      // Small modulo games specify bet outcomes via bit mask.
      // rollRange is a number of 1 bits in this mask (population count).
      // This magic looking formula is an efficient way to compute population
      // count on EVM for numbers below 2**40.
      rollRange = ((_betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
    } else {
        // Larger modulos specify the range roll game.
        uint8 lower = uint8(_betMask);
        uint8 upper = uint8(_betMask >> 8); 
        if((_betMask >> 16) == 0){
          rollRange = upper - lower + 1;    
        } else {
          rollRange = upper > lower ? _modulo - (upper-lower) + 1 : _modulo;
        }

        require ( lower > 0 &&
              upper >= lower && 
              upper <= _modulo && 
              rollRange <= _modulo * maxRollRange / 100, "Roll out of range.");
    }
      
    // Winning amount and jackpot increase.
    uint possibleWinAmount;
    uint _jackpot_fee;
    
    (possibleWinAmount, _jackpot_fee) = getDiceWinAmount(amount, _modulo, rollRange);
    
    // Enforce max profit limit.
    require (possibleWinAmount <= amount + maxProfit, "maxProfit limit violation.");
    
    // Lock funds.
    lockedInBets += uint128(possibleWinAmount);
    if(amount >= minGoldenPotBet){
      goldenPotSize += uint128(_jackpot_fee);
    }      
    else if(amount >= minSilverPotBet){
      silverPotSize += uint128(_jackpot_fee);
    }      
    
    // Check whether contract has enough funds to process this bet.
    require (goldenPotSize + silverPotSize + lockedInBets <= address(this).balance, "Cannot afford to lose this bet.");
    
    // Record commit in logs.
    emit OnCommit(_commit);
    
    // Store bet parameters on blockchain.
    bet.amount = amount;
    bet.modulo = uint8(_modulo);
    bet.rollRange = uint8(rollRange);
    bet.placeBlockNumber = uint40(block.number);
    bet.mask = uint40(_betMask);
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
      
    uint diceWinAmount;
    uint _jackpot_fee;
    (diceWinAmount, _jackpot_fee) = getDiceWinAmount(amount, bet.modulo, bet.rollRange);
      
    assert(diceWinAmount <= lockedInBets);
    lockedInBets -= uint128(diceWinAmount);
    // If jackpot size overflow, that's very few accident, contract offered jackpot fee.
    if(amount >= minGoldenPotBet && _jackpot_fee <= goldenPotSize) {
      goldenPotSize -= uint128(_jackpot_fee);
    }      
    else if(amount >= minSilverPotBet && _jackpot_fee <= silverPotSize) {
      silverPotSize -= uint128(_jackpot_fee);
    }
      
      
    // Send the refund.
    sendFunds(bet.gambler, amount, amount);
  }
    
  //--------------------------------------------------------------------------------------------------
  //helper functions.
    
  // Core settlement code for settleBet.
  function settleBetCore(Bet storage _bet, uint _reveal, bytes32 _entropyHash) internal {
    uint modulo = _bet.modulo;
    uint amount = _bet.amount;
    uint mask = _bet.mask;
    // Check that bet is in 'active' state.
    require (amount != 0, "Bet should be in an 'active' state");

    // The RNG - combine "reveal" and tx hash of placeBet using Keccak256. Miners
    // are not aware of "reveal" and cannot deduce it from "commit" (as Keccak256
    // preimage is intractable), and house is unable to alter the "reveal" after
    // placeBet have been mined (as Keccak256 collision finding is also intractable).
    bytes32 entropy = keccak256(abi.encodePacked(_reveal, _entropyHash));    
      
    // Do a roll by taking a modulo of entropy. Compute winning amount.
    uint dice = uint(entropy) % modulo;

    uint diceWinAmount;
    uint jackpot_fee;
    (diceWinAmount, jackpot_fee) = getDiceWinAmount(amount, modulo, _bet.rollRange);
      
    uint diceWin = 0;
    uint jackpotWin = 0;
      
    // Determine dice outcome.
    if (modulo <= MAX_MASK_MODULO) {
      // For small modulo games, check the outcome against a bit mask.
      if ((2 ** dice) & mask != 0) {
        diceWin = diceWinAmount;
      }        
    } else {
      // For larger modulos, check inside/outside of roll range.
      if((mask >> 16)==0){
        if (dice >= (uint8(mask) - 1) && dice <= (uint8(mask >> 8) - 1)) {
          diceWin = diceWinAmount;
        }
      } else {
        if (dice <= (uint8(mask) - 1) || dice >= (uint8(mask >> 8) - 1)) {
          diceWin = diceWinAmount;
        }
      }                
    }
        
    // Unlock the bet amount, regardless of the outcome.
    assert(diceWinAmount <= lockedInBets);
    lockedInBets -= uint128(diceWinAmount);
    
    // Roll for a jackpot (if qualified).
    uint jackpotRng = (uint(entropy) / modulo) % jackpotModulo;
    if(jackpotRng == 0) {
      if(amount >= minGoldenPotBet) {
        jackpotWin = goldenPotSize;
        goldenPotSize = 0;
        //Log jackpot pay
        emit OnGoldenPotPay(_bet.gambler, jackpotWin);
      }
      else if(amount >= minSilverPotBet){
        jackpotWin = silverPotSize;
        silverPotSize = 0;
        //Log jackpot pay
        emit OnSilverPotPay(_bet.gambler, jackpotWin);
      }
    }
 
    // Move bet into 'processed' state already.
    _bet.amount = 0;    

    // Send the funds to gambler.
    if(diceWin + jackpotWin > 0){
      sendFunds(_bet.gambler, diceWin + jackpotWin, diceWin);
    }
    else{
      emit OnPay(_bet.gambler, 0);
    }    
  }
      
  // Get the expected win amount after house edge is subtracted.
  function getDiceWinAmount(uint amount, uint modulo, uint rollRange) internal view returns (uint winAmount, uint _jackpot_fee) {
    require (0 < rollRange && rollRange <= modulo, "Win probability out of range.");
        
    _jackpot_fee = amount >= minGoldenPotBet ? goldenPotFee : (amount >= minSilverPotBet ? silverPotFee : 0);
        
    uint _house_edge = amount * houseEdge / 1000;
        
    if (_house_edge < minHouseEdge) {
      _house_edge = minHouseEdge;
    }
        
    require (_house_edge + _jackpot_fee <= amount, "Bet doesn't even cover house edge.");
    winAmount = (amount - _house_edge - _jackpot_fee) * modulo / rollRange;
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
    if (beneficiary.send(amount)) {
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

  function setHouseEdge(uint _input) public onlyOwner {    
    houseEdge = _input;
  }

  function setMinHouseEdge(uint _input) public onlyOwner {    
    minHouseEdge = _input;
  }

  function setMinGoldenPotBet(uint _input) public onlyOwner {    
    minGoldenPotBet = _input;
  }

  function setMinSilverPotBet(uint _input) public onlyOwner {    
    minSilverPotBet = _input;
  }

  function setGoldenPotFee(uint _input) public onlyOwner {    
    goldenPotFee = _input;
  }

  function setSilverPotFee(uint _input) public onlyOwner {    
    silverPotFee = _input;
  }

  function setJackpotModulo(uint _input) public onlyOwner {    
    jackpotModulo = _input;
  }

  function setMaxRollRange(uint _input) public onlyOwner {    
    maxRollRange = _input;
  }  

  // This function is used to bump up the golden jackpot fund. Cannot be used to lower it.
  function increaseGoldenPot(uint increaseAmount) public onlyOwner {
    require (goldenPotSize + silverPotSize + lockedInBets + increaseAmount <= address(this).balance, "Not enough funds.");
    goldenPotSize += uint128(increaseAmount);
  }

  // This function is used to bump up the silver jackpot fund. Cannot be used to lower it.
  function increaseSilverPot(uint increaseAmount) public onlyOwner {
    require (goldenPotSize + silverPotSize + lockedInBets + increaseAmount <= address(this).balance, "Not enough funds.");
    silverPotSize += uint128(increaseAmount);
  }
        
  // Funds withdrawal to cover costs of HashDice operation.
  function withdrawFunds(address beneficiary, uint withdrawAmount) public onlyOwner {
    require (withdrawAmount <= address(this).balance, "Increase amount larger than balance.");
    require (goldenPotSize + silverPotSize + lockedInBets + withdrawAmount <= address(this).balance, "Not enough funds.");
    sendFunds(beneficiary, withdrawAmount, withdrawAmount);
  }
        
  // Contract may be destroyed only when there are no ongoing bets,
  // either settled or refunded. All funds are transferred to contract owner.
  function kill() public onlyOwner {
    require (lockedInBets == 0, "All bets should be processed (settled or refunded) before self-destruct.");
    selfdestruct(owner);
  }
}      