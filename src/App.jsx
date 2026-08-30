import {
  AuthenticatedTemplate,
  UnauthenticatedTemplate,
  useMsal
} from "@azure/msal-react";

import { useEffect, useMemo, useRef, useState } from "react";

const nowLabel = () =>
  new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date());

const STARTER_MESSAGE = {
  id: "assistant-welcome",
  role: "assistant",
  text:
    "Hello! I’m your Azure Operations Assistant. I can help you explore subscriptions, virtual machines, storage accounts, resource groups, subnets, and other Azure inventory.",
  meta: null,
  time: nowLabel()
};

const QUICK_PROMPTS = [
  {
    label: "Subscriptions",
    prompt: "Show me subscription names",
    icon: "▣"
  },
  {
    label: "VM count",
    prompt: "How many virtual machines are there?",
    icon: "◫"
  },
  {
    label: "Virtual machines",
    prompt: "Show me VM names",
    icon: "▤"
  },
  {
    label: "Storage accounts",
    prompt: "Show me storage accounts",
    icon: "◧"
  },
  {
    label: "Resource groups",
    prompt: "Show me resource groups",
    icon: "▦"
  },
  {
    label: "Resource summary",
    prompt: "Show me resource summary",
    icon: "◩"
  }
];

function App({ loginRequest, runtimeConfig }) {
  const { instance, accounts } = useMsal();

  const account =
    accounts.length > 0 ? accounts[0] : null;

  const [messages, setMessages] = useState([
    STARTER_MESSAGE
  ]);

  const [chatMessage, setChatMessage] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [technicalMessageId, setTechnicalMessageId] =
    useState(null);

  const conversationEndRef = useRef(null);

  const displayName =
    account?.name ||
    account?.username ||
    "Signed-in user";

  const initials = useMemo(() => {
    const source =
      account?.name ||
      account?.username ||
      "AU";

    const parts = source
      .replace(/[#@._-]/g, " ")
      .split(/\s+/)
      .filter(Boolean);

    return (
      parts
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase())
        .join("") || "AU"
    );
  }, [account]);

  useEffect(() => {
    conversationEndRef.current?.scrollIntoView({
      behavior: "smooth",
      block: "end"
    });
  }, [messages, chatLoading]);

  const login = async () => {
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

  const createId = (prefix) =>
    `${prefix}-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 8)}`;

  const newChat = () => {
    setMessages([{ ...STARTER_MESSAGE, time: nowLabel() }]);
    setChatMessage("");
    setTechnicalMessageId(null);
    setSidebarOpen(false);
  };

  const clearConversation = () => {
    setMessages([]);
    setChatMessage("");
    setTechnicalMessageId(null);
  };

  const sendChatMessage = async (
    overrideMessage = null
  ) => {
    const message = (
      overrideMessage ?? chatMessage
    ).trim();

    if (!message || chatLoading) {
      return;
    }

    const userMessage = {
      id: createId("user"),
      role: "user",
      text: message,
      meta: null,
      time: nowLabel()
    };

    setMessages((current) => [
      ...current,
      userMessage
    ]);

    setChatMessage("");
    setChatLoading(true);
    setSidebarOpen(false);

    try {
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

        throw new Error(detail);
      }

      setMessages((current) => [
        ...current,
        {
          id: createId("assistant"),
          role: "assistant",
          text:
            body?.answer ||
            "The assistant returned no text response.",
          meta: {
            correlationId:
              body?.correlationId || null,
            agentName:
              body?.agentName || null,
            agentVersion:
              body?.agentVersion || null
          },
          time: nowLabel()
        }
      ]);
    } catch (error) {
      console.error(error);

      setMessages((current) => [
        ...current,
        {
          id: createId("assistant-error"),
          role: "assistant",
          text:
            "I couldn’t complete that request. Please try again. If the issue continues, open Technical details and provide the correlation information to the support team.",
          isError: true,
          meta: {
            error:
              error?.message ||
              "Azure Operations Assistant request failed."
          },
          time: nowLabel()
        }
      ]);
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
      sendChatMessage();
    }
  };

  const copyMessage = async (text) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch (error) {
      console.error(
        "Could not copy response.",
        error
      );
    }
  };

  const handleQuickPrompt = (prompt) => {
    setChatMessage(prompt);
    sendChatMessage(prompt);
  };

  return (
    <>
      <UnauthenticatedTemplate>
        <div className="login-page">
          <div className="login-shell">
            <div className="brand-mark large">
              <span className="brand-mark-inner">
                AZ
              </span>
            </div>

            <div className="login-kicker">
              AZURE OPERATIONS
            </div>

            <h1>
              AI Operations Assistant
            </h1>

            <p className="login-copy">
              Securely explore your Azure environment
              using Microsoft Entra ID and a controlled,
              read-only AI assistant.
            </p>

            <button
              className="button button-primary login-button"
              onClick={login}
            >
              <span className="microsoft-window">
                <span />
                <span />
                <span />
                <span />
              </span>
              Sign in with Microsoft
            </button>

            <div className="login-security">
              <span className="status-dot" />
              Enterprise authentication enabled
            </div>
          </div>
        </div>
      </UnauthenticatedTemplate>

      <AuthenticatedTemplate>
        <div className="app-shell">
          <header className="topbar">
            <div className="topbar-left">
              <button
                className="icon-button mobile-menu-button"
                onClick={() =>
                  setSidebarOpen((current) => !current)
                }
                aria-label="Toggle navigation"
              >
                ☰
              </button>

              <div className="brand-mark">
                <span className="brand-mark-inner">
                  AZ
                </span>
              </div>

              <div className="brand-copy">
                <div className="brand-kicker">
                  AZURE OPERATIONS
                </div>
                <div className="brand-title">
                  AI Operations Assistant
                </div>
              </div>
            </div>

            <div className="topbar-right">
              <div className="environment-pill">
                <span className="status-dot" />
                Connected
              </div>

              <div
                className="mode-pill"
                title="Read-only mode can retrieve Azure inventory but cannot modify Azure resources."
              >
                Read only
                <span className="info-dot">i</span>
              </div>

              <div className="user-menu">
                <div className="avatar">
                  {initials}
                </div>

                <div className="user-copy">
                  <div className="user-name">
                    {displayName}
                  </div>
                  <div className="user-subtitle">
                    Microsoft Entra ID
                  </div>
                </div>

                <button
                  className="signout-button"
                  onClick={logout}
                >
                  Sign out
                </button>
              </div>
            </div>
          </header>

          <div className="workspace">
            <aside
              className={`sidebar ${
                sidebarOpen ? "sidebar-open" : ""
              }`}
            >
              <button
                className="button button-primary new-chat-button"
                onClick={newChat}
              >
                <span className="plus-icon">＋</span>
                New chat
              </button>

              <div className="sidebar-section">
                <div className="sidebar-label">
                  QUICK QUESTIONS
                </div>

                <div className="quick-prompt-list">
                  {QUICK_PROMPTS.map((item) => (
                    <button
                      key={item.label}
                      className="quick-prompt"
                      onClick={() =>
                        handleQuickPrompt(
                          item.prompt
                        )
                      }
                      disabled={chatLoading}
                    >
                      <span className="quick-prompt-icon">
                        {item.icon}
                      </span>
                      {item.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="sidebar-spacer" />

              <div className="sidebar-info">
                <div className="sidebar-info-title">
                  Secure inventory access
                </div>
                <div className="sidebar-info-copy">
                  Results are retrieved through approved
                  read-only Azure inventory tools.
                </div>
              </div>
            </aside>

            {sidebarOpen && (
              <button
                className="sidebar-overlay"
                onClick={() =>
                  setSidebarOpen(false)
                }
                aria-label="Close navigation"
              />
            )}

            <main className="chat-panel">
              <section className="chat-header">
                <div>
                  <h1>
                    Azure Operations Assistant
                  </h1>
                  <p>
                    Ask questions about your Azure
                    subscriptions and resources.
                  </p>
                </div>

                <div className="chat-header-actions">
                  <div className="chat-header-status">
                    <span className="status-dot" />
                    Inventory service connected
                  </div>

                  <button
                    className="clear-button"
                    onClick={clearConversation}
                    disabled={messages.length === 0 || chatLoading}
                  >
                    Clear conversation
                  </button>
                </div>
              </section>

              <section className="conversation">
                <div className="conversation-inner">
                  {messages.map((message) => (
                    <div
                      key={message.id}
                      className={`message-row ${message.role}`}
                    >
                      <div
                        className={`message-avatar ${
                          message.role
                        }`}
                      >
                        {message.role === "assistant"
                          ? "AI"
                          : initials}
                      </div>

                      <div className="message-content">
                        <div className="message-heading-row">
                          <div className="message-heading">
                            {message.role === "assistant"
                              ? "Azure Operations Assistant"
                              : "You"}
                          </div>
                          <div className="message-time">
                            {message.time || ""}
                          </div>
                        </div>

                        <div
                          className={`message-bubble ${
                            message.role
                          } ${
                            message.isError
                              ? "message-error"
                              : ""
                          }`}
                        >
                          <div className="message-text">
                            {message.text}
                          </div>
                        </div>

                        {message.role === "assistant" && (
                          <div className="message-actions">
                            <button
                              onClick={() =>
                                copyMessage(
                                  message.text
                                )
                              }
                            >
                              Copy
                            </button>

                            {message.meta && (
                              <button
                                onClick={() =>
                                  setTechnicalMessageId(
                                    technicalMessageId ===
                                      message.id
                                      ? null
                                      : message.id
                                  )
                                }
                              >
                                Technical details
                              </button>
                            )}
                          </div>
                        )}

                        {technicalMessageId ===
                          message.id &&
                          message.meta && (
                            <div className="technical-details">
                              {message.meta.agentName && (
                                <div>
                                  <span>Agent</span>
                                  <strong>
                                    {
                                      message.meta
                                        .agentName
                                    }
                                  </strong>
                                </div>
                              )}

                              {message.meta
                                .agentVersion && (
                                <div>
                                  <span>Version</span>
                                  <strong>
                                    {
                                      message.meta
                                        .agentVersion
                                    }
                                  </strong>
                                </div>
                              )}

                              {message.meta
                                .correlationId && (
                                <div>
                                  <span>
                                    Correlation ID
                                  </span>
                                  <strong>
                                    {
                                      message.meta
                                        .correlationId
                                    }
                                  </strong>
                                </div>
                              )}

                              {message.meta.error && (
                                <div>
                                  <span>Error</span>
                                  <strong>
                                    {
                                      message.meta
                                        .error
                                    }
                                  </strong>
                                </div>
                              )}
                            </div>
                          )}
                      </div>
                    </div>
                  ))}

                  {chatLoading && (
                    <div className="message-row assistant">
                      <div className="message-avatar assistant">
                        AI
                      </div>

                      <div className="message-content">
                        <div className="message-heading-row">
                          <div className="message-heading">
                            Azure Operations Assistant
                          </div>
                          <div className="message-time">
                            {nowLabel()}
                          </div>
                        </div>

                        <div className="thinking-card">
                          <div className="thinking-dots">
                            <span />
                            <span />
                            <span />
                          </div>
                          Checking Azure inventory…
                        </div>

                        <div className="skeleton-stack">
                          <span />
                          <span />
                          <span />
                        </div>
                      </div>
                    </div>
                  )}

                  <div ref={conversationEndRef} />
                </div>
              </section>

              <section className="composer-area">
                <div className="composer-shell">
                  <textarea
                    value={chatMessage}
                    onChange={(event) =>
                      setChatMessage(
                        event.target.value
                      )
                    }
                    onKeyDown={handleChatKeyDown}
                    placeholder="Ask about your Azure environment..."
                    rows="1"
                    disabled={chatLoading}
                    aria-label="Message"
                  />

                  <button
                    className="send-button"
                    onClick={() =>
                      sendChatMessage()
                    }
                    disabled={
                      chatLoading ||
                      !chatMessage.trim()
                    }
                    aria-label="Send message"
                  >
                    ➤
                  </button>
                </div>

                <div className="composer-footer">
                  <span>
                    Enter to send · Shift+Enter for
                    new line
                  </span>

                  <span>
                    Read-only Azure inventory · AI
                    responses should be verified for
                    critical decisions
                  </span>
                </div>
              </section>
            </main>
          </div>
        </div>
      </AuthenticatedTemplate>
    </>
  );
}

export default App;
