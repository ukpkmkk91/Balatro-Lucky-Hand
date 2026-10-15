param(
    [string]$GameDir,
    [string]$DataDir = (Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Balatro'),
    [switch]$DryRun,
    [switch]$Yes
)
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$temporaryRoot = $null
$applied = @()
$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)

function Full([string]$Path) { return [IO.Path]::GetFullPath($Path).TrimEnd('\') }
function Hash([string]$Path) {
    $stream=[IO.File]::OpenRead($Path);$hasher=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}
    finally{$hasher.Dispose();$stream.Dispose()}
}
function Under([string]$Path,[string]$Parent) {
    return (Full $Path).StartsWith((Full $Parent)+'\',[StringComparison]::OrdinalIgnoreCase)
}
function RelativeSafe([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Contains('\') -or $Name.Contains(':') -or
        $Name.StartsWith('/') -or ($Name.Split('/') -contains '..')) { throw 'Unsafe package/archive path.' }
}
function EntryText($Archive,[string]$Name) {
    $entry=$Archive.GetEntry($Name)
    if(-not $entry){throw ('Game identity entry missing: '+$Name)}
    $reader=New-Object IO.StreamReader($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function ExpandChecked([string]$ArchivePath,[string]$Destination) {
    $archive=[IO.Compression.ZipFile]::OpenRead($ArchivePath)
    $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    try {
        foreach($entry in $archive.Entries){
            RelativeSafe $entry.FullName
            if(-not $seen.Add($entry.FullName)){throw 'Duplicate archive path.'}
            $target=Full (Join-Path $Destination $entry.FullName.Replace('/','\'))
            if(-not (Under $target $Destination)){throw 'Archive escaped staging directory.'}
            if($entry.FullName.EndsWith('/')){[IO.Directory]::CreateDirectory($target)|Out-Null;continue}
            [IO.Directory]::CreateDirectory((Split-Path $target -Parent))|Out-Null
            $entryInput=$entry.Open();$entryOutput=[IO.File]::Create($target)
            try{$entryInput.CopyTo($entryOutput)}finally{$entryOutput.Dispose();$entryInput.Dispose()}
        }
    } finally {$archive.Dispose()}
}
function ZipFiles([string]$ArchivePath,[switch]$StripRoot) {
    $result=@{};$archive=[IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach($entry in $archive.Entries){
            RelativeSafe $entry.FullName
            if($entry.FullName.EndsWith('/')){continue}
            $relative=$entry.FullName
            if($StripRoot){$relative=$relative.Substring($relative.IndexOf('/')+1)}
            if($result.ContainsKey($relative)){throw 'Duplicate dependency file.'}
            $stream=$entry.Open();$hasher=[Security.Cryptography.SHA256]::Create()
            try{$result[$relative]=([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}
            finally{$hasher.Dispose();$stream.Dispose()}
        }
    } finally {$archive.Dispose()}
    return $result
}
function Matches([string]$Directory,$Expected) {
    if(-not (Test-Path -LiteralPath $Directory -PathType Container)){return $false}
    $actual=@(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force)
    if($actual.Count -ne $Expected.Count){return $false}
    foreach($file in $actual){
        $relative=$file.FullName.Substring((Full $Directory).Length+1).Replace('\','/')
        if(-not $Expected.ContainsKey($relative) -or (Hash $file.FullName) -ne $Expected[$relative]){return $false}
    }
    return $true
}

try {
    if([Environment]::OSVersion.Platform -ne 'Win32NT' -or -not [Environment]::Is64BitOperatingSystem){throw 'Windows x64 is required.'}
    $build=[int](Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    if($build -lt 22000){throw 'This installer currently targets the tested Windows 11 environment.'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $manifest=@{}
    foreach($line in [IO.File]::ReadAllLines((Join-Path $packageRoot 'MANIFEST.sha256'))){
        if($line -notmatch '^([0-9a-f]{64})  (.+)$'){throw 'Invalid package manifest.'}
        $digest=$Matches[1];$relative=$Matches[2];RelativeSafe $relative
        $file=Full (Join-Path $packageRoot $relative.Replace('/','\'))
        if(-not (Under $file $packageRoot) -or $manifest.ContainsKey($relative)){throw 'Invalid manifest path.'}
        if(-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Hash $file) -ne $digest){throw ('Package is incomplete or changed: '+$relative)}
        $manifest[$relative]=$digest
    }
    $dependencies=Get-Content -LiteralPath (Join-Path $packageRoot 'vendor\DEPENDENCIES.record') -Raw | ConvertFrom-Json
    if($dependencies.lovely.version -ne '0.10.0' -or $dependencies.smods.commit -ne '39182f0cc7b1af86d3d3d6afc5422661a07b4312'){throw 'Unsupported dependency bundle.'}
    $lovelyArchive=Join-Path $packageRoot ('vendor\'+$dependencies.lovely.archive)
    $smodsArchive=Join-Path $packageRoot ('vendor\'+$dependencies.smods.archive)
    if((Hash $lovelyArchive) -ne $dependencies.lovely.sha256 -or (Hash $smodsArchive) -ne $dependencies.smods.sha256){throw 'Dependency checksum mismatch.'}
    if(-not $GameDir){
        Add-Type -AssemblyName System.Windows.Forms
        $dialog=New-Object Windows.Forms.FolderBrowserDialog
        $dialog.Description='Select the Balatro folder containing Balatro.exe / 选择小丑牌安装目录'
        $dialog.ShowNewFolderButton=$false
        try{if($dialog.ShowDialog() -ne 'OK'){throw 'Installation cancelled.'};$GameDir=$dialog.SelectedPath}
        finally{$dialog.Dispose()}
    }
    $GameDir=Full $GameDir;$DataDir=Full $DataDir
    if($GameDir -eq [IO.Path]::GetPathRoot($GameDir).TrimEnd('\') -or $DataDir -eq [IO.Path]::GetPathRoot($DataDir).TrimEnd('\')){throw 'A drive root is not a valid installation target.'}
    $gameExe=Join-Path $GameDir 'Balatro.exe'
    if(-not (Test-Path -LiteralPath $gameExe -PathType Leaf)){throw 'Balatro.exe was not found.'}
    $archive=[IO.Compression.ZipFile]::OpenRead($gameExe)
    try{
        $version=EntryText $archive 'version.jkr';$main=EntryText $archive 'main.lua'
        $gameVersion=($version -split '\r?\n')[0].Trim()
        if($gameVersion -ne '1.0.1o-FULL' -or $main -notmatch 'LocalThunk' -or -not $archive.GetEntry('card.lua') -or -not $archive.GetEntry('game.lua')){throw 'This is not the supported Balatro 1.0.1o-FULL installation.'}
    }finally{$archive.Dispose()}
    $appIdFile=Join-Path $GameDir 'steam_appid.txt'
    if((Test-Path -LiteralPath $appIdFile) -and (Get-Content -LiteralPath $appIdFile -Raw).Trim() -ne '2379780'){throw 'Steam App ID does not match Balatro.'}
    foreach($process in @(Get-Process -Name Balatro -ErrorAction SilentlyContinue)){
        if(-not $process.Path -or (Full $process.Path) -eq $gameExe){throw 'Close Balatro before installing.'}
    }
    $mods=Join-Path $DataDir 'Mods';$smodsTarget=Join-Path $mods 'smods';$modTarget=Join-Path $mods 'BalatroDrawController'
    $dllTarget=Join-Path $GameDir 'winmm.dll'
    if(Test-Path -LiteralPath (Join-Path $GameDir 'version.dll')){throw 'An older injector or unknown version.dll is present. Resolve it manually before installing; it will not be removed.'}
    $lovelyFiles=ZipFiles $lovelyArchive
    if($lovelyFiles.Count -ne 1 -or -not $lovelyFiles.ContainsKey('winmm.dll')){throw 'Unexpected Lovely archive layout.'}
    if((Test-Path -LiteralPath $dllTarget) -and (Hash $dllTarget) -ne $lovelyFiles['winmm.dll']){throw 'A different winmm.dll is already installed. It will not be overwritten.'}
    $smodsFiles=ZipFiles $smodsArchive -StripRoot
    if((Test-Path -LiteralPath $smodsTarget) -and -not (Matches $smodsTarget $smodsFiles)){throw 'Existing smods folder differs from the bundled version. Move it outside Mods manually before continuing.'}
    foreach($folder in @(Get-ChildItem -LiteralPath $mods -Directory -ErrorAction SilentlyContinue)){
        if($folder.FullName -ne $smodsTarget -and (Test-Path -LiteralPath (Join-Path $folder.FullName 'lovely')) -and (Test-Path -LiteralPath (Join-Path $folder.FullName 'version.lua')) -and (Test-Path -LiteralPath (Join-Path $folder.FullName 'src\core.lua'))){throw 'Another SMODS installation was found. Remove the duplicate before installing.'}
        if($folder.FullName -ne $modTarget -and (Test-Path -LiteralPath (Join-Path $folder.FullName 'BalatroDrawController.json'))){throw 'Another controller folder was found. Move the duplicate outside Mods first.'}
    }
    if(Test-Path -LiteralPath $modTarget){
        $metadata=Join-Path $modTarget 'BalatroDrawController.json'
        if(-not (Test-Path -LiteralPath $metadata) -or (Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json).id -ne 'balatro_draw_controller'){throw 'The target Mod folder contains unknown files and will not be replaced.'}
    }
    Write-Host 'Balatro Lucky Hand: 0.1.0 first public release / 首次公开版本'
    Write-Host ('Game / 游戏: '+$GameDir)
    Write-Host ('Mods / 模组: '+$mods)
    Write-Host 'Installs Lovely 0.10.0 (MIT), SMODS 26.829.0 source (GPLv3), and the controller (MIT).'
    Write-Host 'No downloads, registry changes, admin elevation, Steam changes or player save edits are performed.'
    Write-Host 'Existing matching dependencies are reused. An existing controller is backed up outside Mods.'
    if($DryRun){Write-Output 'DRY RUN OK: package, game identity, versions, paths and conflicts checked; no installation changes.';return}
    if(-not $Yes -and (Read-Host '输入 INSTALL 确认 / Type INSTALL to continue') -cne 'INSTALL'){throw 'Installation cancelled.'}
    $temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('BDCLuckyHand-'+[Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temporaryRoot)|Out-Null
    ExpandChecked $lovelyArchive (Join-Path $temporaryRoot 'lovely')
    ExpandChecked $smodsArchive (Join-Path $temporaryRoot 'smods-unpacked')
    $smodsSource=@(Get-ChildItem -LiteralPath (Join-Path $temporaryRoot 'smods-unpacked') -Directory)
    if($smodsSource.Count -ne 1){throw 'Unexpected SMODS archive root.'}
    $modSource=Join-Path $temporaryRoot 'controller';[IO.Directory]::CreateDirectory($modSource)|Out-Null
    foreach($relative in $manifest.Keys){
        if($relative -match '^(src/|localization/|docs/)' -or $relative -in @('main.lua','config.lua','BalatroDrawController.json','README.md','CHANGELOG.md','LICENSE','THIRD_PARTY_NOTICES.md','vendor/DEPENDENCIES.record','vendor/LICENSE-Lovely-MIT.txt','vendor/LICENSE-SMODS-GPL-3.0.txt')){
            $destination=Join-Path $modSource $relative.Replace('/','\');[IO.Directory]::CreateDirectory((Split-Path $destination -Parent))|Out-Null
            Copy-Item -LiteralPath (Join-Path $packageRoot $relative.Replace('/','\')) -Destination $destination
        }
    }
    $operations=@()
    if(-not (Test-Path -LiteralPath $dllTarget)){$operations+=@{source=(Join-Path $temporaryRoot 'lovely\winmm.dll');target=$dllTarget;backup=(Join-Path $GameDir ('BDCBackups\'+$stamp+'\winmm.dll'));directory=$false}}
    if(-not (Test-Path -LiteralPath $smodsTarget)){$operations+=@{source=$smodsSource[0].FullName;target=$smodsTarget;backup=(Join-Path $DataDir ('BDCBackups\'+$stamp+'\smods'));directory=$true}}
    $operations+=@{source=$modSource;target=$modTarget;backup=(Join-Path $DataDir ('BDCBackups\'+$stamp+'\BalatroDrawController'));directory=$true}
    $licenseTarget=Join-Path $GameDir 'Balatro-Lucky-Hand-Lovely-LICENSE.txt'
    $operations+=@{source=(Join-Path $packageRoot 'vendor\LICENSE-Lovely-MIT.txt');target=$licenseTarget;backup=(Join-Path $GameDir ('BDCBackups\'+$stamp+'\Lovely-LICENSE.txt'));directory=$false}
    $allowedTargets=@($dllTarget,$smodsTarget,$modTarget,$licenseTarget)
    foreach($op in $operations){
        $target=Full $op.target;$backup=Full $op.backup
        if($allowedTargets -notcontains $target -or -not ((Under $backup (Join-Path $DataDir 'BDCBackups')) -or (Under $backup (Join-Path $GameDir 'BDCBackups')))){throw 'Operation escaped exact installation scope.'}
        [IO.Directory]::CreateDirectory((Split-Path $target -Parent))|Out-Null
        $op.hadOriginal=Test-Path -LiteralPath $target;$op.newStarted=$false
        if($op.hadOriginal){[IO.Directory]::CreateDirectory((Split-Path $backup -Parent))|Out-Null;Move-Item -LiteralPath $target -Destination $backup}
        $applied+=,$op;$op.newStarted=$true
        if($op.directory){Copy-Item -LiteralPath $op.source -Destination $target -Recurse}else{Copy-Item -LiteralPath $op.source -Destination $target}
    }
    if((Hash $dllTarget) -ne $lovelyFiles['winmm.dll'] -or -not (Matches $smodsTarget $smodsFiles)){throw 'Installed dependency verification failed.'}
    foreach($relative in $manifest.Keys){
        if($relative -match '^(src/|localization/|docs/)' -or $relative -in @('main.lua','config.lua','BalatroDrawController.json','README.md','CHANGELOG.md','LICENSE','THIRD_PARTY_NOTICES.md','vendor/DEPENDENCIES.record','vendor/LICENSE-Lovely-MIT.txt','vendor/LICENSE-SMODS-GPL-3.0.txt')){
            if((Hash (Join-Path $modTarget $relative.Replace('/','\'))) -ne $manifest[$relative]){throw 'Installed controller verification failed.'}
        }
    }
    Write-Host '安装完成 / Installed. Start Balatro normally and release F8 in a run.' -ForegroundColor Green
    Write-Host 'Only the pinned local version combination is validated; 0.1.0 complete live acceptance remains pending.'
} catch {
    $failure=$_.Exception.Message
    # Roll back only exact targets already recorded above. Retain failed output.
    for($index=$applied.Count-1;$index -ge 0;$index--){
        $op=$applied[$index];$target=Full $op.target;$backup=Full $op.backup
        if($allowedTargets -notcontains $target){continue}
        try{
            if(Test-Path -LiteralPath $target){
                $failed=$backup+'.failed';[IO.Directory]::CreateDirectory((Split-Path $failed -Parent))|Out-Null
                if(Test-Path -LiteralPath $failed){throw 'Rollback destination exists.'}
                Move-Item -LiteralPath $target -Destination $failed
            }
            if($op.hadOriginal -and (Test-Path -LiteralPath $backup)){Move-Item -LiteralPath $backup -Destination $target}
        }catch{Write-Warning ('Restore requires attention: '+$target+'; backup: '+$backup)}
    }
    Write-Error ($failure+' No administrator elevation was attempted. If access is denied, choose how to grant access yourself.')
    exit 1
} finally {
    if($temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)){
        $fullTemporary=Full $temporaryRoot;$tempBase=Full ([IO.Path]::GetTempPath())
        if((Under $fullTemporary $tempBase) -and (Split-Path $fullTemporary -Leaf) -like 'BDCLuckyHand-*'){
            Remove-Item -LiteralPath $fullTemporary -Recurse -Force
        }
    }
}
