const Ec2Client = require("aws-sdk/clients/ec2");

const findAsgInstances = require("./findAsgInstances");
const assignIp = require("./assignIp");
const disableSrcDstChecks = require("./disableSrcDstChecks");
const updateRouteTable = require("./updateRouteTable");

module.exports = { handler };

if (require.main === module) {
  handler();
}

/**
 * @param {{detail?: {EC2InstanceId?: string}}} [event={}]
 */
async function handler(event) {
  const natIpId = process.env.NAT_EIP_ID || "";
  const natAsgName = process.env.NAT_ASG || "";
  const privateRouteTableIds = (process.env.ROUTE_TABLE_IDS || "").split(",");

  const ec2Client = new Ec2Client();

  /** @type {string} */
  let instanceId;

  if (event && event.detail && event.detail.EC2InstanceId) {
    instanceId = event.detail.EC2InstanceId;
  } else {
    console.log(
      `Searching for an instance in ${natAsgName} autoscaling group...`
    );
    const [instance] = await findAsgInstances({
      asgName: natAsgName,
      ec2Client,
    });

    if (!instance || !instance.InstanceId) {
      console.log("No running instances found.");
      return;
    }

    instanceId = instance.InstanceId;
    console.log(`Found instance: ${instanceId}.`);
  }

  console.log(`Assigning elastic IP ${natIpId} to ${instanceId}...`);
  await assignIp({ eipId: natIpId, instanceId, ec2Client });

  console.log(`Disabling source/destination checks on ${instanceId}`);
  await disableSrcDstChecks({ instanceId, ec2Client });

  console.log("Updating private subnet route tables...");
  await Promise.all(
    privateRouteTableIds.map(async (routeTableId) =>
      updateRouteTable({ routeTableId, instanceId, ec2Client })
    )
  );
}
