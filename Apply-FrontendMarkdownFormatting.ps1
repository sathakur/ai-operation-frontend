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

Write-Host "Creating backups..."
Copy-Item $appFile "$appFile.before-markdown-formatting.bak" -Force
Copy-Item $cssFile "$cssFile.before-markdown-formatting.bak" -Force

$appText = [System.IO.File]::ReadAllText($appFile)

$marker = @'
function App({ loginRequest, runtimeConfig }) {
'@

if (-not $appText.Contains($marker)) {
    throw "Could not find App() marker in src\App.jsx."
}

$formatter = @'
const renderInlineFormatting = (text, keyPrefix) => {
  const parts = String(text).split(/(\*\*[^*]+\*\*)/g);

  return parts.map((part, index) => {
    const key = `${keyPrefix}-inline-${index}`;

    if (
      part.startsWith("**") &&
      part.endsWith("**") &&
      part.length > 4
    ) {
      return (
        <strong key={key}>
          {part.slice(2, -2)}
        </strong>
      );
    }

    return <span key={key}>{part}</span>;
  });
};

const renderAssistantText = (text) => {
  const lines = String(text || "").replace(/\r\n/g, "\n").split("\n");
  const blocks = [];
  let listItems = [];
  let listType = null;

  const flushList = () => {
    if (listItems.length === 0) {
      return;
    }

    const ListTag = listType === "ordered" ? "ol" : "ul";
    const blockIndex = blocks.length;

    blocks.push(
      <ListTag
        key={`assistant-list-${blockIndex}`}
        className="assistant-list"
      >
        {listItems.map((item, index) => (
          <li key={`assistant-list-${blockIndex}-${index}`}>
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
    const numberedMatch = line.match(/^\d+[.)]\s+(.+)$/);
    const headingMatch = line.match(/^(#{1,3})\s+(.+)$/);

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
        level === 1 ? "h3" : level === 2 ? "h4" : "h5";

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

'@

$appText = $appText.Replace($marker, $formatter + $marker)

$oldRender = @'
                          <div className="message-text">
                            {message.text}
                          </div>
'@

$newRender = @'
                          <div className="message-text">
                            {message.role === "assistant"
                              ? renderAssistantText(message.text)
                              : message.text}
                          </div>
'@

if (-not $appText.Contains($oldRender)) {
    throw "Could not find the message-text render block in src\App.jsx."
}

$appText = $appText.Replace($oldRender, $newRender)

$cssText = [System.IO.File]::ReadAllText($cssFile)

$cssAddition = @'

/* Assistant response formatting */
.message-text .assistant-paragraph{
  margin:0 0 8px;
}
.message-text .assistant-paragraph:last-child{
  margin-bottom:0;
}
.message-text .assistant-list{
  margin:7px 0 10px;
  padding-left:22px;
}
.message-text .assistant-list:last-child{
  margin-bottom:0;
}
.message-text .assistant-list li{
  margin:4px 0;
  padding-left:2px;
}
.message-text .assistant-heading{
  margin:10px 0 6px;
  color:#eef5fb;
  line-height:1.35;
}
.message-text h3.assistant-heading{
  font-size:15px;
}
.message-text h4.assistant-heading{
  font-size:14px;
}
.message-text h5.assistant-heading{
  font-size:13px;
}
.message-text strong{
  color:#f2f7fc;
  font-weight:700;
}
'@

if (-not $cssText.Contains("/* Assistant response formatting */")) {
    $cssText = $cssText.TrimEnd("`r","`n") + $cssAddition + "`n"
}

# Write UTF-8 without BOM (compatible with Windows PowerShell 5.1)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($appFile, $appText, $utf8NoBom)
[System.IO.File]::WriteAllText($cssFile, $cssText, $utf8NoBom)

Write-Host ""
Write-Host "Frontend formatting fix applied successfully."
Write-Host ""
Write-Host "Changed:"
Write-Host "  $appFile"
Write-Host "    - bold Markdown (**text**)"
Write-Host "    - bullet lists"
Write-Host "    - numbered lists"
Write-Host "    - simple # / ## / ### headings"
Write-Host "  $cssFile"
Write-Host "    - assistant list/heading/paragraph styles"
Write-Host ""
Write-Host "Backups:"
Write-Host "  $appFile.before-markdown-formatting.bak"
Write-Host "  $cssFile.before-markdown-formatting.bak"
