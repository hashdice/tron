/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
HashDice: a Block Chain Gambling Game.

Don't trust anyone but the CODE!
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    - HashDice Token (hdt) 私募合约
    
    交易对: trx / hdt

    私募规则：
    1. 募集目标(Hard cap): 6,250,000 trx. 对应 500,000,000 hdt, 比率1:80;
    2. 启动时间为 utc 2019/1/8 00:00:00;
    3. 最小购买单位为 1 trx;
    4. 单账户最高限额: 250,000 trx;
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/
pragma solidity ^0.4.20;

import "./SafeMath.sol";
import "./ReentrancyGuard.sol";

contract HashDiceTRC20I {  
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
}

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
contract HashDiceCrowdsale is ReentrancyGuard {
    using SafeMath for uint256;

    // The token being sold
    HashDiceTRC20I private _token;

    //Max amount of sun to be contributed
    uint256 private _cap;
    uint256 private _individual_cap;

    //Min buy value.
    uint256 constant MIN_VALUE = 1 * (10 ** 6);

    //Individual sum.
    mapping(address => uint256) private _contributions;

    // Address where funds are collected
    address private _wallet;

    // How many token units a buyer gets per sun.
    // The rate is the conversion between sun and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 sun will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    // Amount of sun raised
    uint256 private _sunRaised;

    uint256 private _openingTime;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value suns paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * @dev Smart contract prohibited.
     */
    modifier onlyHuman {
      require (msg.sender == tx.origin, "Prohibition of smart contracts.");
      _;
    }

    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen {
        require(isOpen());
        _;
    }

    /**
     * @dev The rate is the conversion between sun and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 sun will give you 1 unit, or 0.001 TOK.
     */
    constructor () public {
        _token = HashDiceTRC20I(address(0xb123a9807BD8aFBa091719934CD59c403bdd66c8));
        _cap = 6250000 * (10 ** 6);
        _individual_cap = 1250000 * (10 ** 6);
        _wallet = address(0x451E7C33c74Aab0bDC4F8a35b47f1699604F8605);
        _rate = 80 * (10 ** 3);
        _openingTime = 1546905600;
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer fund with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (HashDiceTRC20I) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per sun.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of sun raised.
     */
    function sunRaised() public view returns (uint256) {
        return _sunRaised;
    }

    /**
     * @dev Checks the amount of tokens left in the allowance.
     * @return Amount of tokens left in the allowance
     */
    function remainingTokens() public view returns (uint256) {
        return _token.allowance(_wallet, address(this));
    }

    /**
     * @dev Checks whether the cap has been reached.
     * @return Whether the cap was reached
     */
    function capReached() public view returns (bool) {
        return _sunRaised >= _cap;
    }

    /**
     * @return the crowdsale opening time.
     */
    function openingTime() public view returns (uint256) {
        return _openingTime;
    }

    /**
     * @return true if the crowdsale is open, false otherwise.
     */
    function isOpen() public view returns (bool) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp >= _openingTime;
    }

    /**
     * @dev Returns the amount contributed so far by a specific beneficiary.
     * @param beneficiary Address of contributor
     * @return Beneficiary contribution so far
     */
    function getContribution(address beneficiary) public view returns (uint256) {
        return _contributions[beneficiary];
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary) public nonReentrant onlyHuman payable {
        uint256 sunAmount = msg.value;
        _preValidatePurchase(beneficiary, sunAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(sunAmount);

        // update state
        _sunRaised = _sunRaised.add(sunAmount);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(msg.sender, beneficiary, sunAmount, tokens);

        _updatePurchasingState(beneficiary, sunAmount);
        _forwardFunds();
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, sunAmount);
     *     require(sunRaised().add(sunAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param sunAmount Value in sun involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 sunAmount) internal onlyWhileOpen view {
        require(beneficiary != address(0));
        require(sunAmount >= MIN_VALUE);
        require(_sunRaised.add(sunAmount) <= _cap);
        require(_contributions[beneficiary].add(sunAmount) <= _individual_cap);
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.transferFrom(_wallet, beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Extend parent behavior to update beneficiary contributions
     * @param beneficiary Token purchaser
     * @param sunAmount Amount of wei contributed
     */
    function _updatePurchasingState(address beneficiary, uint256 sunAmount) internal {
        _contributions[beneficiary] = _contributions[beneficiary].add(sunAmount);
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param sunAmount Value in sun to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _sunAmount
     */
    function _getTokenAmount(uint256 sunAmount) internal view returns (uint256) {
        return sunAmount.mul(_rate);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }
}