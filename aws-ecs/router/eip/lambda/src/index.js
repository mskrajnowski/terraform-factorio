const Ec2Client = require("aws-sdk/clients/ec2");

const findAsgInstances = require("./findAsgInstances");
const assignIp = require("./assignIp");
const disableSrcDstChecks = require("./disableSrcDstChecks");
const updateRouteTable = require("./updateRouteTable");

module.exports = { handler };

if (require.main === module) {
  handler();
}

async function handler() {
  const routerIpId = process.env.ROUTER_EIP_ID || "";
  const routerAsgName = process.env.ROUTER_ASG || "";
  const privateRouteTableIds = (process.env.ROUTE_TABLE_IDS || "").split(",");

  const ec2Client = new Ec2Client();

  console.log(
    `Searching for an instance in ${routerAsgName} autoscaling group...`
  );
  const [instance] = await findAsgInstances({
    asgName: routerAsgName,
    ec2Client,
  });

  if (!instance) {
    console.log("No running instances found.");
    return;
  }

  const instanceId = instance.InstanceId || "";

  console.log(`Found instance: ${instanceId}.`);

  console.log(`Assigning elastic IP ${routerIpId} to ${instanceId}...`);
  await assignIp({ eipId: routerIpId, instanceId, ec2Client });

  console.log(`Disabling source/destination checks on ${instanceId}`);
  await disableSrcDstChecks({ instanceId, ec2Client });

  console.log("Updating private subnet route tables...");
  await Promise.all(
    privateRouteTableIds.map(async (routeTableId) =>
      updateRouteTable({ routeTableId, instanceId, ec2Client })
    )
  );
}
