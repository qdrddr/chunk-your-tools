# Back-compat wrapper - prefer ./scripts/pre-commit-hooks/psscriptanalyzer-docker.ps1
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'pre-commit-hooks/psscriptanalyzer-docker.ps1') @args
exit $LASTEXITCODE
