const EcsClient = require("aws-sdk/clients/ecs");
const Ec2Client = require("aws-sdk/clients/ec2");
const SsmClient = require("aws-sdk/clients/ssm");

const discoverRoutes = require("./discoverRoutes");
const updateRouterConfig = require("./updateRouterConfig");

module.exports = { handler };

if (require.main === module) {
  handler();
}

async function handler() {
  const clusterName = process.env.CLUSTER || "";
  const routerConfigParamName = process.env.ROUTER_CONFIG_PARAM || "";

  const ecsClient = new EcsClient();
  const ec2Client = new Ec2Client();
  const ssmClient = new SsmClient();

  const routes = await discoverRoutes({
    clusterName,
    ecsClient,
    ec2Client,
  });

  await updateRouterConfig({
    routes,
    paramName: routerConfigParamName,
    ssmClient,
  });
}
