# HashDice Open Source Announcement !!!
------------

In the world of Blockchain, We firmly believe in WE DON'T NEED TO TRUST ANYTHING BUT THE CODE !!!  

“Code is law”, it does not lie, blockchain developers can't break this baseline. So our motivation moving forward is  transparency being the best decision for Hashdice future, we shall be releasing our source code for all to view, lets let the Code do the talking.  

Although Tron doesn't provide the same verification tool currently used by Ethereum on Etherscan, it's no excuse for Dapp developers to centralize/manipulate the system. The core difference between decentralized apps and centralized apps is clear for all to see, we're dedicated to being an open and transparent decentralized application.  

The Hashdice team has decided to lead the way by providing the verification tool linked to our Open Source Code.   

## Code Verification Method
Instructions below should make this facility accessable to all.

1. Install node.js and npm.  
a) NodeJs official website: https://nodejs.org  
b) Requires NodeJS 5.0+. Check version:   
```  
node -v  
```  

2. Install the tronbox  
```  
npm install -g tronbox  
```  

3. Download the source from github  
a) Create a new directory called hashdice and enter the directory.  
b) git clone [https://github.com/hashdice/tron.git](https://github.com/hashdice/tron.git).  
```  
git clone https://github.com/hashdice/tron.git  
```  

4. Deploy smart contracts on the shasta test chain.  
   a) Open tronbox.js and using your address and private key replace the comment.  
```  
    shasta: {  
      from: 'your address',  
      privateKey: 'your private key'
    }
```  
   b) Run tronbox migrate command.  
```  
tronbox migrate –-reset –-network shasta.  
```    
   c) Record the smart contract address deployed at
Https://shasta.tronscan.org/#/contract/’contract address’
View contract abi and bytecode.


5. Compare the formal contract with the api and bytecode of the contract you're deploying. Due to the differences in the Tronbox versions, bytecode may have subtle differences for individual user but should not have any affect on the substantive functionality.  

The official HashDice contract has been deployed at the following addresses:  

HashDice: [https://tronscan.org/#/contract/TVWT2gVe2uKASxKYasFzc8uM5b4x1UFwmd](https://tronscan.org/#/contract/TVWT2gVe2uKASxKYasFzc8uM5b4x1UFwmd)   
HashDice(Vena): [https://tronscan.org/#/contract/TH7u3qDLrz7DKH6UPBgEwFBYBitSEfEYtq](https://tronscan.org/#/contract/TH7u3qDLrz7DKH6UPBgEwFBYBitSEfEYtq)  
HDT TRC20 token: [https://tronscan.org/#/contract/TS7qKrrHe5GUJmpqo7s4tAPNcasPh7umFM](https://tronscan.org/#/contract/TS7qKrrHe5GUJmpqo7s4tAPNcasPh7umFM)  
Vena TRC20 token: [https://tronscan.org/#/contract/TUL5yxRKeSWvceLZ3BSU5iNJcQmNxkWayh](https://tronscan.org/#/contract/TUL5yxRKeSWvceLZ3BSU5iNJcQmNxkWayh)   









