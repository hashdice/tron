const config = require("../config.js");

var _addr = config.environments.shasta.address;

contract('HashDice Token', function() {
    it("freeze energy: ", async function (){
        let _txhash = await tronWeb.transactionBuilder.freezeBalance(5000 * 1e6, 3, "ENERGY");
        console.log(_txhash);
    });

    /*
    it("unfreeze energy and bankwidth: ", async function (){
        let _txhash = await tronWeb.transactionBuilder.unfreezeBalance("ENERGY", _addr);
        console.log(_txhash);

        _txhash = await tronWeb.transactionBuilder.unfreezeBalance("BANDWIDTH", _addr);
        console.log(_txhash);
    }); */
})
