param(
    [string]$FrontendRepo = "C:\script\ai-operation-frontend"
)

$ErrorActionPreference = "Stop"

$appFile = Join-Path $FrontendRepo "src\App.jsx"
$cssFile = Join-Path $FrontendRepo "src\styles.css"

if (-not (Test-Path $appFile)) { throw "App.jsx not found: $appFile" }
if (-not (Test-Path $cssFile)) { throw "styles.css not found: $cssFile" }

Copy-Item $appFile "$appFile.before-table-polish-v2.bak" -Force
Copy-Item $cssFile "$cssFile.before-table-polish-v2.bak" -Force

$appText = [System.IO.File]::ReadAllText($appFile)

$old = @'
const renderTable = (columns, records, keyPrefix) => (
  <div
    className="assistant-table-wrap"
    key={`${keyPrefix}-wrap`}
  >
    <table className="assistant-table">
      <thead>
        <tr>
          {columns.map((column) => (
            <th key={`${keyPrefix}-head-${column}`}>
              {column}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {records.map((record, rowIndex) => (
          <tr key={`${keyPrefix}-row-${rowIndex}`}>
            {columns.map((column) => (
              <td
                key={`${keyPrefix}-${rowIndex}-${column}`}
                data-label={column}
              >
                {record[column] || "â€”"}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  </div>
);
'@

$new = @'
const normalizeResourceType = (value) => {
  const text = String(value || "");

  if (
    text.toLowerCase() ===
    "microsoft.storage/storageaccounts"
  ) {
    return "Storage account";
  }

  return text;
};

const getDisplayColumns = (columns, records) => {
  if (!columns.includes("Type")) {
    return columns;
  }

  const typeValues = [
    ...new Set(
      records
        .map((record) => record.Type)
        .filter(Boolean)
    )
  ];

  // When all rows are the same resource type, the Type
  // column adds noise. Keep the table focused on useful
  // inventory information.
  if (typeValues.length === 1) {
    return columns.filter(
      (column) => column !== "Type"
    );
  }

  return columns;
};

const renderCellValue = (column, value) => {
  const displayValue =
    column === "Type"
      ? normalizeResourceType(value)
      : String(value || "—");

  const badgeColumns = [
    "Location",
    "Subscription",
    "Subscription Name"
  ];

  if (badgeColumns.includes(column)) {
    return (
      <span className="assistant-table-badge">
        {displayValue}
      </span>
    );
  }

  return (
    <span
      className="assistant-table-cell-text"
      title={displayValue}
    >
      {displayValue}
    </span>
  );
};

const renderTable = (columns, records, keyPrefix) => {
  const displayColumns =
    getDisplayColumns(columns, records);

  return (
    <div
      className="assistant-table-section"
      key={`${keyPrefix}-section`}
    >
      <div className="assistant-table-toolbar">
        <div className="assistant-table-count">
          {records.length}{" "}
          {records.length === 1 ? "result" : "results"}
        </div>
      </div>

      <div className="assistant-table-wrap">
        <table className="assistant-table">
          <thead>
            <tr>
              {displayColumns.map((column) => (
                <th key={`${keyPrefix}-head-${column}`}>
                  {column}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {records.map((record, rowIndex) => (
              <tr key={`${keyPrefix}-row-${rowIndex}`}>
                {displayColumns.map((column) => (
                  <td
                    key={`${keyPrefix}-${rowIndex}-${column}`}
                    data-label={column}
                  >
                    {renderCellValue(
                      column,
                      record[column]
                    )}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
'@

if (-not $appText.Contains($old)) {
    throw "Current renderTable block was not found. Your App.jsx may differ from the expected deployed version."
}

$appText = $appText.Replace($old, $new)

$cssText = [System.IO.File]::ReadAllText($cssFile)

$marker = "/* Table polish v2 */"

$css = @'

/* Table polish v2 */
.message-row.assistant .message-content{
  width:min(1040px,98%);
}
.message-bubble.assistant{
  width:100%;
}
.assistant-table-section{
  width:100%;
  margin-top:10px;
}
.assistant-table-toolbar{
  display:flex;
  align-items:center;
  justify-content:space-between;
  margin:0 0 7px;
}
.assistant-table-count{
  display:inline-flex;
  align-items:center;
  min-height:24px;
  padding:3px 9px;
  border:1px solid #24445f;
  border-radius:999px;
  background:#0b2033;
  color:#83c8f2;
  font-size:10px;
  font-weight:700;
}
.assistant-table-wrap{
  margin:0;
  border-radius:9px;
  overflow:auto;
}
.assistant-table{
  min-width:760px;
  table-layout:fixed;
  line-height:1.35;
}
.assistant-table th{
  position:sticky;
  top:0;
  z-index:1;
  padding:9px 12px;
  background:#12304a;
  font-size:10px;
}
.assistant-table td{
  padding:9px 12px;
  font-size:11px;
}
.assistant-table th:nth-child(1),
.assistant-table td:nth-child(1){
  width:24%;
}
.assistant-table th:nth-child(2),
.assistant-table td:nth-child(2){
  width:16%;
}
.assistant-table th:nth-child(3),
.assistant-table td:nth-child(3){
  width:22%;
}
.assistant-table th:nth-child(4),
.assistant-table td:nth-child(4){
  width:38%;
}
.assistant-table-cell-text{
  display:block;
  min-width:0;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
}
.assistant-table td:first-child .assistant-table-cell-text{
  font-weight:700;
  color:#f4f8fc;
}
.assistant-table-badge{
  display:inline-flex;
  max-width:100%;
  align-items:center;
  padding:3px 7px;
  border:1px solid #294962;
  border-radius:999px;
  background:#0b2237;
  color:#b7d9ef;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
}
.assistant-table tbody tr{
  height:42px;
}
.assistant-table tbody tr:hover{
  background:rgba(46,168,255,.09);
}
@media(max-width:980px){
  .message-row.assistant .message-content{
    width:98%;
  }
}
@media(max-width:760px){
  .assistant-table{
    min-width:680px;
  }
  .assistant-table-toolbar{
    margin-bottom:6px;
  }
}
'@

if (-not $cssText.Contains($marker)) {
    $cssText = $cssText.TrimEnd("`r","`n") + $css + "`n"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($appFile, $appText, $utf8NoBom)
[System.IO.File]::WriteAllText($cssFile, $cssText, $utf8NoBom)

Write-Host ""
Write-Host "Table polish v2 applied."
Write-Host ""
Write-Host "Improvements:"
Write-Host "  - hides redundant Type column when every row is the same type"
Write-Host "  - adds result-count pill"
Write-Host "  - wider assistant response area"
Write-Host "  - compact row height"
Write-Host "  - prevents ugly character-by-character wrapping"
Write-Host "  - ellipsis + tooltip for long values"
Write-Host "  - badges for Location and Subscription"
Write-Host "  - sticky table header"
Write-Host "  - fixes fallback dash encoding"
Write-Host ""
