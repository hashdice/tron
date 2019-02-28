
const config = require('../config.js');

var _contract = 'TR1i1AxQgdoN5A6WTfkp5U2UzvybqGV3EW';

const _commit = "0x8f395f765cc17c47669d8985e1c8fa7bfb7a33cc0241931c5ae64adac37d5f4a";

contract('HashDice', function() {
    it("get bet info: " + _commit, async function (){
        let res = await tronWeb.contract().at(_contract);
        await res.bets(_commit).call().then(console.log);
    });
})

