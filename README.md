# nanoFramework.NET.Sdk

[![NuGet](https://img.shields.io/nuget/vpre/nanoFramework.NET.Sdk.svg?label=NuGet)](https://www.nuget.org/packages/nanoFramework.NET.Sdk)

MSBuild SDK package for .NET nanoFramework projects. Enables building nanoFramework class libraries and applications using `dotnet build` and standard SDK-style project files, on Windows, macOS and Linux, without Visual Studio or Mono.

## Overview

This SDK replaces the legacy MSBuild infrastructure previously bundled inside the Visual Studio extension (VSIX). It packages the nanoFramework build pipeline — C# compilation, metadata processing (IL→PE), resource generation, and binary output — into a standard NuGet-distributed MSBuild SDK.

It is an [MSBuild project SDK](https://learn.microsoft.com/visualstudio/msbuild/how-to-use-project-sdk), not a workload: there is nothing to install. `dotnet build` downloads the package from NuGet the first time a project references it.

## Versions

| SDK version | Requires | Notes |
|---|---|---|
| `1.1.x` (latest) | .NET 10 SDK | Build tasks on .NET 10; bitmap resources via SkiaSharp |
| `1.0.x` | .NET 8 SDK or later | Build tasks on .NET 8; bitmap resources via ImageSharp |

The latest published version is shown on the badge above and on [nuget.org](https://www.nuget.org/packages/nanoFramework.NET.Sdk). In the examples below, replace `<version>` with it.

The `dotnet` build tasks ship native SkiaSharp libraries for `win-x64`, `win-x86`, `win-arm64`, `osx`, `linux-x64`, `linux-arm64`, `linux-arm`, `linux-musl-x64` and `linux-musl-arm64` (Alpine).

## Usage

Create an SDK-style project file (`.csproj`):

```xml
<Project Sdk="nanoFramework.NET.Sdk/<version>">

  <PropertyGroup>
    <OutputType>Library</OutputType>
    <RootNamespace>MyLibrary</RootNamespace>
    <AssemblyName>MyLibrary</AssemblyName>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="nanoFramework.CoreLibrary" Version="2.0.0-preview.52" />
  </ItemGroup>

</Project>
```

Or keep `<Project Sdk="nanoFramework.NET.Sdk">` without a version and pin it once for the whole repository in a `global.json` next to the solution:

```json
{
  "msbuild-sdks": {
    "nanoFramework.NET.Sdk": "<version>"
  }
}
```

Build with the `dotnet` CLI:

```bash
dotnet build
```

The nanoFramework output (`.pe`, `.pdbx`, and `.bin` for applications) lands in `bin/<Configuration>/netnano1.0/`.

## Test with the NuGet package

1. Install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and check it with `dotnet --version`.
2. Create the project file above, with the latest version from nuget.org.
3. Add a source file, for example `Class1.cs`:

   ```csharp
   namespace MyLibrary
   {
       public class Class1
       {
           public int Answer() => 42;
       }
   }
   ```

4. Run `dotnet build` and check that `bin/Debug/netnano1.0/MyLibrary.pe` exists.

NuGet caches the SDK in `~/.nuget/packages/nanoframework.net.sdk/<version>/`. A published version never changes, so the cache is safe to keep.

## Test a local build of this repository

### Smoke test (from this repository)

`test/SmokeTest` always builds against the SDK packed from your checkout, never against a published one:

```bash
pwsh test/SmokeTest/Run-SmokeTest.ps1 -Configuration Debug
```

The script packs the SDK with the fixed dev version pinned in `test/SmokeTest/global.json` (`1.1.0-dev`) into `artifacts/smoketest`, removes the NuGet-cached copy of that version, and builds the project. A plain `dotnet build` of `test/SmokeTest` fails until the script has run, because its `NuGet.Config` only takes `nanoFramework.NET.Sdk` from the local feed.

### Your own project against a local build

1. Pack the SDK from this repository with a fixed dev version:

   ```bash
   dotnet build nanoFramework.NET.Sdk/nanoFramework.NET.Sdk.csproj -c Release -p:NanoSdkPackageVersion=1.1.0-dev -p:PackageOutputPath=<repo>/artifacts/local/
   ```

   `NanoSdkPackageVersion` overrides the Git-based version, so your project does not have to follow each commit.

2. Next to your project or solution, add a `NuGet.Config` that takes the SDK only from that folder:

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <configuration>
     <packageSources>
       <add key="nano-sdk-local" value="<repo>/artifacts/local" />
       <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
     </packageSources>
     <packageSourceMapping>
       <packageSource key="nano-sdk-local">
         <package pattern="nanoFramework.NET.Sdk" />
       </packageSource>
       <packageSource key="nuget.org">
         <package pattern="*" />
       </packageSource>
     </packageSourceMapping>
   </configuration>
   ```

3. Pin the dev version in your `global.json`:

   ```json
   {
     "msbuild-sdks": {
       "nanoFramework.NET.Sdk": "1.1.0-dev"
     }
   }
   ```

4. Before each build of a new pack, remove the cached copy, because NuGet never refreshes a version it already has:

   ```bash
   rm -rf ~/.nuget/packages/nanoframework.net.sdk/1.1.0-dev
   ```

   On Windows (PowerShell):

   ```powershell
   Remove-Item -Recurse -Force "$env:USERPROFILE\.nuget\packages\nanoframework.net.sdk\1.1.0-dev"
   ```

5. Run `dotnet build`.

## Known limitations

- Application projects (`<OutputType>Exe</OutputType>`) fail on Linux and macOS with `MSB3096: Task "GenerateApplicationManifest" is only supported when building on Windows`. Workaround: add `<GenerateManifests>false</GenerateManifests>` to the project.

## Project structure

```
nanoFramework.NET.Sdk/            SDK NuGet package (Sdk.props / Sdk.targets and focused modules)
nanoFramework.Tools.BuildTasks/   Custom MSBuild tasks (resource generation, binary output, etc.)
test/BuildTasks.Tests/            Unit and integration tests for the build tasks
test/SmokeTest/                   Sample nanoFramework project built with the packed SDK
```

## Tools

The `dotnet nano` umbrella CLI and the `nano-migrate` project migrator (with the companion
SDK-migration skill) live in the [nanoframework/nf-tools](https://github.com/nanoframework/nf-tools)
repository, under `tools/nano` and `tools/migrate`.

## Development

```bash
dotnet build nanoFramework.NET.Sdk.sln -c Release
dotnet test test/BuildTasks.Tests/BuildTasks.Tests.csproj
```

`dotnet test` runs the `net10.0` tests everywhere, and also the `net472` tests on Windows. Building the solution also packs the SDK into `nanoFramework.NET.Sdk/bin/<Configuration>/`.

## License

See LICENSE file for details.
