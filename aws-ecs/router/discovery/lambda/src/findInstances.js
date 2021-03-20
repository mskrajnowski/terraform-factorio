/** @typedef {import("aws-sdk/clients/ecs")} EcsClient */
/** @typedef {import("aws-sdk/clients/ec2")} Ec2Client */
/** @typedef {import("aws-sdk/clients/ec2").Instance} Ec2Instance */

const chunk = require("./util/chunk");
const flatten = require("./util/flatten");
const keyBy = require("./util/keyBy");

module.exports = findInstances;

/**
 * @typedef {Object} FindInstancesOptions
 * @property {string} clusterName
 * @property {string[]} containerInstanceArns
 * @property {EcsClient} ecsClient
 * @property {Ec2Client} ec2Client
 */

/**
 * @param {FindInstancesOptions} options
 * @returns {Promise<Record<string, Ec2Instance>>}
 */
async function findInstances(options) {
  const { clusterName, containerInstanceArns, ecsClient, ec2Client } = options;

  const batches = chunk(containerInstanceArns, 100);

  const instanceMapBatches = await Promise.all(
    batches.map(async (arns) => {
      const { containerInstances = [] } = await ecsClient
        .describeContainerInstances({
          cluster: clusterName,
          containerInstances: arns,
        })
        .promise();

      const ec2InstanceIds = containerInstances.map(
        ({ ec2InstanceId = "" }) => ec2InstanceId
      );

      const {
        Reservations: ec2Reservations = [],
      } = await ec2Client
        .describeInstances({ InstanceIds: ec2InstanceIds })
        .promise();

      const ec2Instances = flatten(
        ec2Reservations.map(({ Instances = [] }) => Instances)
      );

      const ec2InstancesMap = keyBy(
        ec2Instances,
        ({ InstanceId = "" }) => InstanceId
      );

      return containerInstances.reduce((map, containerInstance) => {
        const {
          ec2InstanceId = "",
          containerInstanceArn = "",
        } = containerInstance;

        const ec2Instance = ec2InstancesMap[ec2InstanceId];
        map[containerInstanceArn] = ec2Instance;
        return map;
      }, /** @type {Record<string, Ec2Instance>} */ ({}));
    })
  );

  return instanceMapBatches.reduce(
    (map, batchMap) => ({ ...map, ...batchMap }),
    /** @type {Record<string, Ec2Instance>} */ ({})
  );
}
