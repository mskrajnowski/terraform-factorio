const Ec2Client = require("aws-sdk/clients/ec2");

const assignAsgIp = require("./assignAsgIp");

module.exports = { handler };

if (require.main === module) {
  handler();
}

async function handler() {
  const routerIpId = process.env.ROUTER_EIP_ID || "";
  const routerAsgName = process.env.ROUTER_ASG || "";

  const ec2Client = new Ec2Client();

  await assignAsgIp({ eipId: routerIpId, asgName: routerAsgName, ec2Client });
}
