const listTasks = require("./listTasks");
const findInstances = require("./findInstances");
const findTaskDefinitions = require("./findTaskDefinitions");

const keyBy = require("./util/keyBy");

module.exports = discoverRoutes;

/** @typedef {"tcp" | "udp"} RouteProtocol */

/**
 * @typedef {Object} LabelRoute
 * @property {RouteProtocol} protocol,
 * @property {number} containerPort
 * @property {number} natPort,
 */

/**
 * @typedef {Object} Route
 * @property {RouteProtocol} protocol,
 * @property {number} natPort,
 * @property {string} hostIp
 * @property {number} hostPort
 */

/**
 * @typedef {Object} DiscoverRoutesOptions
 * @property {string} clusterName
 * @property {import("aws-sdk/clients/ecs")} ecsClient
 * @property {import("aws-sdk/clients/ec2")} ec2Client
 */

/**
 * @param {DiscoverRoutesOptions} options
 * @returns {Promise<Route[]>}
 */
async function discoverRoutes(options) {
  const { clusterName, ecsClient, ec2Client } = options;

  console.log(`Searching for tasks in cluster ${clusterName}...`);
  const tasks = (await listTasks({ clusterName, ecsClient })).filter((task) => {
    const { containers = [] } = task;
    return containers.some(
      ({ networkBindings = [] }) => networkBindings.length > 0
    );
  });
  console.log(
    `Found ${tasks.length} tasks with network bindings in cluster ${clusterName}.`
  );

  if (tasks.length === 0) {
    return [];
  }

  const containerInstanceArns = tasks.map(
    (task) => task.containerInstanceArn || ""
  );
  const taskDefinitionArns = tasks.map((task) => task.taskDefinitionArn || "");

  console.log(
    `Searching for task definitions and instances running found tasks...`
  );
  const [instancesMap, taskDefinitionsMap] = await Promise.all([
    findInstances({ clusterName, containerInstanceArns, ecsClient, ec2Client }),
    findTaskDefinitions({ arns: taskDefinitionArns, ecsClient }),
  ]);

  console.log(`Building routes...`);
  return tasks.reduce((routes, task) => {
    const {
      taskDefinitionArn = "",
      containerInstanceArn = "",
      containers = [],
    } = task;

    const { containerDefinitions = [] } = taskDefinitionsMap[taskDefinitionArn];
    const containerDefinitionsMap = keyBy(
      containerDefinitions,
      ({ name = "" }) => name
    );

    const instance = instancesMap[containerInstanceArn];
    const { PrivateIpAddress: instanceIp = "" } = instance;

    containers.forEach(({ name = "", networkBindings = [] }) => {
      const { dockerLabels = {} } = containerDefinitionsMap[name];

      /** @type {LabelRoute[]} */
      const forward = JSON.parse(dockerLabels["nat.forward"] || "[]");

      forward.forEach(({ protocol, containerPort, natPort }) => {
        const binding = networkBindings.find(
          (binding) =>
            binding.protocol === protocol &&
            binding.containerPort === containerPort
        );

        const instancePort = binding && binding.hostPort;

        if (instancePort) {
          routes.push({
            protocol,
            natPort,
            hostIp: instanceIp,
            hostPort: instancePort,
          });
        }
      });
    });

    console.log(`Found ${routes.length} routes:`);
    routes.forEach(({ protocol, natPort, hostIp, hostPort }) =>
      console.log(
        `:${natPort}/${protocol} -> ${hostIp}:${hostPort}/${protocol}`
      )
    );

    return routes;
  }, /** @type {Route[]} */ ([]));
}
