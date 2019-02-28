const config = require('../config.js');

var _contract_addr = 'TJpw9juMWzHLnJJbVZ9exPMrMKpuXHFLt6'; //config.hashdice.contract;
var _signer_hex = '0x8Bb2e6DF4bEd2dEDbF4CF69D1321d55f234e2f71';
var _croupier_hex = '0x52a33D828482c31836e578E482E130f07D562d9e';

contract('HashDice', function() {
    /*
    //-------set max profit-----------------------------------------------------------
    it("set max profit", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        await res.setMaxProfit(50000 * 1e9).send();
        let _max_profit = await res.maxProfit().call();
        console.log("Max Profit: " + _max_profit); 
    });    */
    
    //-------set secret signer---------------------------------------------------------
    it("set secret signer", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        await res.setSecretSigner(_signer_hex).send();
        let _signer = await res.secretSigner().call();
        console.log("Secret Signer HEX: " + _signer); 
        console.log("Secret Signer: " + tronWeb.address.fromHex(_signer)); 
    });  

    //-------set croupier---------------------------------------------------------
    it("set croupier", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        await res.setCroupier(_croupier_hex).send();
        let _croupier = await res.croupier().call();
        console.log("Croupier HEX: " + _croupier); 
        console.log("Croupier: " + tronWeb.address.fromHex(_croupier)); 
    });  
    /*
    //-------set min bet---------------------------------------------------
     it("set min bet", async function (){
        let res = await tronWeb.contract().at(_contract_addr);
        
        await res.setMinBet(20 * 1e9).send();
        let _min_bet = await res.minBet().call();
        console.log("Min Bet: " + _min_bet); 
    });  

    
    //-------set min house edge---------------------------------------------------
    it("set min house edge", async function (){
        let res = await tronWeb.contract().at(_contract_addr);
        
        await res.setMinHouseEdge(1 * 1e9).send();
        let _min_house_edge = await res.minHouseEdge().call();
        console.log("Min House Edge: " + _min_house_edge); 
    });  
    

    //-------set min jackpot bet---------------------------------------------------
    it("set min jackpot bet", async function (){
        let res = await tronWeb.contract().at(_contract_addr);
        
        await res.setMinJackpotBet(500 * 1e9).send();
        let _min_jackpot_bet = await res.minJackpotBet().call();
        console.log("Min Jackpot Bet: " + _min_jackpot_bet); 
    });  

    //-------set jackpot fee---------------------------------------------------
    it("set jackpot fee", async function (){
        let res = await tronWeb.contract().at(_contract_addr);
        
        await res.setJackpotFee(5 * 1e9).send();
        let _jackpot_fee = await res.jackpotFee().call();
        console.log("Jackpot Fee: " + _jackpot_fee); 
    });  
    */

    //-------approve next owner---------------------------------------------------------
    it("approve next owner", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        await res.approveNextOwner('TRoN7dtFeZRMMeWBRKYcJVPkZaozK6PmKK').send();
    });  
})