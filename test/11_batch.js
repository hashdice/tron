
var request = require('request');
const config = require('../config.js');

//var account_addr = config.environments.shasta.address;
var contract_addr = 'TTfiDSFUmQHi88SuPRQfs8zmtzpCuvPbmC';
var _betnum = 1;

contract('HashDice', function() {
    /*  程序逻辑
    *   1.用一个promise.all，获取全部所需的随机数，完成之后再投注;
    *   2.异步方式投注; 
    */

    it("batch test -- " + _betnum + " times place bet. ", async function (){
        let contract = await tronWeb.contract().at(contract_addr);

        let j=0;
        for (var i = 0; i < _betnum; i++) {                       
            let r =      "0x90f1a8aa791c0b60256c0c724db2805a10f2f97ef02a77f1e8eeda0219aeeb3b";
            let s =      "0x37734be53c950ee49bc80fa748b41cbf5f2df78df1ec73904d5ac0a587edd238";
            let commit = "0xce31d78cca6b30dd77ba360be3a9aa278b5b1911ddbfc8c0cf9ee89c1dcc8a7f";
            
            await contract.placeRoll(5 ,15, commit, r, s).send({
                feeLimit:   10000000,
                callValue:  20000000,   //20 trx
                shouldPollResponse: false
            }).then(console.log);                           
        }
       
        //testBet(_betnum);

        async function testBet(betnum) {
            var promiseList = [];        
            //获取随机数
            let j=0;
            for (var i = 0; i < betnum; i++) {
                var p = new Promise(function(resolve, reject){
                    getRandom(account_addr).then(function(res){   
                        console.log("get random: " + res);                     
                        let r = res.secret.signature.r;
                        let s = res.secret.signature.s;
                        let commit = res.secret.commit;
                        
                        contract.placeBet(70 * 1e9 ,0x31, 6, commit, r, s).send({
                            feeLimit:   10000000,
                            //callValue:  20000000,
                            shouldPollResponse: false
                        }).then(result => {
                            j++;
                            console.log("place bet no. " + j);
                            console.log("tx hash: " + result);
                            console.log("commit: ", commit);
                            console.log("r: ", r);
                            console.log("s: ", s); 
                            resolve(commit);
                        }).catch(err => {
                            resolve(err);
                        });    
                    })
                })
        
                promiseList.push(p);
            };
         
            Promise.all(promiseList).then(function(results){
                setTimeout(async () => {
                    for (var i = 0; i < betnum; i++) {
                        console.log("get bet result. " + (i + 1));
                        console.log("commit: " + results[i]);
                        await contract.bets(results[i]).call().then(console.log);
                    }
                }, 60000);
            });
        }
    });
        
    async function getRandom(tsAddress) {
        return new Promise(resolve => {
            let options = {
                method:'post',
                json:true,
                rejectUnauthorized: false,
                url:"https://hashdice.org/tron/api/v1/games/random",
                headers: {
                    "content-type":"application/json",
                },
                body: {
                    filter:{
                        address:tsAddress,
                        token_type:"HDT",
                        networkId:1
                    }
                }
            };
    
            request(options, function (err, res, body) {
                if (err) {
                    console.log(err);
                    resolve(null);
                } else {
                    resolve(body.data);
                }
            });
        });
    }
})