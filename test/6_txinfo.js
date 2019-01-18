
const _txhash = "20d7352a9fde38c2aa5d2b19bb6e1f10395cd4146ab0ea492a381c5f5791a29d";

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