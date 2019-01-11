
const config = require('../config.js');

var _contract_addr = 'TEEXEWrkMFKapSMJ6mErg39ELFKDqEs6w3';

contract('Tronbet', function() {
    it("tronbet goodluck function.", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _tx_info = await res.GoodLuck(5, 1).send({
            callValue:  tronWeb.toSun(20)
        });
        console.log(_tx_info);
    });
})