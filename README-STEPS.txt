AZURE OPERATIONS FRONTEND - ASSISTANT FORMATTING UPDATE
========================================================

Purpose
-------
This package updates the existing React frontend so assistant responses render:
- **bold** text
- bullet lists
- numbered lists
- # / ## / ### headings
- normal paragraphs

It does NOT change:
- Microsoft Entra / MSAL login
- backend URL
- /api/chat request
- bearer token handling
- Copy
- Technical details
- quick questions
- current dark theme
- Foundry
- Function App
- API backend

No new npm package is required.

STEP 1 - Extract this ZIP
-------------------------
Example:
C:\script\frontend-markdown-formatting-package

STEP 2 - Run the patch
----------------------
Open Windows PowerShell:

cd C:\script\frontend-markdown-formatting-package

.\Apply-FrontendMarkdownFormatting.ps1 `
  -FrontendRepo "C:\script\ai-operation-frontend"

STEP 3 - Check the changes
--------------------------
cd C:\script\ai-operation-frontend

git diff -- src\App.jsx
git diff -- src\styles.css

The App.jsx diff should:
- add renderInlineFormatting(...)
- add renderAssistantText(...)
- replace {message.text} for assistant messages with renderAssistantText(message.text)

The CSS diff should add only the "Assistant response formatting" section.

STEP 4 - Build locally
----------------------
npm install
npm run build

The build must complete successfully before pushing.

STEP 5 - Commit and push
------------------------
git add src\App.jsx src\styles.css
git commit -m "Render assistant responses with structured formatting"
git push

Wait for the Static Web Apps GitHub Actions deployment to complete.

STEP 6 - Test
-------------
Hard refresh the deployed site with Ctrl+F5.

Test:
Show me resource summary

Expected:
- resource names such as "Action Rules" appear bold
- hyphens are rendered as actual bullets
- raw ** characters are no longer visible

Also test:
Show me storage accounts
Show me VM names
How many resources are there?

SECURITY NOTE
-------------
This implementation does not use dangerouslySetInnerHTML.
Assistant text remains React-rendered text, which avoids injecting raw HTML from model output.
