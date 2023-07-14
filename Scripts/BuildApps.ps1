[CmdletBinding()]
param (
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'


Import-Module -Name BcContainerHelper -DisableNameChecking -Force


Write-Information -MessageData 'Main app folders:'
$AppFolders = @($env:AppFolders | ConvertFrom-Json -NoEnumerate)
Write-Information -MessageData ($AppFolders | ConvertTo-Json)

Write-Information -MessageData 'Test app folders:'
$TestAppFolders = @($env:TestFolders | ConvertFrom-Json -NoEnumerate)
Write-Information -MessageData  ($TestAppFolders | ConvertTo-Json)


Write-Information -MessageData ''
Write-Information -MessageData "BC version given $env:BcVersion"
$Pattern = -join @(
    '^(?<Type>OnPrem|Sandbox)\/'
    '(?<Version>Current|NextMinor|NextMajor|\d+(?:\.\d+){0,3})\/'
    '(?<Country>base|w1|[a-zA-Z]{2})$'
)
if ($env:BcVersion -cnotmatch $Pattern) {
    Write-Information -MessageData (
        -join @(
            '#vso[task.logissue type=error;]'
            'BC version expected pattern '''
            '<OnPrem|Sandbox>/'
            '<Current|NextMinor|NextMajor|Numeric version, eg 16.3>/'
            '<base or w1 or country>'
            ''' (case sensitive).'
        )
    )
    Write-Information 'BC version does not match pattern. '
    exit(1)
}
Write-Information -MessageData ''
Write-Information -MessageData "Parsed artifact type:    $($Matches.Type)"
Write-Information -MessageData "Parsed artifact version: $($Matches.Version)"
Write-Information -MessageData "Parsed artifact country: $($Matches.Country)"

$GetBcArtifactUrlParameters = @{
    Type = $Matches.Type
    Select = 'Latest'
    Version = $Matches.Version -replace 'Current|NextMinor|NextMajor', ''
    Country = $Matches.Country
}
switch ($Matches.Version) {
    'Current' {
        $GetBcArtifactUrlParameters.Select = 'Current'
        break
    }
    { $_ -in @('NextMinor', 'NextMajor') } {
        $GetBcArtifactUrlParameters.SasToken = $env:BcInsiderSasToken
        $GetBcArtifactUrlParameters.Select = $Matches.Version
        break
    }
}

Write-Information -MessageData ''
Write-Information -MessageData ($GetBcArtifactUrlParameters | ConvertTo-Json -Depth 1)

$BcArtifactUrl = Get-BCArtifactUrl @GetBcArtifactUrlParameters
if (-not $BcArtifactUrl) {
    Write-Information -MessageData $(
        -join @(
            '##vso[task.logissue type=error;]'
            'There is not enough disk space left. There must be at least '
            "$('{0:0.#,.}' -f ($RequiredFreeSystemDriveSpaceInBytes / 1GB)) GB."
        )
    )
    exit(1)
}
Write-Information -MessageData "BC artifact URL: $BcArtifactUrl"


$CountryArtifactPath, $PlatformArtifactPath = Download-Artifacts -artifactUrl $BcArtifactUrl -includePlatform
Write-Information -MessageData "Country artifact path: $CountryArtifactPath"
Write-Information -MessageData "Platform artifact: path $PlatformArtifactPath"

$BcArtifactManifest = $(
    Get-Content -LiteralPath ($CountryArtifactPath | Join-Path -ChildPath 'manifest.json') -Raw |
    ConvertFrom-Json
)
Write-Information -MessageData 'BC artifact manifest:'
Write-Information -MessageData $($BcArtifactManifest | ConvertTo-Json)

[version]$Global:PlatformVersion = $BcArtifactManifest.platform
$SomethingNotGlobal = 123

$NewBCContainer = {
    param([hashtable]$Parameters)

    if (-not $SomethingNotGlobal) {
        throw 'Yep. $Global: is not needed.'
    }

    $Parameters['isolation'] = $env:DockerIsolation
    New-BcContainer @parameters

    Write-Information -MessageData 'Running script inside container:'
    Write-Information -MessageData $env:BeforeAppsInstallScript
    if ($env:BeforeAppsInstallScript) {
        $BeforeAppsInstallScript = @{
            containerName = $Parameters.containerName
            argumentList = $env:BeforeAppsInstallScript
            scriptBlock = {
                param(
                    [Parameter(Mandatory)]
                    $Command
                )

                Invoke-Expression -Command $Command
            }
        }
        Invoke-ScriptInBcContainer @BeforeAppsInstallScript
    }

    if ($env:ALLanguageExtensionFileName) {
        $RemoveDefaultCompilerScript = @{
            containerName = $Parameters.containerName
            scriptBlock = {
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item -Path 'C:\run\*.vsix'
            }
        }
        Invoke-ScriptInBcContainer @RemoveDefaultCompilerScript

        $ReplaceCompilerParameter = @{
            containerName = $Parameters.containerName
            localPath = $env:ALLanguageExtensionFileName
            containerPath = 'C:\run\ALLanguage.vsix'
        }
        Copy-FileToBCContainer @ReplaceCompilerParameter
    }

    foreach ($AppFolder in $AppFolders) {
        Write-Information -MessageData ''
        Write-Information -MessageData "Updating app version in '$AppFolder'..."

        $AppManifestPath = $AppFolder | Join-Path -ChildPath 'app.json'
        $AppManifest = Get-Content -Path $AppManifestPath -Raw | ConvertFrom-Json

        [version]$CustomAppVersion = $env:CustomAppVersion
        [version]$ManifestVersion = $AppManifest.version

        $VersionNumberPattern = '\{(?<Identifier>[a-zA-Z.]+)\}'
        [System.Text.RegularExpressions.MatchEvaluator]$VersionNumberEvaluator = {
            param(
                [Parameter(Mandatory)]
                [System.Text.RegularExpressions.Match]$Match
            )
            switch -CaseSensitive ($Match.Groups['Identifier'].Value) {
                'Manifest.Major' { $ManifestVersion.Major }
                'Manifest.Minor' { $ManifestVersion.Minor }
                'Manifest.Build' { $ManifestVersion.Build }
                'Manifest.Revision' { $ManifestVersion.Revision }
                'Container.Major' { $PlatformVersion.Major }
                'Container.Minor' { $PlatformVersion.Minor }
                'Container.Build' { $PlatformVersion.Build }
                'Container.Revision' { $PlatformVersion.Revision }
                'Custom.Major' { $CustomAppVersion.Major }
                'Custom.Minor' { $CustomAppVersion.Minor }
                'Custom.Build' { $CustomAppVersion.Build }
                'Custom.Revision' { $CustomAppVersion.Revision }
                'Release.Major' { $SelectedAppReleaseVersion.Major }
                'Release.Minor' { $SelectedAppReleaseVersion.Minor }
                'Release.Build' { $SelectedAppReleaseVersion.Build }
                'Release.Revision' { $SelectedAppReleaseVersion.Revision }
            }
        }
        [version]$SelectedAppReleaseVersion = [regex]::Replace(
            $env:AppReleaseVersionFormat, $VersionNumberPattern, $VersionNumberEvaluator)
        [version]$SelectedAppVersion = [regex]::Replace(
            $env:AppVersionFormat, $VersionNumberPattern, $VersionNumberEvaluator)

        $VersionMismatch = $(
            $ManifestVersion.Major -ne $SelectedAppVersion.Major -or
            $ManifestVersion.Minor -notin @(0, $SelectedAppVersion.Minor) -or
            $ManifestVersion.Build -ne $SelectedAppVersion.Build -and
            $ManifestVersion.Revision -ne $SelectedAppVersion.Revision
        )
        if ($VersionMismatch) {
            if ($ManifestVersionMismatchAction -in @('warning', 'error')) {
                Write-Information -MessageData $(
                    -join @(
                        '##vso[task.logissue type=warning;]'
                        "App manifest '$AppManifestPath' version '$ManifestVersion' "
                        "does not match selected app version '$SelectedAppVersion'."
                    )
                )
            }
            if ($ManifestVersionMismatchAction -eq 'error') {
                exit(1)
            }
        }

        Write-Information -MessageData "Selected app release version: $SelectedAppReleaseVersion"
        Write-Information -MessageData "Selected app version: $SelectedAppVersion"
        if ($AppFolder -eq $env:MainAppFolder) {
            Write-Information -MessageData $(
                -join @(
                    '##vso[task.setvariable variable=AppReleaseVersion;]'
                    $SelectedAppReleaseVersion
                )
            )
            Write-Information -MessageData $(
                -join @(
                    '##vso[task.setvariable variable=BcApplicationVersion;]'
                    $SelectedAppVersion
                )
            )
        }

        $AppManifest.version = [string]$SelectedAppVersion

        $AppManifest |
        ConvertTo-Json |
        Set-Content -LiteralPath $AppManifestPath
    }
}

Write-Information -MessageData 'Install apps folders:'
$InstallAppsFolders = @($env:LatestDependencyAppPaths | ConvertFrom-Json -NoEnumerate)
Write-Information -MessageData $InstallAppsFolders

$AppsFromDependencies = @(
    $InstallAppsFolders |
    Where-Object -FilterScript { $_ } |
    ForEach-Object -Process {
        $AppFiles = @(
            Get-ChildItem -LiteralPath $_ -Filter '*.app' -Recurse |
            Select-Object -ExpandProperty FullName
        )
        if (-not $AppFiles) {
            Write-Information -MessageData $(
                -join @(
                    '##vso[task.logissue type=error;]'
                    "No app files found in folder $_."
                )
            )
            exit(1)
        }

        $AppFiles
    }
)

$Global:ContainerName = -join [char[]]([char]'a'..[char]'z' | Get-Random -Count 8)
Write-Information -MessageData $(
    -join @(
        '##vso[task.setvariable variable=ContainerName;]'
        $Global:ContainerName
    )
)

$LicensePath = $(
    $PlatformVersion.Major..12 |
    ForEach-Object -Process {
        $LicenseFileExtension = 'bclicense'
        if ($_ -lt 20) {
            $LicenseFileExtension = 'flf'
        }
        "\\filestorage\Projects\DevOps\!Pipeline\Licenses\BC$_.$LicenseFileExtension"
    } |
    Resolve-Path |
    Select-Object -First 1 -ExpandProperty ProviderPath
)
Write-Information -MessageData "Selected license path for platform BC$($PlatformVersion.Major): $LicensePath"

$GetRunAlPipelineParameters = @{
    pipelinename = 'Build'
    containerName = $Global:ContainerName
    artifact = $BcArtifactUrl
    baseFolder = $env:WorkspaceRoot
    licenseFile = $LicensePath
    appFolders = $AppFolders
    testFolders = $TestAppFolders
    memoryLimit = $env:DockerMemory
    codeSignCertPfxFile = $env:CodeSignCertPfxFile
    codeSignCertPfxPassword = ($env:CodeSignCertPfxPassword | ConvertTo-SecureString -AsPlainText -Force)
    installApps = $AppsFromDependencies
    installTestRunner = $true
    installTestFramework = $true
    installTestLibraries = $true
    azureDevOps = $true
    NewBCContainer = $NewBCContainer
}
Run-AlPipeline @GetRunAlPipelineParameters