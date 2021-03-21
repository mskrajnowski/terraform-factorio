/** @typedef {import("aws-sdk/clients/ssm")} SsmClient */
/** @typedef {import("./discoverRoutes").Route} Route */

module.exports = updateNatConfig;

/**
 * @typedef {Object} UpdateNatConfigOptions
 * @property {Route[]} routes
 * @property {string} paramName
 * @property {SsmClient} ssmClient
 */

/**
 * @param {UpdateNatConfigOptions} options
 * @returns {Promise<void>}
 */

async function updateNatConfig(options) {
  const { routes, paramName, ssmClient } = options;

  const routesJson = JSON.stringify(routes, null, 2);

  console.log(`Writing configuration to ${paramName} parameter...`);
  console.log(routesJson);

  await ssmClient
    .putParameter({
      Name: paramName,
      Type: "String",
      Value: routesJson,
      Overwrite: true,
    })
    .promise();

  console.log(`Configuration written to ${paramName} parameter`);
}
