var roll_vena = artifacts.require("HashRoll_VENA.sol");

module.exports = function(deployer) {
  deployer.deploy(roll_vena);
};