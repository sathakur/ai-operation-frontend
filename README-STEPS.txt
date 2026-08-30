STRUCTURED FRONTEND V1
======================

This frontend patch is for the backend structured-response contract
you already pushed.

WHAT IT DOES
------------
The frontend now prefers:

body.presentation

instead of trying to parse Foundry/GPT formatting.

Supported response types:
- table
- metric

If presentation is missing, the existing renderAssistantText() logic is
still used as a fallback. This means the current UI remains backward compatible.

FILES CHANGED
-------------
src\App.jsx
src\styles.css

The script creates backups before changing either file.

STEP 1 - COPY SCRIPT
--------------------
Copy:

Apply-StructuredFrontend.ps1

to:

C:\script\ai-operation-frontend

STEP 2 - RUN
------------
PowerShell:

cd C:\script\ai-operation-frontend

.\Apply-StructuredFrontend.ps1

Expected:

SUCCESS - Structured frontend response support applied.

STEP 3 - REVIEW
---------------
git diff -- src\App.jsx src\styles.css

STEP 4 - BUILD
--------------
npm run build

You want a successful Vite build.

If the build fails, STOP and share the error.
Do not push a failing build.

STEP 5 - COMMIT
---------------
git add src\App.jsx src\styles.css

git commit -m "Render structured Azure inventory responses"

git push

STEP 6 - WAIT FOR STATIC WEB APP DEPLOYMENT
-------------------------------------------
Wait for GitHub Actions / Azure Static Web Apps deployment to finish.

Then open the app and press:

Ctrl + F5

STEP 7 - TEST
-------------
Test in this order:

1. Show me storage accounts

Expected:
- title: Azure Storage Accounts
- summary from backend
- professional table
- columns:
  Name | Location | Subscription | Resource Group
- count comes from backend presentation.total

2. Show me resource summary

Expected:
- Resource Type | Count
- total comes from backend sum of resourceCount

3. How many virtual machines are there?

Expected:
- metric response
- count comes from backend get_vm_count result

4. Show me VM names

5. Show me resource groups

6. Show me subnets

7. Show me subscription names

IMPORTANT
---------
Do NOT delete the old Markdown/plain-record parsers yet.
They are retained as fallback for any response that does not include
presentation.

Once all structured responses are verified, we can remove the old
formatting/parsing code in a later cleanup.

ROLLBACK
--------
The script creates:

src\App.jsx.before-structured-response.bak
src\styles.css.before-structured-response.bak

You can restore them manually if needed.
