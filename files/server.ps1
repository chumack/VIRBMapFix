# VIRBMapFix - local HTTP server for static.garmincdn.com (no Python needed)
# Serves Leaflet replacement from .\www, proxies the rest to real CDN.
param(
    [string]$Root = (Join-Path $PSScriptRoot 'www'),
    [int]$Port = 80,
    [string]$RealHost = 'static.garmincdn.com',
    [string]$RealIp = '104.16.147.2'
)
$ErrorActionPreference = 'Continue'
$LogFile = Join-Path $PSScriptRoot 'server.log'

function Log([string]$msg) {
    try { Add-Content -Path $LogFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8 } catch {}
}

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.svg'  = 'image/svg+xml'
    '.json' = 'application/json'
    '.ico'  = 'image/x-icon'
}

$listener = New-Object System.Net.HttpListener
# Loopback only: enough because hosts maps the CDN name to 127.0.0.1.
# Installer adds urlacl reservations so no admin rights are needed at runtime.
# NOTE: [::1] may lack a reservation on some machines -> retry without it.
$prefixSets = @(
    @("http://127.0.0.1:$Port/", "http://localhost:$Port/", "http://[::1]:$Port/"),
    @("http://127.0.0.1:$Port/", "http://localhost:$Port/")
)
$started = $false
foreach ($set in $prefixSets) {
    $listener.Prefixes.Clear()
    foreach ($prefix in $set) { $listener.Prefixes.Add($prefix) }
    try {
        $listener.Start()
        $started = $true
        break
    } catch {
        Log("FAILED prefixes $($set -join ','): $($_.Exception.Message)")
    }
}
if (-not $started) {
    Log("FAILED to listen on port ${Port}: giving up")
    exit 1
}
Log("Serving $Root on port $Port (proxy fallback $RealIp)")

$wc = New-Object System.Net.WebClient
$wc.Headers.Add('User-Agent', 'VIRBMapFix')

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath
        $query = $req.Url.Query
        $rel = $path.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $full = Join-Path $Root $rel

        # directory -> index.html
        if ((Test-Path $full -PathType Container)) {
            $idx = Join-Path $full 'index.html'
            if (Test-Path $idx -PathType Leaf) { $full = $idx }
        }

        if ((Test-Path $full -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($full).ToLower()
            $ct = $mime[$ext]
            if (-not $ct) { $ct = 'application/octet-stream' }
            try {
                $data = [System.IO.File]::ReadAllBytes($full)
                $res.StatusCode = 200
                $res.ContentType = $ct
                $res.ContentLength64 = $data.Length
                $res.AddHeader('Access-Control-Allow-Origin', '*')
                $res.OutputStream.Write($data, 0, $data.Length)
                Log("$($req.RemoteEndPoint) LOCAL 200 $path")
            } catch {
                $res.StatusCode = 500
                Log("LOCAL 500 $path : $($_.Exception.Message)")
            }
            $res.OutputStream.Close()
            $res.Close()
            continue
        }

        # proxy to real CDN so other Garmin content keeps working
        try {
            $url = "http://${RealIp}${path}${query}"
            $wr = [System.Net.HttpWebRequest]::Create($url)
            $wr.Host = $RealHost
            $wr.UserAgent = 'VIRBMapFix'
            $wr.Timeout = 15000
            $wr.Method = 'GET'
            $resp = $wr.GetResponse()
            $rs = $resp.GetResponseStream()
            $ms = New-Object System.IO.MemoryStream
            $rs.CopyTo($ms)
            $data = $ms.ToArray()
            $res.StatusCode = 200
            if ($resp.ContentType) { $res.ContentType = $resp.ContentType }
            $res.ContentLength64 = $data.Length
            $res.OutputStream.Write($data, 0, $data.Length)
            $rs.Close(); $resp.Close()
            Log("$($req.RemoteEndPoint) PROXY 200 $path")
        } catch [System.Net.WebException] {
            $code = 502
            try { $code = [int]$_.Exception.Response.StatusCode } catch {}
            $res.StatusCode = $code
            Log("PROXY $code $path : $($_.Exception.Message)")
        } catch {
            $res.StatusCode = 502
            Log("PROXY 502 $path : $($_.Exception.Message)")
        }
        try { $res.OutputStream.Close(); $res.Close() } catch {}
    } catch {
        Log("LOOP ERROR: $($_.Exception.Message)")
    }
}
