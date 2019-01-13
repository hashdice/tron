const config = require('../config.js');
var contract_addr = config.hashdice.vena.contract;
var hdt_addr = config.hdt.contract_hex;

const _commit = new Array("",
                        "");

contract('HashDice', function() {  
    
    /*for(let i=0;i<_commit.length;i++){
        it("withdraw: " + _commit[i], async function (){        
            let res = await tronWeb.contract().at(contract_addr);
            let ret = await res.withdraw(_commit[i]).send({
                feeLimit: 100000000,
                shouldPollResponse:false});
            
            console.log(ret);                
        });
    }*/

    /*
    it("reset hdt network: ", async function (){        
        let res = await tronWeb.contract().at(contract_addr);
        let _tx_hash = await res.resetNetwork(hdt_addr).send({
            feeLimit: 100000000,
            shouldPollResponse:false});

        console.log(_tx_hash);   

        await tronWeb.trx.getTransactionInfo(_tx_hash)
        .then(ret => {
            console.log(ret);
        });
    }); */

    /*
    it("withdraw funds: ", async function (){        
        let res = await tronWeb.contract().at(contract_addr);
        let ret = await res.withdrawFunds("",5000 * 1e6).send({
            feeLimit: 100000000,
            shouldPollResponse:false});

        console.log(ret);        
    }); */

    /*
    it("kill contract: ", async function (){        
        let res = await tronWeb.contract().at(contract_addr);
        let ret = await res.kill().send({
            feeLimit: 100000000,
            shouldPollResponse:false});

        console.log(ret);        
    }); */
})