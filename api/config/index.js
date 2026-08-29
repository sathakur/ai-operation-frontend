module.exports = async function (context, req) {
  const frontendClientId = process.env.AZURE_FRONTEND_CLIENT_ID;
  const tenantId = process.env.AZURE_TENANT_ID;
  const apiClientId = process.env.AZURE_API_CLIENT_ID;

  if (!frontendClientId || !tenantId || !apiClientId) {
    context.res = {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store, no-cache, must-revalidate"
      },
      body: {
        error: "Application configuration is incomplete.",
        missing: {
          AZURE_FRONTEND_CLIENT_ID: !frontendClientId,
          AZURE_TENANT_ID: !tenantId,
          AZURE_API_CLIENT_ID: !apiClientId
        }
      }
    };
    return;
  }

  context.res = {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate"
    },
    body: {
      frontendClientId,
      tenantId,
      apiClientId
    }
  };
};
