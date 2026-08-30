STRUCTURED FRONTEND SAFE V2
===========================

This V2 fixes the marker problem from V1.

IMPORTANT
---------
Do NOT run the V1 script again.
Do NOT run any of the old formatting scripts.
Do NOT run git stash pop.

CURRENT STATUS
--------------
Your working app is stable.
The V1 script failed before changing src\App.jsx or src\styles.css.
The leftover V1 files/backups are untracked and should not be committed.

CLEANUP OLD V1 FILES
--------------------
From C:\script\ai-operation-frontend run:

Remove-Item .\Apply-StructuredFrontend-Safe.ps1 -ErrorAction SilentlyContinue
Remove-Item .\StructuredPresentation.jsx -ErrorAction SilentlyContinue
Remove-Item .\structured-response.css -ErrorAction SilentlyContinue
Remove-Item .\src\App.jsx.before-structured-safe.bak -ErrorAction SilentlyContinue
Remove-Item .\src\styles.css.before-structured-safe.bak -ErrorAction SilentlyContinue

Restore the README changed by V1:

git restore README-STEPS.txt

Then check:

git status

Ideally the working tree is clean before V2.

APPLY V2
--------
1. Copy Apply-StructuredFrontend-Safe-V2.ps1 into:
   C:\script\ai-operation-frontend

2. Run:

cd C:\script\ai-operation-frontend
powershell -ExecutionPolicy Bypass -File .\Apply-StructuredFrontend-Safe-V2.ps1

3. Expected output:

SUCCESS - Structured Frontend Safe V2 applied.

4. Check:

git status
git diff --stat

Expected tracked changes:
  modified: src\App.jsx
  modified: src\styles.css

The V2 .bak files will be untracked. Do not add them.

5. Optional visual diff:

git diff -- src/App.jsx
git diff -- src/styles.css

6. Commit ONLY the two src files:

git add src\App.jsx src\styles.css
git commit -m "Render structured Azure inventory responses safely"
git push

7. Wait for Azure Static Web Apps / GitHub Actions deployment.

8. Ctrl+F5 the app.

9. Test:
   Show me subscription names
   Show me storage accounts
   Show me resource groups
   How many resources are there?

EXPECTED
--------
- Tables use backend presentation.rows directly.
- Count/metric responses use presentation.total.
- Existing login/auth/chat UI remains unchanged.
- Plain assistant text is still the fallback.
- No dedupeRecords / Markdown parsing code is introduced.

ROLLBACK BEFORE COMMIT
----------------------
Copy-Item .\src\App.jsx.before-structured-v2.bak .\src\App.jsx -Force
Copy-Item .\src\styles.css.before-structured-v2.bak .\src\styles.css -Force

ROLLBACK AFTER COMMIT
---------------------
git revert HEAD
git push
