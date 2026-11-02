$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    $install = $env:MISE_TOOL_INSTALL_PATH
    $version = $env:MISE_TOOL_VERSION
    if (!$install -or !$version) { throw 'MISE_TOOL_INSTALL_PATH and MISE_TOOL_VERSION are required' }
    $env:MOON_HOME = $install
    $moon = Join-Path $install 'bin/moon.exe'
    $moonx = Join-Path $install 'bin/moonx.exe'
    if (!(Test-Path -LiteralPath $moonx)) {
        New-Item -ItemType HardLink -Path $moonx -Value $moon | Out-Null
    }
    $encodedVersion = [Uri]::EscapeDataString($version)
    $url = "https://cli.moonbitlang.com/cores/core-$encodedVersion.zip"
    $archive = Join-Path $install 'core.zip'
    Write-Output "Downloading core: $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $install 'lib') -Force
    Remove-Item -LiteralPath $archive
    Push-Location (Join-Path $install 'lib/core')
    try {
        & $moon bundle --warn-list -a --all
        if ($LASTEXITCODE -ne 0) { throw "moon bundle --all failed: $LASTEXITCODE" }
        & $moon bundle --warn-list -a --target wasm-gc --quiet
        if ($LASTEXITCODE -ne 0) { throw "moon bundle --target wasm-gc failed: $LASTEXITCODE" }
    } finally { Pop-Location }
    & $moon update
    if ($LASTEXITCODE -ne 0) { throw "moon update failed: $LASTEXITCODE" }
} catch {
    Write-Error "MoonBit completion failed: $_" -ErrorAction Continue
    exit 1
}
