/** @typedef {import("aws-sdk/clients/ec2")} Ec2Client */
/** @typedef {import("aws-sdk/clients/ec2").Instance} Ec2Instance */

module.exports = findAsgInstances;

/**
 * @typedef {Object} FindAsgInstancesOptions
 * @property {string} asgName
 * @property {Ec2Client} ec2Client
 */

/**
 * @param {FindAsgInstancesOptions} options
 * @returns {Promise<Ec2Instance[]>}
 */

async function findAsgInstances(options) {
  const { asgName, ec2Client } = options;

  const { Reservations: ec2Reservations = [] } = await ec2Client
    .describeInstances({
      Filters: [
        { Name: "tag:aws:autoscaling:groupName", Values: [asgName] },
        { Name: "instance-state-name", Values: ["running"] },
      ],
    })
    .promise();

  return ec2Reservations.reduce((instances, reservation) => {
    if (reservation.Instances) {
      instances.push(...reservation.Instances);
    }

    return instances;
  }, /** @type {Ec2Instance[]} */ ([]));
}
