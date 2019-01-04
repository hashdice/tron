
const config = require('../config.js');

contract('HashDice', function() {
    it("to hex.", async function (){
        let account = config.environments.hdt.address;

        console.log("base58: " + account);
        let _account = tronWeb.address.toHex(account);
        console.log("HEX: " + _account);
    });    
})