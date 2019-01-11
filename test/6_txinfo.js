
const _txhash = "f987099dd21b67e2c5fa28d25e0e8aae89b332d9bbd1e6f7fda53f25c3658172";

contract('HashDice', function() {
    it("get tx info...", async function (){
        await tronWeb.trx.getTransaction(_txhash)
            .then(console.log);
            
        await tronWeb.trx.getTransactionInfo(_txhash)
            .then(ret => {
                console.log(ret);
            });
    });    
})