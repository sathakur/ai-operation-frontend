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

  const [chatMessage, setChatMessage] = useState(
    "Hello. What can you help me with?"
  );
  const [chatAnswer, setChatAnswer] = useState("");
  const [chatMeta, setChatMeta] = useState(null);
  const [chatLoading, setChatLoading] = useState(false);

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

  const getBackendBaseUrl = () =>
    runtimeConfig.backendBaseUrl.replace(/\/+$/, "");

  const callBackend = async (path) => {
    try {
      setApiResult(null);
      setStatus(`Calling ${path} ...`);

      const token = await getAccessToken();

      if (!token) {
        return;
      }

      const response =
        await fetch(`${getBackendBaseUrl()}${path}`, {
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
      setStatus(
        error?.message || "Backend call failed."
      );
    }
  };

  const sendChatMessage = async () => {
    const message = chatMessage.trim();

    if (!message) {
      setChatAnswer("Enter a message first.");
      return;
    }

    try {
      setChatLoading(true);
      setChatAnswer("");
      setChatMeta(null);

      const token = await getAccessToken();

      if (!token) {
        return;
      }

      const response =
        await fetch(
          `${getBackendBaseUrl()}/api/chat`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${token}`
            },
            body: JSON.stringify({
              message
            })
          }
        );

      const text = await response.text();

      let body;
      try {
        body = JSON.parse(text);
      } catch {
        body = {
          answer: text
        };
      }

      if (!response.ok) {
        const detail =
          body?.detail ||
          body?.title ||
          body?.answer ||
          text ||
          `HTTP ${response.status}`;

        throw new Error(
          `Agent API returned HTTP ${response.status}: ${detail}`
        );
      }

      setChatAnswer(
        body?.answer ||
        "The agent returned no text response."
      );

      setChatMeta({
        correlationId: body?.correlationId,
        user: body?.user,
        agentName: body?.agentName,
        agentVersion: body?.agentVersion
      });
    } catch (error) {
      console.error(error);

      setChatAnswer(
        error?.message ||
        "Foundry agent call failed."
      );
    } finally {
      setChatLoading(false);
    }
  };

  const handleChatKeyDown = (event) => {
    if (
      event.key === "Enter" &&
      !event.shiftKey
    ) {
      event.preventDefault();

      if (!chatLoading) {
        sendChatMessage();
      }
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
                  callBackend(
                    "/api/inventory/whoami"
                  )
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
                  callBackend(
                    "/api/inventory/vms"
                  )
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

          <div className="card">
            <div className="chat-heading-row">
              <div>
                <h3>Foundry Agent Test</h3>
                <p className="muted">
                  Tests the authenticated frontend →
                  Web App → Microsoft Foundry Agent path.
                </p>
              </div>

              <span className="read-only-badge">
                READ ONLY
              </span>
            </div>

            <label
              className="chat-label"
              htmlFor="agent-message"
            >
              Message
            </label>

            <textarea
              id="agent-message"
              className="chat-input"
              rows="4"
              value={chatMessage}
              onChange={(e) =>
                setChatMessage(e.target.value)
              }
              onKeyDown={handleChatKeyDown}
              placeholder="Ask the Azure Operations Agent..."
              disabled={chatLoading}
            />

            <div className="chat-actions">
              <button
                className="primary-button"
                onClick={sendChatMessage}
                disabled={chatLoading}
              >
                {chatLoading
                  ? "Calling Foundry..."
                  : "Send to Foundry Agent"}
              </button>

              <span className="muted">
                Enter to send · Shift+Enter for new line
              </span>
            </div>

            {chatAnswer && (
              <div className="agent-response">
                <div className="agent-response-title">
                  Agent response
                </div>

                <div className="agent-response-text">
                  {chatAnswer}
                </div>

                {chatMeta && (
                  <div className="agent-meta">
                    {chatMeta.agentName && (
                      <span>
                        Agent: {chatMeta.agentName}
                      </span>
                    )}

                    {chatMeta.agentVersion && (
                      <span>
                        Version: {chatMeta.agentVersion}
                      </span>
                    )}

                    {chatMeta.correlationId && (
                      <span>
                        Correlation ID:{" "}
                        {chatMeta.correlationId}
                      </span>
                    )}
                  </div>
                )}
              </div>
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
