$ErrorActionPreference = 'Stop'

# Run from the repo root regardless of where the script is invoked from.
Set-Location (Join-Path $PSScriptRoot '..')

$envFile = '.env'
$tplFile = '.env.template'

if (-not (Test-Path $envFile)) {
  Copy-Item $tplFile $envFile
  Write-Host "[bootstrap] created $envFile from $tplFile"
}

# Write with LF only. Docker Compose ingests trailing CRs into values otherwise,
# so e.g. MPS_COMMON_NAME would carry a `\r` and corrupt the interpolated URLs.
function Write-Lf($lines) {
  [IO.File]::WriteAllText((Resolve-Path $envFile), (($lines -join "`n") + "`n"))
}

# Normalize once up front in case the file was checked out with CRLF (autocrlf).
Write-Lf (Get-Content $envFile)

function Get-Kv($key) {
  foreach ($line in Get-Content $envFile) {
    if ($line -match "^$key=(.*)$") { return $Matches[1] }
  }
  return $null
}

function Set-Kv($key, $value) {
  Write-Lf ((Get-Content $envFile) | ForEach-Object {
    if ($_ -match "^$key=") { "$key=$value" } else { $_ }
  })
}

# Append a key (blank) if it is absent — an older .env predating new keys won't
# have them, and the generation loop below only fills keys that already exist.
function Set-MissingKv($key) {
  if ($null -eq (Get-Kv $key)) {
    Write-Lf ((Get-Content $envFile) + "$key=")
  }
}

function New-RandomHex {
  param([int]$ByteCount = 24)
  $bytes = New-Object byte[] $ByteCount
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Get-LanIp {
  $r = Find-NetRoute -RemoteIPAddress 1.1.1.1 -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($r) { return $r.IPAddress }
  return $null
}

$current = Get-Kv 'MPS_COMMON_NAME'
if ([string]::IsNullOrEmpty($current) -or $current -eq 'localhost') {
  $ip = Get-LanIp
  if ($ip) {
    Set-Kv 'MPS_COMMON_NAME' $ip
    Write-Host "[bootstrap] MPS_COMMON_NAME=$ip (auto-detected)"
  } else {
    Write-Host "[bootstrap] could not auto-detect IP; set MPS_COMMON_NAME manually in $envFile"
  }
}

@('APP_ENCRYPTION_KEY','AUTH_JWT_KEY','AUTH_ADMIN_PASSWORD','KEYCLOAK_ADMIN_PASSWORD','CONSOLE_USER_PASSWORD','POSTGRES_PASSWORD','VAULT_TOKEN') | ForEach-Object {
  Set-MissingKv $_
  if ((Get-Kv $_) -eq '') {
    # APP_ENCRYPTION_KEY must be exactly 32 chars — go-wsman-messages casts it to
    # []byte for aes.NewCipher (AES-256 wants a 32-byte key). 16 bytes = 32 hex chars.
    $hex = if ($_ -eq 'APP_ENCRYPTION_KEY') { New-RandomHex 16 } else { New-RandomHex }
    Set-Kv $_ $hex
    Write-Host "[bootstrap] generated $_"
  }
}
