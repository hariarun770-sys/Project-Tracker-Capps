param(
    [int]$Port = 3000,
    [switch]$OpenBrowser = $true
)

$RootDir = $PSScriptRoot
if (-not $RootDir) {
    $RootDir = (Get-Location).Path
}

$MimeTypes = @{
    ".html"  = "text/html; charset=utf-8"
    ".htm"   = "text/html; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".js"    = "application/javascript; charset=utf-8"
    ".json"  = "application/json; charset=utf-8"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".svg"   = "image/svg+xml"
    ".ico"   = "image/x-icon"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
}

$prefix = "http://localhost:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Host "[ERROR] Failed to start server on $prefix. Port might already be in use: $_" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   EXECUTIVE PROJECT TRACKER - LOCAL SERVER" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 Server is live at: $prefix" -ForegroundColor Yellow
Write-Host "Serving directory: $RootDir" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop the server.`n" -ForegroundColor DarkGray

if ($OpenBrowser) {
    try {
        Start-Process $prefix
    } catch {}
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
    } catch {
        break
    }

    $req = $context.Request
    $res = $context.Response

    try {
        $res.Headers.Add("Access-Control-Allow-Origin", "*")

        # Handle CORS preflight
        if ($req.HttpMethod -eq "OPTIONS") {
            $res.StatusCode = 204
            $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
            $res.Close()
            continue
        }

        $rawPath = $req.Url.AbsolutePath

        # Handle POST /api/upload
        if ($req.HttpMethod -eq "POST" -and $rawPath -eq "/api/upload") {
            $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $json = ConvertFrom-Json $body

            $docType = $json.type
            $fileName = $json.fileName
            $content = $json.content

            if (-not $fileName -or -not $content) {
                $res.StatusCode = 400
                $res.ContentType = "application/json"
                $errBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Missing fileName or content"}')
                $res.ContentLength64 = $errBytes.Length
                $res.OutputStream.Write($errBytes, 0, $errBytes.Length)
                $res.Close()
                continue
            }

            $targetFolder = if ($docType -eq "scope") { "scope document" } else { "Incubator Weekly update" }
            $targetDir = Join-Path $RootDir $targetFolder
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            $cleanFileName = [regex]::Replace($fileName, '[^a-zA-Z0-9_\-\.]', '_')
            $savePath = Join-Path $targetDir $cleanFileName

            $finalContent = $content
            if ($cleanFileName.ToLower().EndsWith(".html") -and -not $finalContent.Contains("exporter.js")) {
                $scripts = @"

  <!-- Project Tracker Exporter & High-Resolution JPG Engine -->
  <script src="../assets/js/html2canvas.min.js"></script>
  <script src="../assets/js/exporter.js"></script>
</body>
"@
                $finalContent = $finalContent -replace '</body>', $scripts
            }

            [System.IO.File]::WriteAllText($savePath, $finalContent, [System.Text.Encoding]::UTF8)
            $relativeUrl = "$targetFolder/$cleanFileName"
            Write-Host "[Upload] Saved $docType document: $relativeUrl" -ForegroundColor Green

            $resObj = @{
                success = $true
                fileName = $cleanFileName
                url = $relativeUrl
            }
            $jsonResp = ConvertTo-Json $resObj
            $respBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonResp)
            $res.StatusCode = 200
            $res.ContentType = "application/json"
            $res.ContentLength64 = $respBytes.Length
            $res.OutputStream.Write($respBytes, 0, $respBytes.Length)
            $res.Close()
            continue
        }

        # Serve static files
        $decodedPath = [System.Uri]::UnescapeDataString($rawPath)
        if ($decodedPath -eq "/" -or [string]::IsNullOrWhiteSpace($decodedPath)) {
            $decodedPath = "/index.html"
        }

        $relativePath = $decodedPath.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        $filePath = Join-Path $RootDir $relativePath

        if (-not (Test-Path $filePath -PathType Leaf)) {
            if (Test-Path ($filePath + ".html") -PathType Leaf) {
                $filePath = $filePath + ".html"
            } elseif (Test-Path $filePath -PathType Container) {
                $indexInFolder = Join-Path $filePath "index.html"
                if (Test-Path $indexInFolder -PathType Leaf) {
                    $filePath = $indexInFolder
                }
            }
        }

        # Security verification
        $fullFilePath = [System.IO.Path]::GetFullPath($filePath)
        $baseDir = [System.IO.Path]::GetFullPath($RootDir)
        if (-not $fullFilePath.StartsWith($baseDir, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $fullFilePath -PathType Leaf)) {
            $res.StatusCode = 404
            $res.ContentType = "text/html; charset=utf-8"
            $notFoundHtml = @"
<!DOCTYPE html><html><head><title>404 Not Found</title></head>
<body style="font-family:sans-serif;padding:40px;text-align:center;">
<h1>404 Not Found</h1>
<p>The requested document <code>$decodedPath</code> could not be found.</p>
<p><a href="/" style="color:#2563eb;font-weight:bold;">← Return to Project Tracker Dashboard</a></p>
</body></html>
"@
            $nfBytes = [System.Text.Encoding]::UTF8.GetBytes($notFoundHtml)
            $res.ContentLength64 = $nfBytes.Length
            $res.OutputStream.Write($nfBytes, 0, $nfBytes.Length)
            $res.Close()
            continue
        }

        $ext = [System.IO.Path]::GetExtension($fullFilePath).ToLower()
        $mime = if ($MimeTypes.ContainsKey($ext)) { $MimeTypes[$ext] } else { "application/octet-stream" }

        $bytes = [System.IO.File]::ReadAllBytes($fullFilePath)
        $res.StatusCode = 200
        $res.ContentType = $mime
        $res.Headers.Add("Cache-Control", "no-cache")
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
        $res.Close()
    } catch {
        try {
            $res.StatusCode = 500
            $res.Close()
        } catch {}
    }
}
