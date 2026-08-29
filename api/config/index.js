module.exports = async function (context, req) {
  const frontendClientId =
    process.env.AZURE_FRONTEND_CLIENT_ID;

  const tenantId =
    process.env.AZURE_TENANT_ID;

  const apiClientId =
    process.env.AZURE_API_CLIENT_ID;

  const backendBaseUrl =
    process.env.AZURE_BACKEND_BASE_URL;

  const missing = {
    AZURE_FRONTEND_CLIENT_ID: !frontendClientId,
    AZURE_TENANT_ID: !tenantId,
    AZURE_API_CLIENT_ID: !apiClientId,
    AZURE_BACKEND_BASE_URL: !backendBaseUrl
  };

  if (Object.values(missing).some(Boolean)) {
    context.res = {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store, no-cache, must-revalidate"
      },
      body: {
        error: "Application configuration is incomplete.",
        missing
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
      apiClientId,
      backendBaseUrl
    }
  };
};