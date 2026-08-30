param(
    [string]$FrontendRepo = "C:\script\ai-operation-frontend"
)

$ErrorActionPreference = "Stop"

$appFile = Join-Path $FrontendRepo "src\App.jsx"

if (-not (Test-Path $appFile)) {
    throw "App.jsx not found: $appFile"
}

Copy-Item $appFile "$appFile.before-formatting-v3.bak" -Force

$appText = [System.IO.File]::ReadAllText($appFile)

$insertBefore = "const renderStandardAssistantText = (lines) =>"
$insertIndex = $appText.IndexOf($insertBefore)

if ($insertIndex -lt 0) {
    throw "Could not find renderStandardAssistantText marker."
}

if (-not $appText.Contains("const parsePlainRecordTable = (lines) =>")) {

$helpers = @'
const normalizeLocation = (value) => {
  const text = String(value || "").trim();

  const known = {
    eastus: "East US",
    eastus2: "East US 2",
    westus: "West US",
    westus2: "West US 2",
    westus3: "West US 3",
    centralus: "Central US",
    northcentralus: "North Central US",
    southcentralus: "South Central US",
    westcentralus: "West Central US",
    northeurope: "North Europe",
    westeurope: "West Europe",
    uksouth: "UK South",
    ukwest: "UK West",
    southeastasia: "Southeast Asia",
    eastasia: "East Asia",
    centralindia: "Central India",
    southindia: "South India",
    westindia: "West India",
    australiaeast: "Australia East",
    australiasoutheast: "Australia Southeast"
  };

  return known[text.toLowerCase()] || text;
};

const stripCodeTicks = (value) =>
  String(value || "")
    .trim()
    .replace(/^`+|`+$/g, "");

const dedupeRecords = (records) => {
  const seen = new Set();

  return records.filter((record) => {
    const id = String(
      record.ID || record.Id || ""
    ).toLowerCase();

    const fallback = [
      record.Name || "",
      record.Subscription ||
        record["Subscription Name"] ||
        "",
      record["Resource Group"] || ""
    ]
      .join("|")
      .toLowerCase();

    const key = id || fallback;

    if (!key || seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
};

const parsePlainRecordTable = (lines) => {
  const allowedFields = new Set([
    "Name",
    "Type",
    "Location",
    "Subscription",
    "Subscription Name",
    "Resource Group",
    "ID",
    "Id"
  ]);

  const records = [];
  let current = null;
  let firstIndex = -1;
  let lastIndex = -1;

  const fieldRegex =
    /^(?:[-*]\s*)?(?:\*\*)?([^:*]+?)(?:\*\*)?\s*:\s*(.+?)\s*$/;

  lines.forEach((rawLine, index) => {
    const line = rawLine.trim();
    const match = line.match(fieldRegex);

    if (!match) {
      return;
    }

    const field = match[1].trim();
    let value = cleanMarkdownValue(match[2]);

    if (!allowedFields.has(field)) {
      return;
    }

    value = stripCodeTicks(value);

    if (field === "Location") {
      value = normalizeLocation(value);
    }

    if (field === "Name") {
      if (current?.Name) {
        records.push(current);
      }

      current = {};

      if (firstIndex < 0) {
        firstIndex = index;
      }
    }

    if (!current) {
      return;
    }

    current[field] = value;
    lastIndex = index;
  });

  if (current?.Name) {
    records.push(current);
  }

  const uniqueRecords = dedupeRecords(records);

  if (uniqueRecords.length < 2) {
    return null;
  }

  const preferredColumns = [
    "Name",
    "Type",
    "Location",
    "Subscription",
    "Subscription Name",
    "Resource Group",
    "ID"
  ];

  const columns = preferredColumns.filter(
    (column) =>
      uniqueRecords.some((record) =>
        Object.prototype.hasOwnProperty.call(
          record,
          column
        )
      )
  );

  return {
    records: uniqueRecords,
    columns,
    firstRecordIndex: firstIndex,
    lastRecordIndex: lastIndex
  };
};

const parseMarkdownPipeTable = (lines) => {
  const splitPipeRow = (line) =>
    line
      .trim()
      .replace(/^\|/, "")
      .replace(/\|$/, "")
      .split("|")
      .map((cell) => cleanMarkdownValue(cell));

  const isSeparatorRow = (line) => {
    const cells = splitPipeRow(line);

    return (
      cells.length >= 2 &&
      cells.every((cell) =>
        /^:?-{3,}:?$/.test(cell)
      )
    );
  };

  for (
    let index = 0;
    index < lines.length - 2;
    index++
  ) {
    const headerLine = lines[index]?.trim();
    const separatorLine =
      lines[index + 1]?.trim();

    if (
      !headerLine?.includes("|") ||
      !separatorLine?.includes("|") ||
      !isSeparatorRow(separatorLine)
    ) {
      continue;
    }

    const columns = splitPipeRow(headerLine);

    if (columns.length < 2) {
      continue;
    }

    const records = [];
    let lastIndex = index + 1;

    for (
      let rowIndex = index + 2;
      rowIndex < lines.length;
      rowIndex++
    ) {
      const rowLine =
        lines[rowIndex]?.trim();

      if (
        !rowLine ||
        !rowLine.includes("|")
      ) {
        break;
      }

      const cells =
        splitPipeRow(rowLine);

      if (cells.length < 2) {
        break;
      }

      const record = {};

      columns.forEach(
        (column, columnIndex) => {
          let value =
            cells[columnIndex] || "";

          if (
            column.toLowerCase() ===
            "location"
          ) {
            value =
              normalizeLocation(value);
          }

          record[column] = value;
        }
      );

      records.push(record);
      lastIndex = rowIndex;
    }

    if (records.length > 0) {
      return {
        columns,
        records,
        firstIndex: index,
        lastIndex
      };
    }
  }

  return null;
};

'@

$appText =
    $appText.Substring(0, $insertIndex) +
    $helpers +
    $appText.Substring($insertIndex)
}

# Replace getDisplayColumns block
$gdStart = $appText.IndexOf(
    "const getDisplayColumns = (columns, records) =>"
)
$gdEnd = $appText.IndexOf(
    "const renderCellValue = (column, value) =>"
)

if (
    $gdStart -lt 0 -or
    $gdEnd -lt 0 -or
    $gdEnd -le $gdStart
) {
    throw "Could not locate getDisplayColumns section."
}

$newGetDisplayColumns = @'
const getDisplayColumns = (columns, records) => {
  let result = columns.filter(
    (column) =>
      !["ID", "Id", "Resource ID"].includes(
        column
      )
  );

  if (!result.includes("Type")) {
    return result;
  }

  const typeValues = [
    ...new Set(
      records
        .map((record) => record.Type)
        .filter(Boolean)
        .map((value) =>
          String(value).toLowerCase()
        )
    )
  ];

  if (typeValues.length === 1) {
    result = result.filter(
      (column) => column !== "Type"
    );
  }

  return result;
};

'@

$appText =
    $appText.Substring(0, $gdStart) +
    $newGetDisplayColumns +
    $appText.Substring($gdEnd)

# Replace renderCellValue block
$rcStart = $appText.IndexOf(
    "const renderCellValue = (column, value) =>"
)
$rcEnd = $appText.IndexOf(
    "const renderTable = (columns, records, keyPrefix) =>"
)

if (
    $rcStart -lt 0 -or
    $rcEnd -lt 0 -or
    $rcEnd -le $rcStart
) {
    throw "Could not locate renderCellValue section."
}

$newRenderCell = @'
const renderCellValue = (column, value) => {
  let displayValue =
    column === "Type"
      ? normalizeResourceType(value)
      : String(value || "\u2014");

  if (column === "Location") {
    displayValue =
      normalizeLocation(displayValue);
  }

  const badgeColumns = [
    "Location",
    "Subscription",
    "Subscription Name"
  ];

  if (badgeColumns.includes(column)) {
    return (
      <span
        className="assistant-table-badge"
        title={displayValue}
      >
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

'@

$appText =
    $appText.Substring(0, $rcStart) +
    $newRenderCell +
    $appText.Substring($rcEnd)

# Replace renderTable block
$rtStart = $appText.IndexOf(
    "const renderTable = (columns, records, keyPrefix) =>"
)

$rtEnd = $appText.IndexOf(
    "const parsePlainRecordTable = (lines) =>"
)

if ($rtEnd -lt 0) {
    $rtEnd = $appText.IndexOf(
        "const renderStandardAssistantText = (lines) =>"
    )
}

if (
    $rtStart -lt 0 -or
    $rtEnd -lt 0 -or
    $rtEnd -le $rtStart
) {
    throw "Could not locate renderTable section."
}

$newRenderTable = @'
const renderTable = (
  columns,
  records,
  keyPrefix,
  options = {}
) => {
  const displayColumns =
    getDisplayColumns(columns, records);

  const showResultCount =
    options.showResultCount !== false;

  return (
    <div
      className="assistant-table-section"
      key={`${keyPrefix}-section`}
    >
      {showResultCount && (
        <div className="assistant-table-toolbar">
          <div className="assistant-table-count">
            {records.length}{" "}
            {records.length === 1
              ? "result"
              : "results"}
          </div>
        </div>
      )}

      <div className="assistant-table-wrap">
        <table className="assistant-table">
          <thead>
            <tr>
              {displayColumns.map(
                (column) => (
                  <th
                    key={`${keyPrefix}-head-${column}`}
                  >
                    {column}
                  </th>
                )
              )}
            </tr>
          </thead>
          <tbody>
            {records.map(
              (record, rowIndex) => (
                <tr
                  key={`${keyPrefix}-row-${rowIndex}`}
                >
                  {displayColumns.map(
                    (column) => (
                      <td
                        key={`${keyPrefix}-${rowIndex}-${column}`}
                        data-label={column}
                      >
                        {renderCellValue(
                          column,
                          record[column]
                        )}
                      </td>
                    )
                  )}
                </tr>
              )
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

'@

$appText =
    $appText.Substring(0, $rtStart) +
    $newRenderTable +
    $appText.Substring($rtEnd)

# Insert markdown + plain record handling into renderAssistantText
$renderNeedle = @'
const renderAssistantText = (text) => {
  const lines = String(text || "")
    .replace(/\r\n/g, "\n")
    .split("\n");

'@

if (-not $appText.Contains($renderNeedle)) {
    throw "Could not find renderAssistantText start block."
}

if (-not $appText.Contains(
    "const plainRecordTable ="
)) {

$renderReplacement = @'
const renderAssistantText = (text) => {
  const lines = String(text || "")
    .replace(/\r\n/g, "\n")
    .split("\n");

  const markdownTable =
    parseMarkdownPipeTable(lines);

  if (markdownTable) {
    const before = lines.slice(
      0,
      markdownTable.firstIndex
    );

    const after = lines.slice(
      markdownTable.lastIndex + 1
    );

    const isSummary =
      markdownTable.columns.some(
        (column) =>
          /resource\s*type/i.test(column)
      ) &&
      markdownTable.columns.some(
        (column) =>
          /^count$/i.test(column)
      );

    return [
      ...renderStandardAssistantText(before),
      renderTable(
        markdownTable.columns,
        markdownTable.records,
        "assistant-markdown-table",
        {
          showResultCount: !isSummary
        }
      ),
      ...renderStandardAssistantText(after)
    ];
  }

  const plainRecordTable =
    parsePlainRecordTable(lines);

  if (plainRecordTable) {
    const before = lines.slice(
      0,
      plainRecordTable.firstRecordIndex
    );

    const after = lines.slice(
      plainRecordTable.lastRecordIndex + 1
    );

    return [
      ...renderStandardAssistantText(before),
      renderTable(
        plainRecordTable.columns,
        plainRecordTable.records,
        "assistant-plain-record-table"
      ),
      ...renderStandardAssistantText(after)
    ];
  }

'@

$appText = $appText.Replace(
    $renderNeedle,
    $renderReplacement
)
}

# Suppress result badge for old summary table call
$oldSummaryCall = @'
        "assistant-summary-table"
      )
'@

$newSummaryCall = @'
        "assistant-summary-table",
        { showResultCount: false }
      )
'@

$appText = $appText.Replace(
    $oldSummaryCall,
    $newSummaryCall
)

# Use ASCII-safe fallback handling only; no mojibake replacement is required here.

$utf8NoBom =
    New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    $appFile,
    $appText,
    $utf8NoBom
)

Write-Host ""
Write-Host "SUCCESS - Frontend formatting V3 applied."
Write-Host ""
Write-Host "Now supports:"
Write-Host "  - plain Name/Type/Location/Subscription/Resource Group/ID blocks"
Write-Host "  - Markdown pipe tables"
Write-Host "  - numbered inventory records"
Write-Host "  - bullet summaries"
Write-Host "  - deduped inventory counts"
Write-Host "  - hidden ID column"
Write-Host "  - hidden redundant Type column"
Write-Host "  - Azure region normalization"
Write-Host "  - no misleading result badge on Resource Summary"
Write-Host ""
