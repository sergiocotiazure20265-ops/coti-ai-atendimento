[CmdletBinding()]
param(
    [ValidateSet('Check', 'Seed', 'Verify')]
    [string]$PersistenceMode = 'Check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location
$previousEncoding = $OutputEncoding
$OutputEncoding = New-Object Text.UTF8Encoding($false)
$markerFile = Join-Path $projectRoot 'artifacts/infra/persistence-marker.txt'

function Invoke-DockerCommand {
    param([string[]]$DockerArguments, [string]$InputText)
    $savedPreference = $ErrorActionPreference
    try {
        # Capture native diagnostics; never echo raw errors that might contain configuration.
        $ErrorActionPreference = 'Continue'
        if ($PSBoundParameters.ContainsKey('InputText')) {
            $captured = @($InputText | & docker @DockerArguments 2>&1)
        } else {
            $captured = @(& docker @DockerArguments 2>&1)
        }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    return [pscustomobject]@{ Code = $code; Text = (($captured | ForEach-Object { $_.ToString() }) -join "`n").Trim() }
}

function Get-DockerValue {
    param([string[]]$DockerArguments)
    $result = Invoke-DockerCommand -DockerArguments $DockerArguments
    if ($result.Code -ne 0) { throw 'Falha ao consultar Docker. Confira engine, contexto e permissoes; nenhum detalhe sensivel foi exibido.' }
    return $result.Text
}

function Invoke-Database {
    param([ValidateSet('Bootstrap', 'Migration', 'Runtime', 'WrongPassword')][string]$Role, [string]$Sql, [switch]$ExpectDenied)
    $command = switch ($Role) {
        'Bootstrap' { 'PGPASSWORD=$POSTGRES_PASSWORD; export PGPASSWORD; exec psql -X -qAt --no-password -h 127.0.0.1 -U coti_bootstrap -d coti_conhecimento -v ON_ERROR_STOP=1' }
        'Migration' { 'PGPASSWORD=$DB_MIGRATION_PASSWORD; export PGPASSWORD; exec psql -X -qAt --no-password -h 127.0.0.1 -U coti_migrator -d coti_conhecimento -v ON_ERROR_STOP=1' }
        'Runtime' { 'PGPASSWORD=$DB_PASSWORD; export PGPASSWORD; exec psql -X -qAt --no-password -h 127.0.0.1 -U coti_runtime -d coti_conhecimento -v ON_ERROR_STOP=1' }
        'WrongPassword' { 'PGPASSWORD=coti-intentionally-invalid-password; export PGPASSWORD; exec psql -X -qAt --no-password -h 127.0.0.1 -U coti_runtime -d coti_conhecimento -v ON_ERROR_STOP=1' }
    }
    $result = Invoke-DockerCommand -DockerArguments @('compose', 'exec', '-T', 'postgres', 'sh', '-c', $command) -InputText $Sql
    if ($ExpectDenied) {
        if ($result.Code -eq 0 -or $result.Text -notmatch '42501') { throw 'DDL nao foi negado por privilegio (SQLSTATE 42501) como esperado.' }
        return
    }
    if ($Role -eq 'WrongPassword') {
        if ($result.Code -eq 0 -or $result.Text -notmatch 'password authentication failed') { throw 'Senha incorreta nao foi rejeitada como esperado.' }
        return
    }
    if ($result.Code -ne 0) { throw ('Verificacao SQL falhou para a role ' + $Role + '. Diagnostico bruto suprimido para proteger credenciais.') }
    return $result.Text
}

function Assert-Value {
    param([string]$Actual, [string]$Expected, [string]$Label)
    if ($Actual -ne $Expected) { throw ('Verificacao reprovada: ' + $Label + '.') }
    Write-Output ('OK: ' + $Label)
}

try {
    Set-Location -LiteralPath $projectRoot
    Assert-Value (Get-DockerValue @('info', '--format', '{{.OSType}}')) 'linux' 'engine Linux'
    $config = Invoke-DockerCommand -DockerArguments @('compose', 'config', '--quiet')
    if ($config.Code -ne 0) { throw 'Compose invalido ou variaveis obrigatorias ausentes (valores nao exibidos).' }
    $containerId = Get-DockerValue @('compose', 'ps', '-q', 'postgres')
    if ([string]::IsNullOrWhiteSpace($containerId)) { throw 'Servico postgres nao esta em execucao.' }
    Assert-Value (Get-DockerValue @('inspect', '--format', '{{.State.Health.Status}}', $containerId)) 'healthy' 'healthcheck do PostgreSQL'
    $ports = Get-DockerValue @('inspect', '--format', '{{json .NetworkSettings.Ports}}', $containerId) | ConvertFrom-Json
    $binding = @($ports.'5432/tcp')
    if ($binding.Count -ne 1) { throw 'Numero de portas publicadas inesperado.' }
    Assert-Value $binding[0].HostIp '127.0.0.1' 'bind somente loopback'
    Assert-Value $binding[0].HostPort '5434' 'porta local 5434'
    $networks = Get-DockerValue @('inspect', '--format', '{{json .NetworkSettings.Networks}}', $containerId) | ConvertFrom-Json
    $networkNames = @($networks.PSObject.Properties.Name)
    if ($networkNames.Count -ne 2 -or 'coti-ai-atendimento_dados' -notin $networkNames -or 'coti-ai-atendimento_operacao_local' -notin $networkNames) { throw 'Redes do banco devem ser somente dados e operacao_local; servicos nao e permitida.' }
    Assert-Value (Get-DockerValue @('network', 'inspect', '--format', '{{.Internal}}', 'coti-ai-atendimento_dados')) 'true' 'rede de dados interna'
    Assert-Value (Get-DockerValue @('network', 'inspect', '--format', '{{index .Options "com.docker.network.bridge.enable_ip_masquerade"}}', 'coti-ai-atendimento_operacao_local')) 'false' 'masquerade de saida desabilitado na operacao local'
    $tcpClient = New-Object Net.Sockets.TcpClient
    try {
        $connection = $tcpClient.ConnectAsync('127.0.0.1', 5434)
        if (-not $connection.Wait(3000) -or -not $tcpClient.Connected) { throw 'Porta 5434 declarada, mas inacessivel no host.' }
    } finally { $tcpClient.Dispose() }
    Write-Output 'OK: conexao TCP real ao host 127.0.0.1:5434'
    $mounts = @(Get-DockerValue @('inspect', '--format', '{{json .Mounts}}', $containerId) | ConvertFrom-Json)
    $dataMount = @($mounts | Where-Object { $_.Destination -eq '/var/lib/postgresql/data' })
    if ($dataMount.Count -ne 1 -or $dataMount[0].Type -ne 'volume' -or $dataMount[0].Name -ne 'coti-ai-atendimento_postgres_data') { throw 'Volume persistente do projeto nao encontrado.' }
    $bootstrapMount = @($mounts | Where-Object { $_.Destination -eq '/docker-entrypoint-initdb.d' })
    if ($bootstrapMount.Count -ne 1 -or $bootstrapMount[0].RW) { throw 'Bootstrap deve estar montado somente leitura.' }
    Write-Output 'OK: volume nomeado e bootstrap somente leitura'

    Assert-Value (Invoke-Database Bootstrap "SELECT current_setting('server_version_num')::int / 10000;") '16' 'PostgreSQL major 16'
    Assert-Value (Invoke-Database Runtime "SELECT extversion FROM pg_extension WHERE extname='vector';") '0.8.2' 'pgvector 0.8.2 acessivel ao runtime'
    Assert-Value (Invoke-Database Runtime "SELECT count(*) FROM pg_extension WHERE extname IN ('hstore','uuid-ossp');") '2' 'extensoes hstore e uuid-ossp'
    Assert-Value (Invoke-Database Bootstrap "SELECT count(*) FROM pg_hba_file_rules WHERE auth_method IS NOT NULL AND auth_method <> 'scram-sha-256';") '0' 'autenticacao SCRAM sem trust'
    Assert-Value (Invoke-Database Runtime "SELECT current_user;") 'coti_runtime' 'login TCP runtime'
    Assert-Value (Invoke-Database Migration "SELECT current_user;") 'coti_migrator' 'login TCP migrator'
    Assert-Value (Invoke-Database Runtime "SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user;") 'f' 'runtime sem privilegios administrativos'
    Assert-Value (Invoke-Database Migration "SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user;") 'f' 'migrator sem superusuario/criacao de roles'
    Assert-Value (Invoke-Database Runtime "SELECT has_database_privilege(current_user,current_database(),'CREATE') OR has_schema_privilege(current_user,'public','CREATE') OR has_schema_privilege(current_user,'conhecimento','CREATE') OR pg_has_role(current_user,'coti_migrator','MEMBER');") 'f' 'runtime sem DDL ou heranca de migrator'
    Invoke-Database WrongPassword 'SELECT 1;'
    Write-Output 'OK: senha incorreta rejeitada'
    Invoke-Database Runtime "\set VERBOSITY sqlstate`nBEGIN; CREATE TABLE conhecimento.coti_forbidden_probe(id integer); ROLLBACK;" -ExpectDenied
    Write-Output 'OK: CREATE TABLE runtime negado com SQLSTATE 42501'

    if ($PersistenceMode -eq 'Seed') {
        $token = [guid]::NewGuid().ToString()
        # The migrator owns its schemas but intentionally cannot create arbitrary
        # schemas in the database. Only bootstrap establishes this technical one.
        $null = Invoke-Database Bootstrap 'CREATE SCHEMA IF NOT EXISTS infra_validation AUTHORIZATION coti_migrator;'
        $null = Invoke-Database Migration @"
CREATE TABLE IF NOT EXISTS infra_validation.persistence_marker(id integer PRIMARY KEY CHECK(id=1), token uuid NOT NULL);
INSERT INTO infra_validation.persistence_marker VALUES(1,'$token') ON CONFLICT(id) DO NOTHING;
GRANT USAGE ON SCHEMA infra_validation TO coti_runtime;
GRANT SELECT,INSERT,UPDATE,DELETE ON infra_validation.persistence_marker TO coti_runtime;
"@
        $storedToken = Invoke-Database Runtime 'SELECT token FROM infra_validation.persistence_marker WHERE id=1;'
        $null = [guid]::Parse($storedToken)
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $markerFile) -Force
        [IO.File]::WriteAllText($markerFile, $storedToken, (New-Object Text.UTF8Encoding($false)))
        Write-Output 'OK: marcador tecnico persistido; referencia privada em artifacts/infra/'
    }
    if ($PersistenceMode -in @('Seed','Verify')) {
        if (-not (Test-Path -LiteralPath $markerFile)) { throw 'Referencia do marcador ausente. Execute primeiro -PersistenceMode Seed.' }
        $expectedToken = [IO.File]::ReadAllText($markerFile).Trim()
        $null = [guid]::Parse($expectedToken)
        Assert-Value (Invoke-Database Runtime 'SELECT token FROM infra_validation.persistence_marker WHERE id=1;') $expectedToken 'marcador preservado no volume'
        $null = Invoke-Database Runtime "BEGIN; DELETE FROM infra_validation.persistence_marker WHERE id=1; INSERT INTO infra_validation.persistence_marker VALUES(1,'$expectedToken'); UPDATE infra_validation.persistence_marker SET token=token WHERE id=1; ROLLBACK;"
        Write-Output 'OK: DML runtime funciona; alteracoes de prova revertidas'
    }
    $version = Invoke-Database Bootstrap 'SHOW server_version;'
    $digest = Get-DockerValue @('image', 'inspect', 'pgvector/pgvector:0.8.2-pg16-bookworm', '--format', '{{index .RepoDigests 0}}')
    Write-Output ('PostgreSQL efetivo: ' + $version)
    Write-Output ('Imagem efetiva: ' + $digest)
    Write-Output ('VALIDACAO APROVADA (' + $PersistenceMode + '). Nenhum volume removido.')
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
} finally {
    $OutputEncoding = $previousEncoding
    Set-Location $previousLocation
}
