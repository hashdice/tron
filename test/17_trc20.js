const config = require('../config.js');

var _contract_addr = config.vena.contract;

var _addr = config.hashdice.vena.contract_hex;
var _to = config.hashdice.vena.contract_hex;
var _value = 10000;

var _vena_decimal = 1e8;
var _hdt_decimal = 1e9;

contract('VENA TRC20', function() {
    it("get balance", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _balance = await res.balanceOf(_addr).call();
        console.log("address: " + _addr + " Balance: " + _balance); 
    });            
    
    /*
    it("transfer", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        await res.transfer(_to, _value * _vena_decimal).send();

        let _balance = await res.balanceOf(_addr).call();
        console.log("from address: " + _addr + " Balance: " + _balance); 
        _balance = await res.balanceOf(_to).call();
        console.log("to address: " + _to + " Balance: " + _balance); 
    });  */

    /*
    it("allowance", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _allow = await res.allowance(_addr, _to).call();
        console.log("owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);
    });  */

    /*it("approve", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        await res.approve(_to, 1000 * 1e9).send();

        let _allow = await res.allowance(_addr, _to).call();
        console.log("owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);
    });  */

    /*it("increase allowance.", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _allow = await res.allowance(_addr, _to).call();
        console.log("before ------------ owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);

        await res.increaseAllowance(_to, 10000000000000).send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        _allow = await res.allowance(_addr, _to).call();
        console.log("after ------------ owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);
    });  */

    /*it("decrease allowance.", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _allow = await res.allowance(_addr, _to).call();
        console.log("before ------------ owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);

        await res.decreaseAllowance(_to, 500000000000).send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        _allow = await res.allowance(_addr, _to).call();
        console.log("after ------------ owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);
    });  */

    /*
    it("transfer from", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _balance = await res.balanceOf(_addr).call();
        console.log("before transfer.");
        console.log("from address: " + _addr + " Balance: " + _balance); 

        await res.transferFrom(_addr, _to, 100000000000).send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        console.log("after transfer.");
        _balance = await res.balanceOf(_addr).call();
        console.log("from address: " + _addr + " Balance: " + _balance); 
        _balance = await res.balanceOf(_to).call();
        console.log("to address: " + _to + " Balance: " + _balance); 

        let _allow = await res.allowance(_addr, _to).call();
        console.log("owner address: " + _addr);
        console.log("spender address: " +  _to + " Allowance: " + _allow);
    });  */

    /*
    it("freeze", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _balance = await res.balanceOf(_addr).call();
        console.log("before freeze.");
        console.log("address: " + _addr + " Balance: " + _balance); 

        await res.freeze(500 * 1e9).send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        _balance = await res.balanceOf(_addr).call();
        console.log("after freeze.");
        console.log("address: " + _addr + " Balance: " + _balance); 

        let _forzen = await res.frozenOf(_addr).call();
        console.log("address: " + _addr + " Frozen: " + _forzen); 
    }); 
    
    it("thaw", async function (){
        let res = await tronWeb.contract().at(_contract_addr);
        
        let _forzen = await res.frozenOf(_addr).call();
        console.log("before thaw. address: " + _addr + " Frozen: " + _forzen); 
        let _thaws = await res.thawsOf(_addr).call();
        console.log("before thaw. address: " + _addr + " Thaws: " + _thaws); 

        await res.thaw(200 * 1e9).send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        _forzen = await res.frozenOf(_addr).call();
        console.log("after thaw. address: " + _addr + " Frozen: " + _forzen); 
        _thaws = await res.thawsOf(_addr).call();
        console.log("after thaw. address: " + _addr + " Thaws: " + _thaws); 

        let _last_thaw_time = await res.lastThawTime(_addr).call();
        console.log("address: " + _addr + " Last Thaw Time: " + _last_thaw_time);
    }); 

 
    it("cancel thaw", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _forzen = await res.frozenOf(_addr).call();
        console.log("before cancel thaw. address: " + _addr + " Frozen: " + _forzen); 
        let _thaws = await res.thawsOf(_addr).call();
        console.log("before cancel thaw. address: " + _addr + " Thaws: " + _thaws); 

        await res.cancelThaw().send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        _forzen = await res.frozenOf(_addr).call();
        console.log("after cancel thaw. address: " + _addr + " Frozen: " + _forzen); 
        _thaws = await res.thawsOf(_addr).call();
        console.log("after cancel thaw. address: " + _addr + " Thaws: " + _thaws); 

        let _last_thaw_time = await res.lastThawTime(_addr).call();
        console.log("address: " + _addr + "Last Thaw Time: " + _last_thaw_time);
    });*/

    /*
    it("withdraw", async function (){
        let res = await tronWeb.contract().at(_contract_addr);
                
        let _thaws = await res.thawsOf(_addr).call();
        console.log("before withdraw. address: " + _addr + " Thaws: " + _thaws); 

        await res.withdraw().send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });
        
        _thaws = await res.thawsOf(_addr).call();
        console.log("after withdraw. address: " + _addr + " Thaws: " + _thaws); 
    }); */

    /*it("burn", async function (){
        let res = await tronWeb.contract().at(_contract_addr);

        let _value = '200000000000000000'; //'0x‭2c68af0bb140000'‬;
        await res.burn(_value).send({
            feeLimit:   10000000,
            shouldPollResponse: false
        }).then(result => {
            console.log("tx hash: " + result);
        });

        let _balance = await res.balanceOf(_addr).call();
        console.log("address: " + _addr + " Balance: " + _balance);

        let _total = await res.totalSupply().call();
        console.log("total supply: " + _total);
    });*/
})