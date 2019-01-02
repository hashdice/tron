
contract('HashDice', function() {
    it("get contract variables", async function (){
        let account = "";

        console.log("hex: " + account);
        let _account = tronWeb.address.fromHex(account);
        console.log("base58: " + _account);
    });    
})