param(
    [string]$RepoPath = "C:\script\ai-operation-frontend"
)

$ErrorActionPreference = "Stop"

$appPath = Join-Path $RepoPath "src\App.jsx"
$cssPath = Join-Path $RepoPath "src\styles.css"

if (-not (Test-Path $appPath)) {
    throw "App.jsx not found: $appPath"
}

if (-not (Test-Path $cssPath)) {
    throw "styles.css not found: $cssPath"
}

$app = [System.IO.File]::ReadAllText($appPath)
$css = [System.IO.File]::ReadAllText($cssPath)

# ------------------------------------------------------------
# Safety checks
# ------------------------------------------------------------
$forbidden = @(
    "dedupeRecords(",
    "parsePlainRecordTable(",
    "parseMarkdownPipeTable(",
    "normalizeLocation("
)

foreach ($item in $forbidden) {
    if ($app.Contains($item)) {
        throw "STOP: old broken parser code is still present: $item"
    }
}

if ($app.Contains("const renderStructuredPresentation =")) {
    throw "STOP: structured presentation renderer already exists. Do not run this script twice."
}

if (-not $app.Contains("function App({ loginRequest, runtimeConfig }) {")) {
    throw "STOP: expected App() function marker not found."
}

if (-not $app.Contains('body?.answer ||')) {
    throw "STOP: expected backend answer marker not found."
}

if (-not $app.Contains('renderAssistantText(message.text)')) {
    throw "STOP: expected assistant renderer marker not found."
}

# ------------------------------------------------------------
# Create backups only after validation
# ------------------------------------------------------------
Copy-Item $appPath "$appPath.before-structured-v2.bak" -Force
Copy-Item $cssPath "$cssPath.before-structured-v2.bak" -Force

# ------------------------------------------------------------
# 1. Insert structured renderer before App()
# ------------------------------------------------------------
$renderer = @'
const renderStructuredPresentation = (presentation) => {
  if (!presentation) {
    return null;
  }

  const responseType =
    String(presentation.responseType || "").toLowerCase();

  const title = presentation.title || "";
  const summary = presentation.summary || "";

  const columns = Array.isArray(presentation.columns)
    ? presentation.columns
    : [];

  const rows = Array.isArray(presentation.rows)
    ? presentation.rows
    : [];

  if (responseType === "metric") {
    return (
      <div className="structured-response">
        {title && (
          <div className="structured-title">
            {title}
          </div>
        )}

        <div className="structured-metric">
          {presentation.total ?? 0}
        </div>

        {summary && (
          <div className="structured-summary">
            {summary}
          </div>
        )}
      </div>
    );
  }

  if (responseType === "table") {
    return (
      <div className="structured-response">
        <div className="structured-header">
          <div>
            {title && (
              <div className="structured-title">
                {title}
              </div>
            )}

            {summary && (
              <div className="structured-summary">
                {summary}
              </div>
            )}
          </div>

          <div className="structured-count">
            {presentation.total ?? rows.length}
          </div>
        </div>

        {rows.length === 0 ? (
          <div className="structured-empty">
            No results found.
          </div>
        ) : (
          <div className="structured-table-wrapper">
            <table className="structured-table">
              <thead>
                <tr>
                  {columns.map((column) => (
                    <th key={`head-${column}`}>
                      {column}
                    </th>
                  ))}
                </tr>
              </thead>

              <tbody>
                {rows.map((row, rowIndex) => (
                  <tr key={`row-${rowIndex}`}>
                    {columns.map((column) => {
                      const matchingKey =
                        Object.keys(row || {}).find(
                          (key) =>
                            key.toLowerCase() ===
                            String(column).toLowerCase()
                        );

                      const value =
                        row?.[column] ??
                        (matchingKey
                          ? row?.[matchingKey]
                          : undefined);

                      return (
                        <td
                          key={`cell-${rowIndex}-${column}`}
                          data-label={column}
                        >
                          {value === null ||
                          value === undefined ||
                          value === ""
                            ? "—"
                            : String(value)}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    );
  }

  return null;
};

'@

$appMarker = "function App({ loginRequest, runtimeConfig }) {"
$app = $app.Replace($appMarker, $renderer + $appMarker)

# ------------------------------------------------------------
# 2. Add body.presentation to assistant messages
#    Flexible regex, not whitespace-sensitive
# ------------------------------------------------------------
$presentationPattern = '(?s)(text:\s*\r?\n\s*body\?\.answer\s*\|\|\s*\r?\n\s*"The assistant returned no text response\.",)(\s*\r?\n\s*meta:\s*\{)'

if (-not [regex]::IsMatch($app, $presentationPattern)) {
    throw "STOP: could not locate assistant response object safely."
}

$app = [regex]::Replace(
    $app,
    $presentationPattern,
    '$1' + "`r`n          presentation:`r`n            body?.presentation || null," + '$2',
    1
)

# ------------------------------------------------------------
# 3. Render structured presentation first
#    Replace only the ternary expression, not whole JSX block
# ------------------------------------------------------------
$oldRenderPattern = '\{message\.role === "assistant"\s*\?\s*renderAssistantText\(message\.text\)\s*:\s*message\.text\}'

$newRender = @'
{message.role === "assistant"
  ? message.presentation
    ? renderStructuredPresentation(
        message.presentation
      )
    : renderAssistantText(
        message.text
      )
  : message.text}
'@

if (-not [regex]::IsMatch($app, $oldRenderPattern)) {
    throw "STOP: could not locate current assistant render expression safely."
}

$app = [regex]::Replace(
    $app,
    $oldRenderPattern,
    $newRender,
    1
)

# ------------------------------------------------------------
# 4. Append CSS once
# ------------------------------------------------------------
$cssMarker = "/* Structured Azure inventory responses V2 */"

if (-not $css.Contains($cssMarker)) {
$structuredCss = @'

/* Structured Azure inventory responses V2 */

.structured-response {
  width: 100%;
  min-width: 0;
}

.structured-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 14px;
}

.structured-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.4;
  margin-bottom: 4px;
}

.structured-summary {
  font-size: 13px;
  line-height: 1.5;
  opacity: 0.78;
}

.structured-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 38px;
  height: 28px;
  padding: 0 10px;
  border: 1px solid rgba(86, 166, 255, 0.28);
  border-radius: 999px;
  background: rgba(24, 113, 184, 0.14);
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
}

.structured-metric {
  margin: 8px 0;
  font-size: 36px;
  line-height: 1;
  font-weight: 750;
  letter-spacing: -0.03em;
}

.structured-table-wrapper {
  width: 100%;
  overflow-x: auto;
  border: 1px solid rgba(125, 170, 210, 0.18);
  border-radius: 10px;
}

.structured-table {
  width: 100%;
  min-width: 650px;
  border-collapse: collapse;
  table-layout: auto;
}

.structured-table thead {
  background: rgba(255, 255, 255, 0.045);
}

.structured-table th {
  padding: 11px 14px;
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.045em;
  white-space: nowrap;
  border-bottom: 1px solid rgba(125, 170, 210, 0.18);
}

.structured-table td {
  padding: 11px 14px;
  font-size: 13px;
  line-height: 1.4;
  vertical-align: top;
  border-bottom: 1px solid rgba(125, 170, 210, 0.10);
  word-break: break-word;
}

.structured-table tbody tr:last-child td {
  border-bottom: none;
}

.structured-table tbody tr:hover {
  background: rgba(255, 255, 255, 0.025);
}

.structured-empty {
  padding: 18px;
  border: 1px dashed rgba(125, 170, 210, 0.25);
  border-radius: 8px;
  font-size: 13px;
  opacity: 0.75;
}

@media (max-width: 800px) {
  .structured-header {
    flex-direction: column;
  }

  .structured-table {
    min-width: 560px;
  }
}
'@

    $css = $css.TrimEnd() + "`r`n" + $structuredCss + "`r`n"
}

# ------------------------------------------------------------
# 5. Final validation before write
# ------------------------------------------------------------
$required = @(
    "const renderStructuredPresentation =",
    "body?.presentation || null",
    "message.presentation",
    "renderStructuredPresentation("
)

foreach ($item in $required) {
    if (-not $app.Contains($item)) {
        throw "STOP: final validation failed. Missing: $item"
    }
}

# ------------------------------------------------------------
# 6. Write UTF-8 no BOM
# ------------------------------------------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    $appPath,
    $app,
    $utf8NoBom
)

[System.IO.File]::WriteAllText(
    $cssPath,
    $css,
    $utf8NoBom
)

Write-Host ""
Write-Host "SUCCESS - Structured Frontend Safe V2 applied."
Write-Host ""
Write-Host "Modified:"
Write-Host "  src\App.jsx"
Write-Host "  src\styles.css"
Write-Host ""
Write-Host "Backups:"
Write-Host "  src\App.jsx.before-structured-v2.bak"
Write-Host "  src\styles.css.before-structured-v2.bak"
Write-Host ""
Write-Host "Now run:"
Write-Host "  git status"
Write-Host "  git diff --stat"
Write-Host "  git diff -- src/App.jsx"
Write-Host ""
