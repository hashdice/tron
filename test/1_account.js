
const config = require('../config.js');

var _addr = config.environments.hashdice.address;
var _contract = config.hashdice.contract;

contract('HashDice', function() { 
    it("get account", async function getAccount(){
        await tronWeb.trx.getAccount(_addr).then(console.log);    
    });

    it("get account resources", async function getAccountResources(){
        await tronWeb.trx.getAccountResources(_addr).then(console.log);
    }); 
})