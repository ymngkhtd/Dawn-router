[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^(sha-[0-9a-f]{40}|v[0-9A-Za-z._-]+)$')]
  [string]$ImageTag,

  [Parameter(Mandatory = $true)]
  [string]$Server,

  [string]$DeployPath = '/opt/dawn-router',

  [ValidateRange(1, 65535)]
  [int]$SshPort = 22,

  [string]$SshKey = (Join-Path $HOME '.ssh\dawn-router-deploy'),

  [switch]$SkipUpload
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SshKey -PathType Leaf)) {
  throw "SSH private key was not found: $SshKey"
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $repositoryRoot 'docker-compose.prod.yml'
$deployScript = Join-Path $PSScriptRoot 'production-deploy.sh'

if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) {
  throw "Production Compose file was not found: $composeFile"
}
if (-not (Test-Path -LiteralPath $deployScript -PathType Leaf)) {
  throw "Production deploy script was not found: $deployScript"
}

$sshArguments = @(
  '-i', $SshKey,
  '-p', $SshPort,
  '-o', 'BatchMode=yes',
  '-o', 'StrictHostKeyChecking=yes'
)
$scpArguments = @(
  '-i', $SshKey,
  '-P', $SshPort,
  '-o', 'BatchMode=yes',
  '-o', 'StrictHostKeyChecking=yes'
)
$remoteRoot = '{0}:{1}' -f $Server, $DeployPath
$remoteDeployDirectory = '{0}:{1}/deploy/' -f $Server, $DeployPath

& ssh @sshArguments $Server "test -f '$DeployPath/.env' && test -f '$DeployPath/deploy/app.env'"
if ($LASTEXITCODE -ne 0) {
  throw "Production environment files were not found on the server."
}

if (-not $SkipUpload) {
  & scp @scpArguments $composeFile $remoteRoot
  if ($LASTEXITCODE -ne 0) {
    throw 'Uploading docker-compose.prod.yml failed.'
  }

  & scp @scpArguments $deployScript $remoteDeployDirectory
  if ($LASTEXITCODE -ne 0) {
    throw 'Uploading production-deploy.sh failed.'
  }
}

$remoteCommand = "cd '$DeployPath' && chmod 700 deploy/production-deploy.sh && IMAGE_TAG='$ImageTag' IMAGE_REPOSITORY='ghcr.io/ymngkhtd/dawn-router' ./deploy/production-deploy.sh"
& ssh @sshArguments $Server $remoteCommand
if ($LASTEXITCODE -ne 0) {
  throw "Remote deployment failed for image tag: $ImageTag"
}

Write-Host "Deployment completed: ghcr.io/ymngkhtd/dawn-router:$ImageTag"
