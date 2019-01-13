
const _txhash = "0xb6472cfacec7aadca561b782ab22ec71871fb5abe7a54a6c206c947a7c3d931b";

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