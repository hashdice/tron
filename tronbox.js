const config = require('./config.js');

module.exports = {
  networks: {    
    mainnet: {
      from: 'your address',
      privateKey: 'your private key',
      consume_user_resource_percent: 5,
      fee_limit: 100000000,    //100 trx
      origin_energy_limit: 10000000,  //10 trx
      host: "https://api.trongrid.io",
      port: 8090,
      fullNode: "https://api.trongrid.io",
      solidityNode: "https://api.trongrid.io",
      eventServer: "https://api.trongrid.io",
      network_id: "*" // Match any network id
    }, 
    shasta: {
      from: 'your address',
      privateKey: 'your private key',
      consume_user_resource_percent: 5,
      fee_limit: 10000000,    //10 trx
      origin_energy_limit: 10000000, //10 trx
      host: "https://api.shasta.trongrid.io",
      port: 8090,
      fullNode: "https://api.shasta.trongrid.io",
      solidityNode: "https://api.shasta.trongrid.io",
      eventServer: "https://api.shasta.trongrid.io",
      network_id: "*"      
    }
  }
};
