/** @typedef {import("aws-sdk/clients/ecs")} EcsClient */
/** @typedef {import("aws-sdk/clients/ecs").TaskDefinition} TaskDefinition */

const keyBy = require("./util/keyBy");

module.exports = findTaskDefinitions;

/**
 * @typedef {Object} FindTaskDefinitionsOptions
 * @property {string[]} arns
 * @property {EcsClient} ecsClient
 */

/**
 * @param {FindTaskDefinitionsOptions} options
 * @returns {Promise<Record<string, TaskDefinition>>}
 */
async function findTaskDefinitions(options) {
  const { arns, ecsClient } = options;

  const definitions = await Promise.all(
    arns.map(async (arn) => {
      const { taskDefinition } = await ecsClient
        .describeTaskDefinition({ taskDefinition: arn })
        .promise();

      return /** @type {TaskDefinition} */ (taskDefinition);
    })
  );

  return keyBy(definitions, ({ taskDefinitionArn = "" }) => taskDefinitionArn);
}
