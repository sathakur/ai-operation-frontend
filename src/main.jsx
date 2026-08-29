import React from "react";
import ReactDOM from "react-dom/client";
import { PublicClientApplication } from "@azure/msal-browser";
import { MsalProvider } from "@azure/msal-react";

import App from "./App.jsx";
import { loadAuthConfig } from "./authConfig.js";
import "./styles.css";

async function startApplication() {
  const root =
    ReactDOM.createRoot(
      document.getElementById("root")
    );

  try {
    const {
      msalConfig,
      loginRequest,
      runtimeConfig
    } = await loadAuthConfig();

    const msalInstance =
      new PublicClientApplication(msalConfig);

    await msalInstance.initialize();

    root.render(
      <React.StrictMode>
        <MsalProvider instance={msalInstance}>
          <App
            loginRequest={loginRequest}
            runtimeConfig={runtimeConfig}
          />
        </MsalProvider>
      </React.StrictMode>
    );
  } catch (error) {
    console.error("Startup error:", error);

    root.render(
      <div className="startup-error">
        <h2>Application configuration error</h2>
        <p>{error?.message}</p>
      </div>
    );
  }
}

startApplication();
