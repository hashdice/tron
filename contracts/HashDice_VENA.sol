/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HashDice: a Block Chain Gambling Game.

Don't trust anyone but the CODE!
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

    本合约仅接受VENA投注.
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/
pragma solidity ^0.4.20;

contract VENATRC20I {
  function balanceOf(address owner) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
}

contract HashDice_VENA {
  VENATRC20I private _trc20;
  //--------------------------------------------------------------------------------------------------
  // constants.
  uint constant JACKPOT_MODULO = 1000;

  uint constant MAX_AMOUNT = 100000000 * (10 ** 18);  //100,000,000 VENA;
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
  
  uint128 public jackpotSize;
  uint128 public lockedInBets;
  
  // storage variables (与币种相关的部分)
  uint constant VENA_DECIMAL = 8;

  uint public maxProfit = 100000 * (10 ** VENA_DECIMAL);  //100,000 vena
  uint public minBet = 80 * (10 ** VENA_DECIMAL);        //80 vena
  uint public houseEdge = 15;                 //1.5%
  uint public minHouseEdge = 4 * (10 ** VENA_DECIMAL);   //4 vena

  uint public minJackpotBet = 1000 * (10 ** VENA_DECIMAL);//1000 vena
  uint public jackpotFee = 10 * (10 ** VENA_DECIMAL);     //10 vena

  struct Bet {
    // 投注额(以vena decimal为单位, 1 vena = 10 ** vena decimal).
    uint amount;
    // 游戏类别(取模值).
    uint8 modulo;
    // 赔率 (* modulo/rollUnder),
    // 对于 modulo > MAX_MASK_MODULO 的游戏用 mask 代替.
    uint8 rollUnder;
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
    _trc20 = VENATRC20I(address(0x9725b4E3B16bd317Ae76c845727e64112Da9fe80));                                                                       
  }
  
  // Fallback function revert.
  // this contract don't accept trx directly.
  function () public payable {
    revert();
  }
  
  //--------------------------------------------------------------------------------------------------
  // Public operation functions.
  
  // @dev 投注
  // @note 只有本合约签名的commit/reveal对才能进入.
  function placeBet(uint _amount, uint _betMask, uint _modulo, uint _commit, bytes32 _r, bytes32 _s)    
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
    require (_modulo > 1 && _modulo <= MAX_MODULO, "Modulo should be within range.");
    require (_amount >= minBet && _amount <= MAX_AMOUNT, "Amount should be within range.");
    require (_betMask > 0 && _betMask < MAX_BET_MASK, "Mask should be within range.");

    //转账
    require (_trc20.transferFrom(msg.sender, address(this), _amount),"Should approve at first.");
    
    uint rollUnder;
    uint mask;
    
    if (_modulo <= MAX_MASK_MODULO) {
      // Small modulo games specify bet outcomes via bit mask.
      // rollUnder is a number of 1 bits in this mask (population count).
      // This magic looking formula is an efficient way to compute population
      // count on EVM for numbers below 2**40.
      rollUnder = ((_betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
      mask = _betMask;
      } else {
        // Larger modulos specify the right edge of half-open interval of
        // winning bet outcomes.
        require (_betMask > 0 && _betMask <= _modulo, "High modulo range, betMask larger than modulo.");
        rollUnder = _betMask;
      }
      
      // Winning amount and jackpot increase.
      uint possibleWinAmount;
      uint _jackpot_fee;
      
      (possibleWinAmount, _jackpot_fee) = getDiceWinAmount(_amount, _modulo, rollUnder);
      
      // Enforce max profit limit.
      require (possibleWinAmount <= _amount + maxProfit, "maxProfit limit violation.");
      
      // Lock funds.
      lockedInBets += uint128(possibleWinAmount);
      jackpotSize += uint128(_jackpot_fee);
      
      // Check whether contract has enough funds to process this bet.
      require (jackpotSize + lockedInBets <= _trc20.balanceOf(address(this)), "Cannot afford to lose this bet.");
      
      // Record commit in logs.
      emit OnCommit(_commit);
      
      // Store bet parameters on blockchain.
      bet.amount = _amount;
      bet.modulo = uint8(_modulo);
      bet.rollUnder = uint8(rollUnder);
      bet.placeBlockNumber = uint40(block.number);
      bet.mask = uint40(mask);
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
    (diceWinAmount, _jackpot_fee) = getDiceWinAmount(amount, bet.modulo, bet.rollUnder);
      
    assert(diceWinAmount <= lockedInBets);
    lockedInBets -= uint128(diceWinAmount);
    // If jackpotSize overflow, that's very few accident, we offered _jackpot_fee.
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
    uint amount = _bet.amount;
    uint modulo = _bet.modulo;
    uint rollUnder = _bet.rollUnder;
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
    uint dice = uint(entropy) % modulo;
      
    uint diceWinAmount;
    uint _jackpot_fee;
    (diceWinAmount, _jackpot_fee) = getDiceWinAmount(amount, modulo, rollUnder);
      
    uint diceWin = 0;
    uint jackpotWin = 0;
      
    // Determine dice outcome.
    if (modulo <= MAX_MASK_MODULO) {
      // For small modulo games, check the outcome against a bit mask.
      if ((2 ** dice) & _bet.mask != 0) {
        diceWin = diceWinAmount;
      }        
    } else {
      // For larger modulos, check inclusion into half-open interval.
      if (dice < rollUnder) {
        diceWin = diceWinAmount;
      }          
    }
        
    // Unlock the bet amount, regardless of the outcome.
    assert(diceWinAmount <= lockedInBets);
    lockedInBets -= uint128(diceWinAmount);
        
    // Roll for a jackpot (if eligible).
    if (amount >= minJackpotBet) {
      // The second modulo, statistically independent from the "main" dice roll.
      // Effectively you are playing two games at once!
      uint jackpotRng = (uint(entropy) / modulo) % JACKPOT_MODULO;
          
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
    sendFunds(gambler, diceWin + jackpotWin == 0 ? 1 : diceWin + jackpotWin, diceWin);
  }
      
  // Get the expected win amount after house edge is subtracted.
  function getDiceWinAmount(uint amount, uint modulo, uint rollUnder) internal view returns (uint winAmount, uint _jackpot_fee) {
    require (0 < rollUnder && rollUnder <= modulo, "Win probability out of range.");
        
    _jackpot_fee = amount >= minJackpotBet ? jackpotFee : 0;
        
    uint _house_edge = amount * houseEdge / 1000;
        
    if (_house_edge < minHouseEdge) {
      _house_edge = minHouseEdge;
    }
        
    require (_house_edge + _jackpot_fee <= amount, "Bet doesn't even cover house edge.");
    winAmount = (amount - _house_edge - _jackpot_fee) * modulo / rollUnder;
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

  function setHouseEdge(uint _input) public onlyOwner {    
    houseEdge = _input;
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
  * @dev reset HDT TRC20 contract address.
    */
  function resetNetwork(address _addr) 
    public
    onlyOwner
    returns(bool)
  {
    require (getCodeSize(_addr)>0);     
    _trc20 = VENATRC20I(_addr);
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