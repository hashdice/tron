const TronWeb = require('tronweb');
const config = require('../config.js');

var _hdt_addr = config.hashdice.trx.contract;
var _dice_addr = config.hashdice.trx.contract

contract('HashDice', function() {
    var _blocknum = 5965550;

    it("get hashdice contract events...", async function (){     
        for(i=0;i<10;i++){            
            await tronWeb.getEventResult(
                _dice_addr,
                0,
                "OnCommit",
                _blocknum + i,
                20,
                1
            ).then(ret => {
                console.log("block number: " );
                console.log(ret);
            });    
        }
    });    

    it("get hdt trc20 contract events...", async function (){    
        for(i=0;i<10;i++){            
            await tronWeb.getEventResult(
                _hdt_addr,
                0,
                "Freeze",
                _blocknum + i,
                20,
                1
            ).then(ret => {
                console.log("block number: " );
                console.log(ret);
            });    
        }
    });    
})