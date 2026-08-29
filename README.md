# AI Operations Assistant

Azure Static Web Apps frontend with a managed Azure Functions config endpoint.

## Static Web Apps build settings

- App location: /
- API location: api
- Output location: dist

## Azure Static Web App environment variables

Configure these in Azure Portal:

- AZURE_FRONTEND_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_API_CLIENT_ID

Do not put the backend client secret in this Static Web App.

## Test endpoint

After deployment:

/api/config

Expected response when variables are configured:

{
  "frontendClientId": "...",
  "tenantId": "...",
  "apiClientId": "..."
}
