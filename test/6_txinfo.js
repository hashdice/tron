
const _txhash = "657742cca36b14285465eb53f9ad59b1332edd2e62a62dd5a8687df15e539768";

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