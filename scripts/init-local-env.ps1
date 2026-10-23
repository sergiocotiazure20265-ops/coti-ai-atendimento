[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'

function New-PrivatePassword {
    $bytes = New-Object byte[] 32
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
}

if (Test-Path -LiteralPath $envPath) {
    throw 'O .env ja existe; nenhuma credencial foi substituida. Use a rotacao documentada.'
}
$lines = @(
    '# Private local credentials. Do not commit or print this file.'
    ('POSTGRES_PASSWORD=' + (New-PrivatePassword))
    ('DB_MIGRATION_PASSWORD=' + (New-PrivatePassword))
    ('DB_PASSWORD=' + (New-PrivatePassword))
)
# CreateNew protects an existing file even if another process creates it meanwhile.
$stream = [IO.File]::Open($envPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
$writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false)))
try { $writer.Write(($lines -join "`n") + "`n") } finally { $writer.Dispose() }
Write-Output '.env privado criado com tres senhas aleatorias distintas; valores nao exibidos.'
