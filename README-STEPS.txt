FRONTEND FORMATTING V3
======================

This patch handles all current response styles.

It fixes plain output like:

Name: devstoragesec
Type: Microsoft.Storage/storageAccounts
Location: eastus
Subscription: SecondarySub
Resource Group: rg-storagedec
ID: `/subscriptions/...`

It converts that into the same professional table used by the good
Storage Accounts view.

It also:
- deduplicates rows
- calculates the displayed result count from unique returned records
- hides the very long ID column
- hides Type when every row is the same Azure resource type
- normalizes eastus -> East US, westeurope -> West Europe, etc.
- supports Markdown pipe tables for Resource Summary
- does not show a misleading "N results" badge on Resource Summary

RUN
---
Copy Apply-FrontendFormattingV3.ps1 to:

C:\script\ai-operation-frontend

Then:

cd C:\script\ai-operation-frontend

.\Apply-FrontendFormattingV3.ps1

VERIFY
------
git diff -- src\App.jsx

BUILD
-----
npm run build

If build succeeds:

git add src\App.jsx
git commit -m "Support all Azure inventory response formats"
git push

TEST
----
Show me storage accounts
Show me resource summary
Show me VM names
Show me resource groups

IMPORTANT
---------
The inventory result badge is the number of unique rows actually returned
in that response. It does not trust or invent a number from assistant prose.
