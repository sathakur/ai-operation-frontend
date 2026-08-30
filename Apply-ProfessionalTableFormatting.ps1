param(
    [string]$FrontendRepo = "C:\script\ai-operation-frontend"
)

$ErrorActionPreference = "Stop"

$appFile = Join-Path $FrontendRepo "src\App.jsx"
$cssFile = Join-Path $FrontendRepo "src\styles.css"

if (-not (Test-Path $appFile)) { throw "App.jsx not found: $appFile" }
if (-not (Test-Path $cssFile)) { throw "styles.css not found: $cssFile" }

Write-Host "Creating backups..."
Copy-Item $appFile "$appFile.before-professional-tables.bak" -Force
Copy-Item $cssFile "$cssFile.before-professional-tables.bak" -Force

$appText = [System.IO.File]::ReadAllText($appFile)

$startMarker = "const renderAssistantText = (text) => {"
$endMarker = "function App({ loginRequest, runtimeConfig }) {"

$startIndex = $appText.IndexOf($startMarker)
$endIndex = $appText.IndexOf($endMarker)

if ($startIndex -lt 0 -or $endIndex -lt 0 -or $endIndex -le $startIndex) {
    throw "Could not locate the existing assistant formatter in src\App.jsx."
}

$newFormatter = @'
const cleanMarkdownValue = (value) =>
  String(value || "")
    .trim()
    .replace(/\s{2,}$/g, "");

const parseRecordTable = (lines) => {
  const records = [];
  let current = null;
  let firstRecordIndex = -1;
  let lastRecordIndex = -1;

  const numberedField =
    /^\d+[.)]\s+\*\*([^*]+):\*\*\s*(.+?)\s*$/;
  const bulletField =
    /^[-*]\s+\*\*([^*]+):\*\*\s*(.+?)\s*$/;

  lines.forEach((rawLine, index) => {
    const line = rawLine.trim();
    const numberedMatch = line.match(numberedField);
    const bulletMatch = line.match(bulletField);

    if (numberedMatch) {
      if (current) {
        records.push(current);
      }

      current = {
        [numberedMatch[1].trim()]:
          cleanMarkdownValue(numberedMatch[2])
      };

      if (firstRecordIndex < 0) {
        firstRecordIndex = index;
      }

      lastRecordIndex = index;
      return;
    }

    if (current && bulletMatch) {
      current[bulletMatch[1].trim()] =
        cleanMarkdownValue(bulletMatch[2]);
      lastRecordIndex = index;
      return;
    }

    if (current && line === "") {
      lastRecordIndex = index;
    }
  });

  if (current) {
    records.push(current);
  }

  if (records.length < 2) {
    return null;
  }

  const columns = [];
  records.forEach((record) => {
    Object.keys(record).forEach((key) => {
      if (!columns.includes(key)) {
        columns.push(key);
      }
    });
  });

  if (columns.length < 2) {
    return null;
  }

  return {
    records,
    columns,
    firstRecordIndex,
    lastRecordIndex
  };
};

const parseSummaryTable = (lines) => {
  const rows = [];
  let firstIndex = -1;
  let lastIndex = -1;

  const summaryField =
    /^[-*]\s+\*\*([^*]+):\*\*\s*(.+?)\s*$/;

  lines.forEach((rawLine, index) => {
    const line = rawLine.trim();
    const match = line.match(summaryField);

    if (!match) {
      return;
    }

    if (firstIndex < 0) {
      firstIndex = index;
    }

    lastIndex = index;

    rows.push({
      label: match[1].trim(),
      value: cleanMarkdownValue(match[2])
    });
  });

  if (rows.length < 4) {
    return null;
  }

  return {
    rows,
    firstIndex,
    lastIndex
  };
};

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
                {record[column] || "—"}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  </div>
);

const renderStandardAssistantText = (lines) => {
  const blocks = [];
  let listItems = [];
  let listType = null;

  const flushList = () => {
    if (listItems.length === 0) {
      return;
    }

    const ListTag =
      listType === "ordered" ? "ol" : "ul";
    const blockIndex = blocks.length;

    blocks.push(
      <ListTag
        key={`assistant-list-${blockIndex}`}
        className="assistant-list"
      >
        {listItems.map((item, index) => (
          <li
            key={`assistant-list-${blockIndex}-${index}`}
          >
            {renderInlineFormatting(
              item,
              `assistant-list-${blockIndex}-${index}`
            )}
          </li>
        ))}
      </ListTag>
    );

    listItems = [];
    listType = null;
  };

  lines.forEach((rawLine, index) => {
    const line = rawLine.trim();

    if (!line) {
      flushList();
      return;
    }

    const bulletMatch = line.match(/^[-*]\s+(.+)$/);
    const numberedMatch =
      line.match(/^\d+[.)]\s+(.+)$/);
    const headingMatch =
      line.match(/^(#{1,3})\s+(.+)$/);

    if (bulletMatch) {
      if (listType && listType !== "unordered") {
        flushList();
      }

      listType = "unordered";
      listItems.push(bulletMatch[1]);
      return;
    }

    if (numberedMatch) {
      if (listType && listType !== "ordered") {
        flushList();
      }

      listType = "ordered";
      listItems.push(numberedMatch[1]);
      return;
    }

    flushList();

    if (headingMatch) {
      const level = headingMatch[1].length;
      const HeadingTag =
        level === 1
          ? "h3"
          : level === 2
            ? "h4"
            : "h5";

      blocks.push(
        <HeadingTag
          key={`assistant-heading-${index}`}
          className="assistant-heading"
        >
          {renderInlineFormatting(
            headingMatch[2],
            `assistant-heading-${index}`
          )}
        </HeadingTag>
      );
      return;
    }

    blocks.push(
      <p
        key={`assistant-paragraph-${index}`}
        className="assistant-paragraph"
      >
        {renderInlineFormatting(
          line,
          `assistant-paragraph-${index}`
        )}
      </p>
    );
  });

  flushList();
  return blocks;
};

const renderAssistantText = (text) => {
  const lines = String(text || "")
    .replace(/\r\n/g, "\n")
    .split("\n");

  const recordTable = parseRecordTable(lines);

  if (recordTable) {
    const before = lines.slice(
      0,
      recordTable.firstRecordIndex
    );
    const after = lines.slice(
      recordTable.lastRecordIndex + 1
    );

    return [
      ...renderStandardAssistantText(before),
      renderTable(
        recordTable.columns,
        recordTable.records,
        "assistant-record-table"
      ),
      ...renderStandardAssistantText(after)
    ];
  }

  const nonEmptyLines = lines.filter(
    (line) => line.trim() !== ""
  );
  const summaryTable = parseSummaryTable(
    nonEmptyLines.filter((line) =>
      /^[-*]\s+\*\*[^*]+:\*\*/.test(line.trim())
    )
  );

  const summaryCandidateCount =
    nonEmptyLines.filter((line) =>
      /^[-*]\s+\*\*[^*]+:\*\*/.test(line.trim())
    ).length;

  if (
    summaryTable &&
    summaryCandidateCount >= 4
  ) {
    const summaryRows = nonEmptyLines
      .map((line) =>
        line
          .trim()
          .match(
            /^[-*]\s+\*\*([^*]+):\*\*\s*(.+?)\s*$/
          )
      )
      .filter(Boolean)
      .map((match) => ({
        Resource: match[1].trim(),
        Count: cleanMarkdownValue(match[2])
      }));

    const otherLines = lines.filter(
      (line) =>
        !/^[-*]\s+\*\*[^*]+:\*\*/.test(
          line.trim()
        )
    );

    return [
      ...renderStandardAssistantText(otherLines),
      renderTable(
        ["Resource", "Count"],
        summaryRows,
        "assistant-summary-table"
      )
    ];
  }

  return renderStandardAssistantText(lines);
};

'@

$appText =
    $appText.Substring(0, $startIndex) +
    $newFormatter +
    $appText.Substring($endIndex)

$cssText = [System.IO.File]::ReadAllText($cssFile)

$cssMarker = "/* Professional assistant tables */"

$tableCss = @'

/* Professional assistant tables */
.assistant-table-wrap{
  width:100%;
  max-width:100%;
  margin:12px 0 6px;
  overflow-x:auto;
  border:1px solid #29415c;
  border-radius:10px;
  background:#0a1828;
  box-shadow:0 8px 20px rgba(0,0,0,.14);
}
.assistant-table{
  width:100%;
  min-width:620px;
  border-collapse:collapse;
  table-layout:auto;
  white-space:normal;
  font-size:12px;
  line-height:1.45;
}
.assistant-table thead{
  background:#102a42;
}
.assistant-table th{
  padding:10px 12px;
  border-bottom:1px solid #31506f;
  color:#89cffa;
  text-align:left;
  font-size:10px;
  font-weight:800;
  letter-spacing:.035em;
  text-transform:uppercase;
  white-space:nowrap;
}
.assistant-table td{
  padding:10px 12px;
  border-bottom:1px solid #1b3047;
  color:#dce7f2;
  vertical-align:top;
  overflow-wrap:anywhere;
}
.assistant-table tbody tr:last-child td{
  border-bottom:0;
}
.assistant-table tbody tr:nth-child(even){
  background:rgba(25,57,84,.18);
}
.assistant-table tbody tr:hover{
  background:rgba(46,168,255,.07);
}
.assistant-table td:first-child{
  color:#f0f6fc;
  font-weight:650;
}
.message-bubble.assistant .assistant-table-wrap{
  min-width:min(720px,calc(100vw - 390px));
}
@media(max-width:980px){
  .message-bubble.assistant .assistant-table-wrap{
    min-width:0;
  }
}
@media(max-width:760px){
  .assistant-table{
    min-width:560px;
    font-size:11px;
  }
  .assistant-table th,
  .assistant-table td{
    padding:8px 10px;
  }
}
'@

if (-not $cssText.Contains($cssMarker)) {
    $cssText =
        $cssText.TrimEnd("`r","`n") +
        $tableCss +
        "`n"
}

$utf8NoBom =
    New-Object System.Text.UTF8Encoding($false)

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
Write-Host "Professional table formatting applied successfully."
Write-Host ""
Write-Host "Changes:"
Write-Host "  - repeated numbered Azure records -> responsive table"
Write-Host "  - resource-summary key/value lists -> Resource / Count table"
Write-Host "  - normal paragraphs, headings, bullets and bold still supported"
Write-Host "  - no dangerouslySetInnerHTML"
Write-Host "  - no npm dependency added"
Write-Host ""
Write-Host "Backups:"
Write-Host "  $appFile.before-professional-tables.bak"
Write-Host "  $cssFile.before-professional-tables.bak"
