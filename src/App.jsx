import {
  AuthenticatedTemplate,
  UnauthenticatedTemplate,
  useMsal
} from "@azure/msal-react";

import { useState } from "react";

function App({ loginRequest, runtimeConfig }) {
  const { instance, accounts } = useMsal();

  const [status, setStatus] = useState("");
  const [apiResult, setApiResult] = useState(null);

  const account =
    accounts.length > 0 ? accounts[0] : null;

  const login = async () => {
    setStatus("Redirecting to Microsoft sign-in...");
    await instance.loginRedirect(loginRequest);
  };

  const logout = async () => {
    await instance.logoutRedirect({
      account,
      postLogoutRedirectUri: window.location.origin
    });
  };

  const getAccessToken = async () => {
    if (!account) {
      throw new Error("No signed-in account found.");
    }

    try {
      const tokenResponse =
        await instance.acquireTokenSilent({
          ...loginRequest,
          account
        });

      return tokenResponse.accessToken;
    } catch {
      await instance.acquireTokenRedirect({
        ...loginRequest,
        account
      });

      return null;
    }
  };

  const callBackend = async (path) => {
    try {
      setApiResult(null);
      setStatus(`Calling ${path} ...`);

      const token = await getAccessToken();

      if (!token) {
        return;
      }

      const baseUrl =
        runtimeConfig.backendBaseUrl.replace(/\/+$/, "");

      const response =
        await fetch(`${baseUrl}${path}`, {
          method: "GET",
          headers: {
            Authorization: `Bearer ${token}`
          }
        });

      const text = await response.text();

      let body;
      try {
        body = JSON.parse(text);
      } catch {
        body = text;
      }

      setApiResult(body);

      if (!response.ok) {
        setStatus(
          `Backend returned HTTP ${response.status}`
        );
        return;
      }

      setStatus("Backend call successful.");
    } catch (error) {
      console.error(error);
      setStatus(error?.message || "Backend call failed.");
    }
  };

  return (
    <div className="page">
      <header className="header">
        <div>
          <div className="small-title">
            AZURE OPERATIONS
          </div>
          <h1>AI Operations Assistant</h1>
        </div>
      </header>

      <main className="content">
        <UnauthenticatedTemplate>
          <div className="card login-card">
            <h2>Azure Inventory Assistant</h2>
            <p>
              Sign in with your organizational Microsoft
              account to access Azure inventory.
            </p>

            <button
              className="primary-button"
              onClick={login}
            >
              Sign in with Microsoft
            </button>

            {status && (
              <p className="status">{status}</p>
            )}
          </div>
        </UnauthenticatedTemplate>

        <AuthenticatedTemplate>
          <div className="card">
            <h2>Welcome</h2>

            <p>
              <strong>Name:</strong>{" "}
              {account?.name || "Unknown"}
            </p>

            <p>
              <strong>User:</strong>{" "}
              {account?.username || "Unknown"}
            </p>

            <p className="success">
              ✓ Microsoft Entra authentication successful
            </p>
          </div>

          <div className="card">
            <h3>Backend tests</h3>

            <div className="button-row">
              <button
                className="primary-button"
                onClick={() =>
                  callBackend("/api/inventory/whoami")
                }
              >
                Test Who Am I
              </button>

              <button
                className="primary-button"
                onClick={() =>
                  callBackend(
                    "/api/inventory/subscriptions"
                  )
                }
              >
                List My Subscriptions
              </button>

              <button
                className="primary-button"
                onClick={() =>
                  callBackend("/api/inventory/vms")
                }
              >
                List My VMs
              </button>
            </div>

            {status && (
              <p className="status">{status}</p>
            )}

            {apiResult !== null && (
              <pre className="result">
                {JSON.stringify(
                  apiResult,
                  null,
                  2
                )}
              </pre>
            )}
          </div>

          <button
            className="secondary-button"
            onClick={logout}
          >
            Sign out
          </button>
        </AuthenticatedTemplate>
      </main>
    </div>
  );
}

export default App;
