import {
  AuthenticatedTemplate,
  UnauthenticatedTemplate,
  useMsal
} from "@azure/msal-react";

import { useState } from "react";

function App({ loginRequest }) {
  const { instance, accounts } = useMsal();
  const [status, setStatus] = useState("");

  const account = accounts.length > 0 ? accounts[0] : null;

  const login = async () => {
    try {
      setStatus("Redirecting to Microsoft sign-in...");
      await instance.loginRedirect(loginRequest);
    } catch (error) {
      console.error(error);
      setStatus("Unable to start Microsoft login.");
    }
  };

  const logout = async () => {
    try {
      await instance.logoutRedirect({
        account,
        postLogoutRedirectUri: window.location.origin
      });
    } catch (error) {
      console.error(error);
      setStatus("Logout failed.");
    }
  };

  const testApiToken = async () => {
    if (!account) return;

    try {
      setStatus("Requesting API access token...");

      const tokenResponse = await instance.acquireTokenSilent({
        ...loginRequest,
        account
      });

      if (tokenResponse.accessToken) {
        setStatus(
          "Inventory.Read access token acquired successfully."
        );
      }
    } catch (error) {
      console.error(error);

      try {
        await instance.acquireTokenRedirect({
          ...loginRequest,
          account
        });
      } catch (redirectError) {
        console.error(redirectError);
        setStatus("Unable to acquire API access token.");
      }
    }
  };

  return (
    <div className="page">
      <header className="header">
        <div>
          <div className="small-title">AZURE OPERATIONS</div>
          <h1>AI Operations Assistant</h1>
        </div>
      </header>

      <main className="content">
        <UnauthenticatedTemplate>
          <div className="login-card">
            <h2>Azure Inventory Assistant</h2>
            <p>
              Sign in with your organizational Microsoft account
              to access Azure inventory.
            </p>

            <button
              className="primary-button"
              onClick={login}
            >
              Sign in with Microsoft
            </button>

            {status && <p className="status">{status}</p>}
          </div>
        </UnauthenticatedTemplate>

        <AuthenticatedTemplate>
          <div className="dashboard">
            <div className="welcome-card">
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

            <div className="action-card">
              <h3>API Authentication Test</h3>

              <p>
                Verify that this signed-in user can obtain
                the delegated Inventory.Read token.
              </p>

              <button
                className="primary-button"
                onClick={testApiToken}
              >
                Test Inventory.Read Token
              </button>

              {status && <p className="status">{status}</p>}
            </div>

            <button
              className="secondary-button"
              onClick={logout}
            >
              Sign out
            </button>
          </div>
        </AuthenticatedTemplate>
      </main>
    </div>
  );
}

export default App;
