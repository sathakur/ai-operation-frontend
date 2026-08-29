export async function loadAuthConfig() {
  const response = await fetch("/api/config", {
    method: "GET",
    cache: "no-store"
  });

  if (!response.ok) {
    throw new Error(
      `Unable to load application configuration. HTTP ${response.status}`
    );
  }

  const config = await response.json();

  if (
    !config.frontendClientId ||
    !config.tenantId ||
    !config.apiClientId
  ) {
    throw new Error("Invalid authentication configuration received.");
  }

  const msalConfig = {
    auth: {
      clientId: config.frontendClientId,
      authority: `https://login.microsoftonline.com/${config.tenantId}`,
      redirectUri: window.location.origin,
      postLogoutRedirectUri: window.location.origin
    },
    cache: {
      cacheLocation: "sessionStorage",
      storeAuthStateInCookie: false
    }
  };

  const loginRequest = {
    scopes: [
      `api://${config.apiClientId}/Inventory.Read`
    ]
  };

  return {
    msalConfig,
    loginRequest,
    runtimeConfig: config
  };
}
