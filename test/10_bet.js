
const config = require('../config.js');

var _contract = config.hashdice.contract;

const _commit = "";

contract('HashDice', function() {
    it("get bet info: " + _commit, async function (){
        let res = await tronWeb.contract().at(_contract);
        await res.bets(_commit).call().then(console.log);
    });
})

