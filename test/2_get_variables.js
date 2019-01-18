
const config = require('../config.js');

var _contract_addr = config.hashdice.trx.contract;

contract('HashDice', function() {
    it("get contract variables", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _owner = await res.owner().call();
        console.log("Owner:" + _owner); 

        let _status = await res.status().call();
        console.log("Status:" + _status);  

        let _croupier = await res.croupier().call();
        console.log("Croupier:" + _croupier);   
        
        let _signer = await res.secretSigner().call();
        console.log("Secret Signer:" + _signer);  
        
        let _max_profit = await res.maxProfit().call();
        console.log("Max Profit:" + _max_profit);        
                
        let _min_bet = await res.minBet().call();
        console.log("Min Bet:" + _min_bet);  

        let _house_edge = await res.houseEdge().call();
        console.log("House Edge:" + _house_edge);  

        let _min_house_edge = await res.minHouseEdge().call();
        console.log("Min House Edge:" + _min_house_edge); 

        let _min_jackpot_bet = await res.minJackpotBet().call();
        console.log("Min Jackpot Bet:" + _min_jackpot_bet);

        let _jackpot_fee = await res.jackpotFee().call();
        console.log("Jackpot Fee:" + _jackpot_fee);

        let _jcakpot = await res.jackpotSize().call();
        console.log("Jackpot Size:" + _jcakpot); 
        
        let _lock = await res.lockedInBets().call();
        console.log("Locked in Bets:" + _lock); 

        let _balance = await tronWeb.trx.getBalance(_contract_addr);;
        console.log("contract balance: " + _balance);
    });    
})