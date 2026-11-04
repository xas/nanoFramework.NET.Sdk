[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Builds SmokeTest against the SDK packed from this checkout, never a published one.
# The SDK is packed with the fixed dev version pinned in global.json into
# artifacts/smoketest (the local-sdk source of NuGet.Config), and the copy NuGet
# cached from a previous run is removed so the fresh package is always used.

function Invoke-DotNet {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Get-GlobalPackagesFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = & dotnet nuget locals global-packages --list
    }
    finally {
        Pop-Location
    }

    $match = [regex]::Match(($output -join "`n"), 'global-packages:\s*(.+)')
    if (-not $match.Success) {
        throw "Unable to locate the NuGet global packages folder: $output"
    }

    return $match.Groups[1].Value.Trim()
}

$smokeTestDirectory = $PSScriptRoot
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $smokeTestDirectory '../..')).Path
$sdkProject = Join-Path $repositoryRoot 'nanoFramework.NET.Sdk/nanoFramework.NET.Sdk.csproj'
$smokeProject = Join-Path $smokeTestDirectory 'SmokeTest.csproj'
$feedDirectory = Join-Path $repositoryRoot 'artifacts/smoketest'

$globalJson = Get-Content -Raw -LiteralPath (Join-Path $smokeTestDirectory 'global.json') | ConvertFrom-Json
$sdkVersion = $globalJson.'msbuild-sdks'.'nanoFramework.NET.Sdk'
if ([string]::IsNullOrWhiteSpace($sdkVersion)) {
    throw 'global.json does not pin a nanoFramework.NET.Sdk version.'
}

Write-Host "Packing nanoFramework.NET.Sdk $sdkVersion into $feedDirectory"
if (Test-Path -LiteralPath $feedDirectory) {
    Remove-Item -LiteralPath $feedDirectory -Recurse -Force
}
Invoke-DotNet @('build', $sdkProject, '-c', 'Release', "-p:NanoSdkPackageVersion=$sdkVersion", "-p:PackageOutputPath=$feedDirectory/", '/nologo', '/v:minimal')

$cachedSdk = Join-Path (Get-GlobalPackagesFolder -WorkingDirectory $smokeTestDirectory) "nanoframework.net.sdk/$($sdkVersion.ToLowerInvariant())"
if (Test-Path -LiteralPath $cachedSdk) {
    Write-Host "Removing cached SDK $cachedSdk"
    Remove-Item -LiteralPath $cachedSdk -Recurse -Force
}

# No node reuse, so no MSBuild node keeps the cached task DLLs locked for the next run.
Write-Host "Building SmokeTest ($Configuration)"
Invoke-DotNet @('build', $smokeProject, '-c', $Configuration, '--no-incremental', '-nodeReuse:false', '/nologo', '/v:minimal')

Write-Host "SmokeTest built with nanoFramework.NET.Sdk $sdkVersion from this checkout."
