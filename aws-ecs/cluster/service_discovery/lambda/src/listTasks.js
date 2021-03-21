/** @typedef {import("aws-sdk/clients/ecs")} EcsClient */
/** @typedef {import("aws-sdk/clients/ecs").Task} Task */

module.exports = listTasks;

/**
 * @typedef {Object} ListTasksOptions
 * @property {string} clusterName
 * @property {EcsClient} ecsClient
 */

/**
 * @param {ListTasksOptions} options
 * @returns {Promise<Task[]>}
 */
async function listTasks(options) {
  const { clusterName, ecsClient } = options;

  /** @type {Task[]} */
  const tasks = [];

  /** @type {string | undefined} */
  let nextToken;

  do {
    const listResult = await ecsClient
      .listTasks({
        cluster: clusterName,
        maxResults: 100,
        desiredStatus: "RUNNING",
        nextToken,
      })
      .promise();

    const { taskArns = [] } = listResult;
    nextToken = listResult.nextToken;

    if (taskArns.length === 0) break;

    const { tasks: tasksPage = [] } = await ecsClient
      .describeTasks({
        cluster: clusterName,
        tasks: taskArns,
      })
      .promise();

    tasks.push(...tasksPage);
  } while (nextToken);

  return tasks;
}
