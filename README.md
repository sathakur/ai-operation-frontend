# AI Operations Assistant Frontend

React + Vite frontend for Azure Static Web Apps.

## Azure Static Web App environment variables

Create these values under:

Azure Portal -> Static Web Apps -> swa-ai-operation-frontend -> Environment variables

- AZURE_FRONTEND_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_API_CLIENT_ID

Do not place the backend client secret in this application.

## Build configuration

- App location: /
- API location: api
- Output location: dist

## Entra redirect URI

Register the exact Static Web App origin as a Single-page application redirect URI.

Example:
https://<your-static-web-app>.azurestaticapps.net
