pragma solidity ^0.4.20;

import "./SafeMath.sol";

/**
 * @title HashDice TRC20 token
 *
 * @dev HashDice 标准 ERC20 可销毁代币.
    起始总供应量：   100亿
    name:           HashDice
    symbol:         HDT
    decimals:       9
        
    ERC20 标准没有定义increaseAllowance, decreaseAllowance 函数，这里采用的是openzeppelin的实现，增加了这两个函数.

    由于HashDice token要承担冻结、解冻、领取的业务逻辑，所以增加了相关参数、事件及函数。
    冻结、解冻、领取的业务逻辑如下:
    1) 冻结下限为100 hdt;
    2) 冻结后可以立即解冻;
    3) 解冻下限为100 hdt;
    4) 解冻可以撤销，撤销是将解冻金额全部重新冻结;
    5) 解冻金额24小时之后才能领取，领取是全部领取;

    事件触发机制:
    1. 冻结时，触发Freeze事件;
    2. 领取时，触发Transfer事件，从TRC20合约向用户转账;
    3. 解冻时，触发Traw事件;
    4. 撤销解冻时，触发Traw事件，解冻金额为0;
    由于原本TRC20合约本身没有余额，引入了冻结、解冻逻辑之后，如果直接使用Transfer事件累加计算余额的话，TRC20合约本身会有余额，
    而在合约中取TRC20合约地址的余额，却依然会是0.
 */

contract HashDiceTRC20{
    using SafeMath for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    //冻结业务逻辑相关参数.    

    uint constant private FREEZE_PERIOD = 24 hours;
    uint constant private MIN_FREEZE = 100 * (10 ** 9);
    uint constant private MIN_THAW = 100* (10 ** 9);

    mapping (address => uint256) private _frozen;
    mapping (address => uint256) private _thaws;
    mapping (address => uint256) private _last_thaw_time;

    event Freeze(address indexed from, uint256 value);
    event Thaw(address indexed from, uint256 value);

    /**
     * @dev constructor function.
     */
    constructor () public {
        _name = "HashDice";
        _symbol = "HDT";
        _decimals = 9;
        _totalSupply = 10000000000 * (10 ** 9);
        _balances[msg.sender] = _totalSupply;
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
    * @dev Total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev Gets the frozen of the specified address.
    * @param owner The address to query the frozen of.
    * @return An uint256 representing the amount frozen by the passed address.
    */
    function frozenOf(address owner) public view returns (uint256) {
        return _frozen[owner];
    }

    /**
    * @dev Gets the thaws token of the specified address.
    * @param owner The address to query the frozen of.
    * @return An uint256 representing the amount thaws by the passed address.
    */
    function thawsOf(address owner) public view returns (uint256) {
        return _thaws[owner];
    }

    /**
    * @dev Gets the last frozen time of the specified address.
    * @param owner The address to query the last frozen time of.
    * @return An uint256 representing the last frozen time by the passed address.
    */
    function lastThawTime(address owner) public view returns (uint256) {
        return _last_thaw_time[owner];
    }

    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
    * @dev Freeze token.
    * @param value The amount to be frozen.
    */
    function freeze(uint256 value) public returns (bool) {
        require( value >= MIN_FREEZE );

        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _frozen[msg.sender] = _frozen[msg.sender].add(value);

        emit Freeze(msg.sender, value);
        return true;
    }

    /**
    * @dev Thaw token.
    * @param value The amount to be thaw.
    */
    function thaw(uint256 value) public returns (bool) {
        require( value >= MIN_THAW );

        _last_thaw_time[msg.sender] = now;

        _frozen[msg.sender] = _frozen[msg.sender].sub(value);
        _thaws[msg.sender] = _thaws[msg.sender].add(value);

        emit Thaw(msg.sender, value);
        return true;
    }

    /**
    * @dev Cancel thaw token.
    */
    function cancelThaw() public returns (bool) {
        _last_thaw_time[msg.sender] = 0;

        uint256 _temp = _thaws[msg.sender];
        _thaws[msg.sender] = 0;
        _frozen[msg.sender] = _frozen[msg.sender].add(_temp);
        
        emit Thaw(msg.sender, 0);
        return true;
    }

    /**
    * @dev Withthaw thawed token.
    */
    function withdraw() public returns (bool) {
        require( _last_thaw_time[msg.sender] + FREEZE_PERIOD < now );

        uint256 _temp = _thaws[msg.sender];
        _thaws[msg.sender] = 0;
        _balances[msg.sender] = _balances[msg.sender].add(_temp);

        emit Transfer(address(this), msg.sender, _temp);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The address which you want to send tokens from
     * @param value uint256 The amount of token to be burned
     */
    function burnFrom(address from, uint256 value) public {
        _burnFrom(from, value);
    }

    /**
    * @dev Transfer token for a specified addresses
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
        emit Approval(account, msg.sender, _allowed[account][msg.sender]);
    }
}