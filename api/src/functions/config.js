import { app } from "@azure/functions";

app.http("config", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "config",

  handler: async () => {
    const frontendClientId =
      process.env.AZURE_FRONTEND_CLIENT_ID;

    const tenantId =
      process.env.AZURE_TENANT_ID;

    const apiClientId =
      process.env.AZURE_API_CLIENT_ID;

    if (!frontendClientId || !tenantId || !apiClientId) {
      return {
        status: 500,
        jsonBody: {
          error: "Application configuration is incomplete."
        }
      };
    }

    return {
      status: 200,
      headers: {
        "Cache-Control": "no-store, no-cache, must-revalidate"
      },
      jsonBody: {
        frontendClientId,
        tenantId,
        apiClientId
      }
    };
  }
});
