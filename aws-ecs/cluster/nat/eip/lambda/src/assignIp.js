/** @typedef {import("aws-sdk/clients/ec2")} Ec2Client */

module.exports = assignIp;

/**
 * @typedef {Object} AssignIpOptions
 * @property {string} eipId
 * @property {string} instanceId
 * @property {Ec2Client} ec2Client
 */

/**
 * @param {AssignIpOptions} options
 * @returns {Promise<void>}
 */
async function assignIp(options) {
  const { eipId, instanceId, ec2Client } = options;

  await ec2Client
    .associateAddress({
      AllocationId: eipId,
      InstanceId: instanceId,
      AllowReassociation: true,
    })
    .promise();
}
