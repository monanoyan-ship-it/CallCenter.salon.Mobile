#requires -Version 5.1
<#
  Mobil release build sarmalayicisi — env (dev/staging/prod) bazli dart-define seti.

  Ornek:
    .\scripts\build.ps1 -Target web      -Env staging
    .\scripts\build.ps1 -Target apk      -Env prod
    .\scripts\build.ps1 -Target appbundle -Env prod
    .\scripts\build.ps1 -Target ios      -Env prod   # macOS gerekir

  Override:
    .\scripts\build.ps1 -Target web -Env prod -ApiUrl https://api.corplynk.com -MapTileUrl 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=XXX'
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('web', 'apk', 'appbundle', 'ios', 'macos', 'windows')]
    [string] $Target,

    [ValidateSet('dev', 'staging', 'prod')]
    [string] $Env = 'dev',

    [string] $ApiUrl,
    [string] $MapTileUrl,
    [string] $MapTileAttribution,
    [bool]   $AllowBadSsl
)

$ErrorActionPreference = 'Stop'

# Env varsayilanlari — proje ozel
$defaults = @{
    dev = @{
        ApiUrl              = 'http://localhost:5041'
        MapTileUrl          = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
        MapTileAttribution  = '© OpenStreetMap'
        AllowBadSsl         = $true
    }
    staging = @{
        ApiUrl              = 'https://staging-api.corplynk.com'
        MapTileUrl          = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
        MapTileAttribution  = '© OpenStreetMap'
        AllowBadSsl         = $false
    }
    prod = @{
        ApiUrl              = 'https://api.corplynk.com'
        MapTileUrl          = ''   # ZORUNLU: prod-da OSM kullanilmamali; mapbox/maptiler/carto key girin
        MapTileAttribution  = ''
        AllowBadSsl         = $false
    }
}

$cfg = $defaults[$Env]

if ($ApiUrl)             { $cfg.ApiUrl = $ApiUrl }
if ($MapTileUrl)         { $cfg.MapTileUrl = $MapTileUrl }
if ($MapTileAttribution) { $cfg.MapTileAttribution = $MapTileAttribution }
if ($PSBoundParameters.ContainsKey('AllowBadSsl')) { $cfg.AllowBadSsl = $AllowBadSsl }

if ($Env -eq 'prod' -and [string]::IsNullOrWhiteSpace($cfg.MapTileUrl)) {
    throw "Prod build icin MapTileUrl zorunlu. -MapTileUrl ile gecin (Mapbox/MapTiler/Stadia/Carto key dahil). OSM Foundation public tile-lari magaza yayini icin yasak."
}

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    throw "flutter PATH-te yok. Flutter SDK kurun ve PATH ekleyin."
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $RepoRoot

# dart-define seti
$defines = @(
    "--dart-define=API_BASE_URL=$($cfg.ApiUrl)",
    "--dart-define=ALLOW_BAD_SSL=$($cfg.AllowBadSsl.ToString().ToLower())"
)
if ($cfg.MapTileUrl)         { $defines += "--dart-define=MAP_TILE_URL=$($cfg.MapTileUrl)" }
if ($cfg.MapTileAttribution) { $defines += "--dart-define=MAP_TILE_ATTRIBUTION=$($cfg.MapTileAttribution)" }

Write-Host "[build] target=$Target env=$Env"
foreach ($d in $defines) { Write-Host "         $d" }

# Build komutu
$cmd = @('build', $Target) + $defines

# Web icin --release default; mobil icin de ayni.
if ($Target -in @('apk', 'appbundle', 'ios')) {
    $cmd += '--release'
}

& flutter @cmd
