param(
    [string]$FrontendRepo = "C:\script\ai-operation-frontend"
)

$ErrorActionPreference = "Stop"

$appFile = Join-Path $FrontendRepo "src\App.jsx"
$cssFile = Join-Path $FrontendRepo "src\styles.css"

if (-not (Test-Path $appFile)) {
    throw "App.jsx not found: $appFile"
}

if (-not (Test-Path $cssFile)) {
    throw "styles.css not found: $cssFile"
}

Copy-Item $appFile "$appFile.before-structured-response.bak" -Force
Copy-Item $cssFile "$cssFile.before-structured-response.bak" -Force

$appText = [System.IO.File]::ReadAllText($appFile)
$cssText = [System.IO.File]::ReadAllText($cssFile)

# ------------------------------------------------------------
# 1. Add structured presentation renderer
# ------------------------------------------------------------
if (-not $appText.Contains("const renderStructuredPresentation =")) {

    $marker = "function App({ loginRequest, runtimeConfig }) {"
    $index = $appText.IndexOf($marker)

    if ($index -lt 0) {
        throw "Could not find App() marker in src\App.jsx."
    }

    $renderer = @'
const renderStructuredPresentation = (presentation) => {
  if (!presentation) {
    return null;
  }

  if (presentation.responseType === "metric") {
    return (
      <div className="structured-response">
        {presentation.title && (
          <div className="structured-response-title">
            {presentation.title}
          </div>
        )}

        <div className="structured-metric">
          {presentation.total ?? 0}
        </div>

        {presentation.summary && (
          <div className="structured-response-summary">
            {presentation.summary}
          </div>
        )}
      </div>
    );
  }

  if (presentation.responseType === "table") {
    const columns =
      Array.isArray(presentation.columns)
        ? presentation.columns
        : [];

    const rows =
      Array.isArray(presentation.rows)
        ? presentation.rows
        : [];

    return (
      <div className="structured-response">
        {presentation.title && (
          <div className="structured-response-title">
            {presentation.title}
          </div>
        )}

        {presentation.summary && (
          <div className="structured-response-summary">
            {presentation.summary}
          </div>
        )}

        <div className="assistant-table-toolbar">
          <div className="assistant-table-count">
            {presentation.total ?? rows.length}{" "}
            {presentation.total === 1 ? "result" : "results"}
          </div>
        </div>

        <div className="assistant-table-wrap">
          <table className="assistant-table">
            <thead>
              <tr>
                {columns.map((column) => (
                  <th key={`structured-head-${column}`}>
                    {column}
                  </th>
                ))}
              </tr>
            </thead>

            <tbody>
              {rows.map((row, rowIndex) => (
                <tr key={`structured-row-${rowIndex}`}>
                  {columns.map((column) => (
                    <td
                      key={`structured-${rowIndex}-${column}`}
                      data-label={column}
                    >
                      <span
                        className="assistant-table-cell-text"
                        title={String(row?.[column] ?? "")}
                      >
                        {row?.[column] ?? "\u2014"}
                      </span>
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  }

  return null;
};

'@

    $appText =
        $appText.Substring(0, $index) +
        $renderer +
        $appText.Substring($index)
}

# ------------------------------------------------------------
# 2. Store presentation from backend response
# ------------------------------------------------------------
if (-not $appText.Contains("presentation:`r`n") -and
    -not $appText.Contains("presentation:`n")) {

    $old = @'
          text:
            body?.answer ||
            "The assistant returned no text response.",
          meta: {
'@

    $new = @'
          text:
            body?.answer ||
            "The assistant returned no text response.",
          presentation:
            body?.presentation || null,
          meta: {
'@

    if (-not $appText.Contains($old)) {
        throw "Could not find assistant response object marker in src\App.jsx."
    }

    $appText = $appText.Replace($old, $new)
}

# ------------------------------------------------------------
# 3. Render structured presentation first, fallback to old renderer
# ------------------------------------------------------------
$oldRender = @'
                            {message.role === "assistant"
                              ? renderAssistantText(message.text)
                              : message.text}
'@

$newRender = @'
                            {message.role === "assistant"
                              ? (
                                  message.presentation
                                    ? renderStructuredPresentation(
                                        message.presentation
                                      )
                                    : renderAssistantText(
                                        message.text
                                      )
                                )
                              : message.text}
'@

if ($appText.Contains($oldRender)) {
    $appText = $appText.Replace($oldRender, $newRender)
}
elseif (-not $appText.Contains("renderStructuredPresentation(")) {
    throw "Could not find assistant message renderer marker in src\App.jsx."
}

# ------------------------------------------------------------
# 4. Add CSS once
# ------------------------------------------------------------
if (-not $cssText.Contains("/* Structured backend presentation contract */")) {

$structuredCss = @'

/* Structured backend presentation contract */
.structured-response {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-width: 0;
}

.structured-response-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.3;
}

.structured-response-summary {
  font-size: 13px;
  line-height: 1.5;
  opacity: 0.82;
}

.structured-metric {
  font-size: 34px;
  font-weight: 750;
  line-height: 1;
  letter-spacing: -0.03em;
}

'@

    $cssText += $structuredCss
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    $appFile,
    $appText,
    $utf8NoBom
)

[System.IO.File]::WriteAllText(
    $cssFile,
    $cssText,
    $utf8NoBom
)

Write-Host ""
Write-Host "SUCCESS - Structured frontend response support applied."
Write-Host ""
Write-Host "Changed:"
Write-Host "  src\App.jsx"
Write-Host "  src\styles.css"
Write-Host ""
Write-Host "Backups:"
Write-Host "  src\App.jsx.before-structured-response.bak"
Write-Host "  src\styles.css.before-structured-response.bak"
Write-Host ""
Write-Host "Next:"
Write-Host "  npm run build"
Write-Host ""
