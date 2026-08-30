TABLE POLISH V2 - FIXED
=======================

Why the previous script failed:
It tried to match the entire renderTable function character-for-character.
Your App.jsx structure is correct, but exact text matching is fragile.

This fixed script instead locates:
  const renderTable = ...
through:
  const renderStandardAssistantText = ...

and replaces only that section.

RUN
---
Copy/extract Apply-TablePolishV2-Fixed.ps1 into:
C:\script\ai-operation-frontend

Then:

cd C:\script\ai-operation-frontend

.\Apply-TablePolishV2-Fixed.ps1

VERIFY
------
git diff -- src\App.jsx
git diff -- src\styles.css
npm run build

Do not commit until npm run build succeeds.

Then:

git add src\App.jsx src\styles.css
git commit -m "Polish Azure inventory table presentation"
git push
