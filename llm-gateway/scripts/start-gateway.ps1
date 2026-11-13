$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
            if ($Matches[2].Trim()) {
                Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2].Trim().Trim('"')
            }
        }
    }
}
if (-not $env:LITELLM_MASTER_KEY) {
    Write-Error "LITELLM_MASTER_KEY is not set. Copy .env.example to .env and fill it in."
    exit 1
}
$litellm = Join-Path $root ".venv\Scripts\litellm.exe"
& $litellm --config (Join-Path $root "litellm\config.yaml") --host 127.0.0.1 --port 4000
