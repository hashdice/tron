
const config = require('../config.js');

var _contract = config.hashdice.trx.contract;

const _commit = "0xce31d78cca6b30dd77ba360be3a9aa278b5b1911ddbfc8c0cf9ee89c1dcc8a7f";

contract('HashDice', function() {
    it("get bet info: " + _commit, async function (){
        let res = await tronWeb.contract().at(_contract);
        await res.bets(_commit).call().then(console.log);
    });
})

