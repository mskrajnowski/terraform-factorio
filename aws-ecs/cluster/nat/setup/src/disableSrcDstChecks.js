/** @typedef {import("aws-sdk/clients/ec2")} Ec2Client */

module.exports = disableSrcDstChecks;

/**
 * @typedef {Object} DisableSrcDestChecksOptions
 * @property {string} instanceId
 * @property {Ec2Client} ec2Client
 */

/**
 * @param {DisableSrcDestChecksOptions} options
 * @returns {Promise<void>}
 */
async function disableSrcDstChecks(options) {
  const { instanceId, ec2Client } = options;

  await ec2Client
    .modifyInstanceAttribute({
      InstanceId: instanceId,
      SourceDestCheck: { Value: false },
    })
    .promise();
}
