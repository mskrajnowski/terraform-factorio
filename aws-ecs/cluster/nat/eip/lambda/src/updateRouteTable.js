/** @typedef {import("aws-sdk/clients/ec2")} Ec2Client */

module.exports = updateRouteTable;

/**
 * @typedef {Object} UpdateRouteTableOptions
 * @property {string} routeTableId
 * @property {string} instanceId
 * @property {Ec2Client} ec2Client
 */

/**
 * @param {UpdateRouteTableOptions} options
 * @returns {Promise<void>}
 */
async function updateRouteTable(options) {
  const { routeTableId, instanceId, ec2Client } = options;

  const createRouteOptions = {
    RouteTableId: routeTableId,
    DestinationCidrBlock: "0.0.0.0/0",
    InstanceId: instanceId,
  };

  try {
    await ec2Client.replaceRoute(createRouteOptions).promise();
  } catch {
    await ec2Client.createRoute(createRouteOptions).promise();
  }
}
