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
$url = if ($env:LLM_GATEWAY_URL) { $env:LLM_GATEWAY_URL } else { "http://localhost:4000" }
$key = if ($env:LLM_GATEWAY_KEY) { $env:LLM_GATEWAY_KEY } else { $env:LITELLM_MASTER_KEY }
$headers = @{ Authorization = "Bearer $key" }
try {
    $live = Invoke-RestMethod -Uri "$url/health/liveliness" -TimeoutSec 5
    Write-Host "Liveness: $live"
    $models = Invoke-RestMethod -Uri "$url/v1/models" -Headers $headers -TimeoutSec 10
    Write-Host "Model groups:"
    $models.data | ForEach-Object { Write-Host "  $($_.id)" }
} catch {
    Write-Error "Gateway not reachable at $url : $($_.Exception.Message)"
    exit 1
}
