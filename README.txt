Foundry Agent frontend test update

Based on the current repository files in sathakur/ai-operation-frontend.

Replace:
  src/App.jsx
  src/styles.css

No changes are required to:
  src/authConfig.js
  src/main.jsx
  api/config
  package.json

After Static Web Apps deploys:
1. Sign in.
2. Confirm existing Backend tests still work.
3. In Foundry Agent Test, leave:
   Hello. What can you help me with?
4. Click Send to Foundry Agent.
5. If it fails, capture the full message displayed in the Agent response area.

This stage tests only frontend -> /api/chat -> Foundry Agent connectivity.
