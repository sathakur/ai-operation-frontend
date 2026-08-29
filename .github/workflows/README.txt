Azure Static Web Apps creates its own deployment YAML in this folder.

After Azure creates the workflow, verify that the Azure/static-web-apps-deploy action uses:

app_location: "/"
api_location: "api"
output_location: "dist"

Do not replace the deployment token secret that Azure automatically creates.
