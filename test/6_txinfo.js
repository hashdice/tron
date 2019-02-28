
const _txhash = "0dd92cfd3820eb652f8c17b33bc0d4b73efe9da624f59021702c29ee29ce124c";

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