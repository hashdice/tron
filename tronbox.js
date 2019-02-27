const config = require('./config.js');

module.exports = {
  networks: {    
    mainnet: {
      from: config.environments.mainnet.address,
      privateKey: config.environments.mainnet.private_key,
      consume_user_resource_percent: 10,
      fee_limit: 10000000,    //10 trx
      origin_energy_limit: 10000000,  //10 trx
      host: "https://api.trongrid.io",
      port: 8090,
      fullNode: "https://api.trongrid.io",
      solidityNode: "https://api.trongrid.io",
      eventServer: "https://api.trongrid.io",
      network_id: "*" // Match any network id
    }, 
    hdt: {
      from: config.environments.hdt.address,
      privateKey: config.environments.hdt.private_key,
      consume_user_resource_percent: 50,
      fee_limit: 100000000,    //100 trx
      origin_energy_limit: 10000000, //10 trx
      host: "https://api.trongrid.io",
      port: 8090,
      fullNode: "https://api.trongrid.io",
      solidityNode: "https://api.trongrid.io",
      eventServer: "https://api.trongrid.io",
      network_id: "*" 
    },
    hashdice: {
      from: config.environments.hashdice.address,
      privateKey: config.environments.hashdice.private_key,
      consume_user_resource_percent: 10,
      fee_limit: 100000000,    //100 trx
      origin_energy_limit: 10000000, //10 trx
      host: "https://api.trongrid.io",
      port: 8090,
      fullNode: "https://api.trongrid.io",
      solidityNode: "https://api.trongrid.io",
      eventServer: "https://api.trongrid.io",
      network_id: "*" 
    },
    shasta: {
      from: config.environments.shasta.address,
      privateKey: config.environments.shasta.private_key,
      consume_user_resource_percent: 10,
      fee_limit: 100000000,    //100 trx
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
