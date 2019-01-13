
const config = require('../config.js');

var _contract = config.hashdice.trx.contract;

const _commit = "0xe4e070bd637a6a9b962e1dfcf0aa9a515743cf37ebc18fbf7527a79286dcd00f";

contract('HashDice', function() {
    it("get bet info: " + _commit, async function (){
        let res = await tronWeb.contract().at(_contract);
        await res.bets(_commit).call().then(console.log);
    });
})

