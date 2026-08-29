export async function loadAuthConfig() {
  const response = await fetch("/api/config", {
    method: "GET",
    cache: "no-store"
  });

  if (!response.ok) {
    let detail = "";
    try {
      const body = await response.json();
      detail = body?.error ? ` - ${body.error}` : "";
    } catch {
      // Ignore parsing errors.
    }

    throw new Error(
      `Unable to load application configuration. HTTP ${response.status}${detail}`
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
