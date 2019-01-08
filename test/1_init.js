
const config = require('../config.js');

var _addr = config.environments.hashdice.address;
var _contract = config.hashdice.contract;

contract('HashDice', function() {
    /*it("get contract instance", async function getContract(){
        let res = await tronWeb.contract().at(_contract);
        console.log(res);
    });*/
 
    it("get account", async function getAccount(){
        await tronWeb.trx.getAccount(_addr).then(console.log);
    });

    it("get account resources", async function getAccountResources(){
        await tronWeb.trx.getAccountResources(_addr).then(console.log);
    }); 
})