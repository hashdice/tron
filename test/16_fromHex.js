const config = require('../config.js');

contract('HashDice', function() {
    it("get contract variables", async function (){
        let account = "";

        console.log("hex: " + account);
        let _account = tronWeb.address.fromHex('4177e11a65793bb6549f4ef20da6cf399fb9b3bfc5');
        console.log("base58: " + _account);
    });    
})