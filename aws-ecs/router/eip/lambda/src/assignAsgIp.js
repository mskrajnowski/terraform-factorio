/** @typedef {import("aws-sdk/clients/ec2")} Ec2Client */

const findAsgInstances = require("./findAsgInstances");

module.exports = assignAsgIp;

/**
 * @typedef {Object} AssignAsgIpOptions
 * @property {string} eipId
 * @property {string} asgName
 * @property {Ec2Client} ec2Client
 */

/**
 * @param {AssignAsgIpOptions} options
 * @returns {Promise<void>}
 */
async function assignAsgIp(options) {
  const { eipId, asgName, ec2Client } = options;

  console.log(`Searching for an instance in ${asgName} autoscaling group...`);
  const [instance] = await findAsgInstances({ asgName, ec2Client });

  if (!instance) {
    console.log("No instances found.");
    return;
  }

  const instanceId = instance.InstanceId;

  console.log(`Found instance: ${instanceId}.`);
  console.log(`Assigning elastic IP ${eipId} to ${instanceId}...`);

  try {
    await ec2Client
      .associateAddress({
        AllocationId: eipId,
        InstanceId: instanceId,
        AllowReassociation: true,
      })
      .promise();

    console.log(`Elastic IP ${eipId} assigned to ${instanceId}.`);
  } catch (error) {
    console.error(`Failed to assign ${eipId} to ${instanceId}:`, error);
  }
}
