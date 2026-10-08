@echo off
chcp 65001 >nul
title Project Viewpoint Setup (No-Steam / GOG / SteamCMD)
rem El .ps1 se ejecuta con iex, asi que $PSScriptRoot queda vacio. Pasamos la carpeta del .bat.
set "PV_SETUP_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath '%~f0' -Raw) -split ('#PS'+'START#'))[1]"
echo.
pause
exit /b
#PSSTART#
# =============================================================================
# Project Viewpoint - Instalador No-Steam / GOG / SteamCMD
# Autor: Yorlandiscuba (Cuba)
# https://github.com/Yorlandiscuba/Instalador-3d
# Hecho dedicando la cuota diaria de luz.
# Si te sirve, una estrella en GitHub.
# Creadores de contenido: compartan este enlace (solo se muestra, no se descarga):
# https://link-center.net/8163108/9gBRbsulo3vJ
# Compatible con: GOG, Steam, instalaciones custom
# Descarga mods via SteamCMD (anonimo), instala ZombieBuddy y configura todo
# =============================================================================
$ErrorActionPreference = 'Stop'
$AppId = '108600'

# iex desde el .bat no define $PSScriptRoot. Usamos la carpeta que pasa el .bat.
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $ScriptDir = $PSScriptRoot
} elseif (-not [string]::IsNullOrWhiteSpace($env:PV_SETUP_DIR)) {
    $ScriptDir = $env:PV_SETUP_DIR.TrimEnd('\')
} else {
    $ScriptDir = (Get-Location).Path
}

# Mods a descargar (Workshop IDs)
$Mods = @(
    @{ Id = '3619862853'; Name = 'ZombieBuddy' },
    @{ Id = '3809306528'; Name = 'Project Viewpoint' },
    @{ Id = '3810302175'; Name = '3D models for Viewpoint' },
    @{ Id = '3811151399'; Name = 'Fix_ZombieBuddy_King' },
    @{ Id = '3811400314'; Name = 'Project ViewPoint: 3D Interiors & Native Aim' }
)

# Nombres internos (mod.info) que default.txt activa al arrancar el juego.
$ActiveMods = @(
    'ZombieBuddy',
    'ViewpointFurnitureFix',
    'Viewpoint',
    'Fix_ZombieBuddy_King',
    'PZVoxelStudioViewpoint'
)

# Join-Path de PowerShell exige que la letra de unidad exista. Path.Combine no.
function Join-SafePath([string]$parent, [string]$child) {
    if ([string]::IsNullOrWhiteSpace($parent) -or [string]::IsNullOrWhiteSpace($child)) {
        throw 'No se pudo armar una ruta: falta la carpeta base o el nombre.'
    }
    return [System.IO.Path]::Combine($parent, $child)
}

function Get-ReadyDriveRoots {
    $roots = @()
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        try {
            # Con barra final (C:\). Sin ella, Path.Combine deja "C:carpeta" y no "C:\carpeta".
            if ($drive.IsReady) { $roots += $drive.RootDirectory.FullName }
        } catch {}
    }
    return $roots
}

function Test-DriveReady([string]$path) {
    if ($path -notmatch '^[A-Za-z]:') { return $true }
    $letter = $path.Substring(0, 1)
    foreach ($ready in Get-ReadyDriveRoots) {
        if ($ready.Substring(0, 1) -eq $letter) { return $true }
    }
    return $false
}

function Test-ExistingPath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    if (-not (Test-DriveReady $path)) { return $false }
    try {
        return Test-Path -LiteralPath $path -ErrorAction SilentlyContinue
    } catch {
        return $false
    }
}

$ZomboidUserDir = Join-SafePath $env:USERPROFILE 'Zomboid'
$LocalModsDir   = Join-SafePath $ZomboidUserDir 'mods'
$StateDir       = Join-SafePath $env:LOCALAPPDATA 'ProjectViewpointSetupNoSteam'
$StateFile      = Join-SafePath $StateDir 'state.json'

function Say([string]$msg, [string]$color = 'Gray') {
    Write-Host $msg -ForegroundColor $color
}

function Show-Credits {
    Say 'Autor: Yorlandiscuba, cubano. Sobreviviendo en la isla a base de cuota de luz.' White
    Say 'Este instalador salio de esa cuota. Si, la del dia. El ventilador tuvo que esperar.' DarkGray
    Say 'Si te sirvio, una estrella no gasta corriente:' Cyan
    Say 'https://github.com/Yorlandiscuba/Instalador-3d' White
    Say 'Creadores de contenido: compartan ESTE enlace, no el repo pelado.' Yellow
    Say 'Cada clic me ayuda a mejorar el script y a no pasarme el mes a oscuras:' Yellow
    Say 'https://link-center.net/8163108/9gBRbsulo3vJ' White
    Say 'Y credito al autor, que conste. Soy yo, el de la cuota.' DarkGray
}

function Ask-Path([string]$prompt, [string]$default = '') {
    if ($default) { $prompt = "$prompt  [Enter = $default]" }
    $ans = Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($ans) -and $default) { return $default }
    if ([string]::IsNullOrWhiteSpace($ans)) {
        throw 'No se indico una ruta. Vuelve a ejecutar el script e introduce la carpeta completa.'
    }
    return $ans.Trim().Trim('"')
}

function Ensure-Dir([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No se pudo crear una carpeta: la ruta esta vacia.'
    }
    if (-not (Test-DriveReady $path)) {
        throw "Esa unidad no existe en este PC, no se puede usar la ruta: $path"
    }
    if (-not (Test-ExistingPath $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

function Backup-File([string]$file) {
    if (-not (Test-Path -LiteralPath $file)) { return }
    $bak = "$file.pvsetup.bak"
    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $file $bak -Force
        Say "    Backup creado: $(Split-Path $bak -Leaf)" DarkGray
    }
}

# ---------- Detectar SteamCMD ----------
function Find-SteamCMD {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($ScriptDir)) {
        $candidates += (Join-SafePath $ScriptDir 'steamcmd\steamcmd.exe')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $candidates += (Join-SafePath $env:USERPROFILE 'steamcmd\steamcmd.exe')
        $candidates += (Join-SafePath $env:USERPROFILE 'Desktop\steamcmd\steamcmd.exe')
    }
    # Solo unidades conectadas. No se prueban letras fijas como E:.
    foreach ($root in Get-ReadyDriveRoots) {
        $candidates += (Join-SafePath $root 'steamcmd\steamcmd.exe')
    }
    foreach ($c in $candidates) {
        if (Test-ExistingPath $c) { return $c }
    }
    return $null
}

# ---------- Descargar SteamCMD oficial si no existe ----------
function Install-SteamCMD {
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
        throw 'No se pudo determinar la carpeta del script para instalar SteamCMD.'
    }

    $destDir = Join-SafePath $ScriptDir 'steamcmd'
    $exe = Join-SafePath $destDir 'steamcmd.exe'
    $zip = Join-SafePath $env:TEMP 'steamcmd.zip'
    $url = 'https://client-update.steamstatic.com/installer/steamcmd.zip'

    Say '    SteamCMD no encontrado. Descargando el instalador oficial...' Cyan
    Say "    $url" DarkGray
    Ensure-Dir $destDir

    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    } finally {
        $ProgressPreference = $prevProgress
    }

    Say '    Descomprimiendo...' Cyan
    Expand-Archive -LiteralPath $zip -DestinationPath $destDir -Force
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue

    if (-not (Test-ExistingPath $exe)) {
        throw "La descarga termino, pero no aparecio steamcmd.exe en: $destDir"
    }
    Say "    SteamCMD instalado: $exe" Green
    return $exe
}

# ---------- Detectar carpeta del juego ----------
function Find-GameDir {
    $rels = @(
        'Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
        'Program Files\Steam\steamapps\common\ProjectZomboid',
        'Steam\steamapps\common\ProjectZomboid',
        'SteamLibrary\steamapps\common\ProjectZomboid',
        'GOG Games\Project Zomboid',
        'Games\Project Zomboid'
    )
    $candidates = @()
    foreach ($root in Get-ReadyDriveRoots) {
        foreach ($rel in $rels) {
            $candidates += (Join-SafePath $root $rel)
        }
    }
    # Buscar tambien en libraries de Steam. Si una biblioteca apunta a un disco que ya no esta, se ignora.
    try {
        $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
        if ($steam) {
            $steam = $steam -replace '/', '\'
            if (Test-DriveReady $steam) {
                $candidates += (Join-SafePath $steam 'steamapps\common\ProjectZomboid')
                $vdf = Join-SafePath $steam 'steamapps\libraryfolders.vdf'
                if (Test-ExistingPath $vdf) {
                    $foundPaths = Select-String -LiteralPath $vdf -Pattern '"path"\s+"(.+?)"' -AllMatches
                    foreach ($m in $foundPaths.Matches) {
                        $p = $m.Groups[1].Value -replace '\\\\', '\'
                        if ((-not [string]::IsNullOrWhiteSpace($p)) -and (Test-DriveReady $p)) {
                            $candidates += (Join-SafePath $p 'steamapps\common\ProjectZomboid')
                        }
                    }
                }
            }
        }
    } catch {}

    foreach ($c in ($candidates | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if ((Test-ExistingPath (Join-SafePath $c 'ProjectZomboid64.exe')) -or
            (Test-ExistingPath (Join-SafePath $c 'ProjectZomboid64.bat'))) {
            return $c
        }
    }
    return $null
}

function Test-GameDir([string]$dir) {
    if (-not (Test-ExistingPath $dir)) { return $false }
    return (Test-ExistingPath (Join-SafePath $dir 'ProjectZomboid64.exe')) -or
           (Test-ExistingPath (Join-SafePath $dir 'ProjectZomboid64.bat'))
}

# Si eligen la carpeta padre (por ejemplo D:\Games), usa la subcarpeta del juego si solo hay una.
function Resolve-GameDir([string]$dir) {
    if (Test-GameDir $dir) { return $dir }
    if (-not (Test-ExistingPath $dir)) { return $null }
    $found = @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-GameDir $_.FullName
    })
    if ($found.Count -eq 1) { return $found[0].FullName }
    return $null
}

function Get-FolderStart {
    $rels = @(
        'Games',
        'GOG Games',
        'Steam\steamapps\common',
        'Program Files (x86)\Steam\steamapps\common',
        'Program Files\Steam\steamapps\common'
    )
    foreach ($root in Get-ReadyDriveRoots) {
        foreach ($rel in $rels) {
            $start = Join-SafePath $root $rel
            if (Test-ExistingPath $start) { return $start }
        }
    }
    return $null
}

# Ventana de "Seleccionar carpeta" del Explorador, la misma de Examinar en un instalador.
function Show-VistaFolderPicker([string]$title, [string]$initial) {
    if (-not ('VistaFolderPicker' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class VistaFolderPicker {
    public string SelectedPath { get; set; }
    public string Title { get; set; }

    public bool Show() {
        IFileDialog dialog = (IFileDialog)new FileOpenDialogRCW();
        uint options;
        dialog.GetOptions(out options);
        options |= 0x00000020;
        options |= 0x00001000;
        dialog.SetOptions(options);
        if (!string.IsNullOrEmpty(Title)) {
            dialog.SetTitle(Title);
            dialog.SetOkButtonLabel("Seleccionar carpeta");
        }
        if (!string.IsNullOrEmpty(SelectedPath)) {
            IShellItem start;
            Guid iid = typeof(IShellItem).GUID;
            int hrItem = SHCreateItemFromParsingName(SelectedPath, IntPtr.Zero, ref iid, out start);
            if (hrItem == 0 && start != null) dialog.SetFolder(start);
        }
        int hr = dialog.Show(IntPtr.Zero);
        if (hr != 0) return false;
        IShellItem result;
        dialog.GetResult(out result);
        string path;
        result.GetDisplayName(0x80058000, out path);
        SelectedPath = path;
        return true;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
    static extern int SHCreateItemFromParsingName(
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath,
        IntPtr pbc,
        ref Guid riid,
        out IShellItem ppv);

    [ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
    class FileOpenDialogRCW {}

    [ComImport, Guid("42f85136-db7e-439c-85f1-e4075d135fc8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IFileDialog {
        [PreserveSig] int Show(IntPtr parent);
        void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
        void SetFileTypeIndex(uint iFileType);
        void GetFileTypeIndex(out uint piFileType);
        void Advise(IntPtr pfde, out uint pdwCookie);
        void Unadvise(uint dwCookie);
        void SetOptions(uint fos);
        void GetOptions(out uint fos);
        void SetDefaultFolder(IShellItem psi);
        void SetFolder(IShellItem psi);
        void GetFolder(out IShellItem ppsi);
        void GetCurrentSelection(out IShellItem ppsi);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
        void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
        void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
        void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
        void GetResult(out IShellItem ppsi);
        void AddPlace(IShellItem psi, uint fdap);
        void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
        void Close(int hr);
        void SetClientGuid(ref Guid guid);
        void ClearClientData();
        void SetFilter(IntPtr pFilter);
    }

    [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItem {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
        void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        void Compare(IShellItem psi, uint hint, out int piOrder);
    }
}
'@
    }

    $picker = New-Object VistaFolderPicker
    $picker.Title = $title
    if (-not [string]::IsNullOrWhiteSpace($initial)) { $picker.SelectedPath = $initial }
    $ok = $picker.Show()
    if (-not $ok) { return @{ Cancelled = $true } }
    return @{ Path = $picker.SelectedPath }
}

function Select-GameFolder {
    Say ''
    Say '    Elige la carpeta de INSTALACION de Project Zomboid.' White
    Say '    Dentro deben estar ProjectZomboid64.exe o ProjectZomboid64.bat.' White
    Say '    No es la carpeta de partidas (Documentos\Zomboid) ni la de mods.' Yellow
    Say ''

    $title = 'Carpeta de instalacion de Project Zomboid (la que contiene ProjectZomboid64.exe). No elijas Documentos\Zomboid.'
    $initial = Get-FolderStart

    try {
        $picked = Show-VistaFolderPicker $title $initial
        if ($picked.Cancelled) { throw 'Cancelaste la seleccion de la carpeta del juego.' }
        if (-not [string]::IsNullOrWhiteSpace($picked.Path)) { return $picked.Path }
    } catch {
        if ($_.Exception.Message -match 'Cancelaste') { throw }
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $title
        $dialog.ShowNewFolderButton = $false
        $dialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer
        if ($initial) { $dialog.SelectedPath = $initial }
        $result = $dialog.ShowDialog()
        if ($result -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($dialog.SelectedPath)) {
            throw 'Cancelaste la seleccion de la carpeta del juego.'
        }
        return $dialog.SelectedPath
    } catch {
        if ($_.Exception.Message -match 'Cancelaste') { throw }
        Say '    No se pudo abrir la ventana de carpetas. Escribe la ruta a mano.' Yellow
        return Ask-Path 'Pega la ruta de la carpeta de instalacion de Project Zomboid (la que contiene ProjectZomboid64.exe)'
    }
}

# ---------- Descargar un workshop item ----------
function Download-WorkshopItem([string]$steamCmd, [string]$forceDir, [string]$id, [string]$name) {
    Say "    Descargando $name (ID $id)..." Cyan
    $args = @(
        '+login', 'anonymous',
        '+force_install_dir', $forceDir,
        '+workshop_download_item', $AppId, $id,
        '+quit'
    )
    $p = Start-Process -FilePath $steamCmd -ArgumentList $args -Wait -PassThru -NoNewWindow
    $target = Join-SafePath $forceDir "steamapps\workshop\content\$AppId\$id"
    if (Test-Path -LiteralPath $target) {
        $hasFiles = Get-ChildItem -LiteralPath $target -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hasFiles) {
            Say "    OK: $name descargado." Green
            return $target
        }
    }
    Say "    FALLO: $name no se pudo descargar (SteamCMD exit $($p.ExitCode))." Yellow
    return $null
}

# Mueve un | / - \ mientras corre un trabajo largo, para que la ventana no parezca congelada.
function Invoke-WithPulse([string]$label, [scriptblock]$work, $arg1, $arg2) {
    $ps = [powershell]::Create()
    $null = $ps.AddScript({
        param($body, $x, $y)
        $ErrorActionPreference = 'Stop'
        & $body $x $y
    }).AddArgument($work).AddArgument($arg1).AddArgument($arg2)
    $handle = $ps.BeginInvoke()
    $frames = @('|', '/', '-', '\')
    $i = 0
    try {
        while (-not $handle.IsCompleted) {
            Write-Host ("`r    {0} {1}" -f $label, $frames[$i % 4]) -NoNewline -ForegroundColor Cyan
            $i++
            Start-Sleep -Milliseconds 400
        }
        $null = $ps.EndInvoke($handle)
    } catch {
        Write-Host ''
        throw
    } finally {
        $ps.Dispose()
    }
    Write-Host ("`r    {0}   " -f $label)
}

# ---------- Copiar mods a Zomboid\mods ----------
function Install-ModsFromWorkshop([string]$workshopRoot) {
    $modsRoot = Join-SafePath $workshopRoot 'mods'
    if (-not (Test-Path -LiteralPath $modsRoot)) {
        # A veces la estructura es directa
        $modsRoot = $workshopRoot
    }
    $copied = @()
    $dirs = @(Get-ChildItem -LiteralPath $modsRoot -Directory -ErrorAction SilentlyContinue)
    foreach ($dir in $dirs) {
        $src = $dir.FullName
        $dest = Join-SafePath $LocalModsDir $dir.Name
        Say "    Mod: $($dir.Name)" White
        if (Test-Path -LiteralPath $dest) {
            Invoke-WithPulse "Borrando la copia anterior de $($dir.Name)" {
                param($path, $unused)
                Remove-Item -LiteralPath $path -Recurse -Force
            } $dest $null
        }
        Invoke-WithPulse "Copiando $($dir.Name) a Zomboid\mods" {
            param($from, $to)
            Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
        } $src $dest
        $copied += $dir.Name
        Say "    Listo: $($dir.Name)" Green
    }
    return $copied
}

# default.txt es la lista de mods activos del juego (Zomboid\mods\default.txt).
function Write-DefaultModList {
    $file = Join-SafePath $LocalModsDir 'default.txt'
    $existed = Test-Path -LiteralPath $file
    Ensure-Dir $LocalModsDir
    if ($existed) { Backup-File $file }

    $lines = @(
        'VERSION = 1,',
        '',
        'mods',
        '{'
    )
    foreach ($id in $ActiveMods) {
        $lines += "    mod = $id,"
    }
    $lines += @(
        '}',
        '',
        'maps',
        '{',
        '}',
        ''
    )
    [IO.File]::WriteAllText($file, ($lines -join "`r`n"))
    Say "    Mods activos en: $file" Green
    foreach ($id in $ActiveMods) {
        Say "      - $id" DarkGray
    }
    return $existed
}

# ---------- Buscar zbNative.dll y ZombieBuddy.jar ----------
function Find-ZombieBuddyFiles([string[]]$workshopDirs) {
    $dll = $null
    $jar = $null

    foreach ($dir in $workshopDirs) {
        if (-not $dir) { continue }
        $foundDll = Get-ChildItem -LiteralPath $dir -Recurse -Filter 'zbNative.dll' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($foundDll) { $dll = $foundDll.FullName }

        if (-not $jar) {
            $foundJar = Get-ChildItem -LiteralPath $dir -Recurse -Filter 'ZombieBuddy.jar' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($foundJar) { $jar = $foundJar.FullName }
        }
    }
    return @{ Dll = $dll; Jar = $jar }
}

# Las libs parcheadas van despues de las originales: las pisan en la raiz del juego.
function Copy-ZombieBuddyPatch([string]$gameDir, [string]$workshopDir) {
    $expected = Join-SafePath $LocalModsDir 'Fix_ZombieBuddy_King\libs'
    $libs = $null
    $dllName = 'zbNative.dll'
    $jarName = 'ZombieBuddy.jar'
    $dll = Join-SafePath $expected $dllName
    $jar = Join-SafePath $expected $jarName
    if ((Test-ExistingPath $dll) -and (Test-ExistingPath $jar)) {
        $libs = $expected
    }

    if (-not $libs) {
        $roots = @()
        $modDir = Join-SafePath $LocalModsDir 'Fix_ZombieBuddy_King'
        if (Test-ExistingPath $modDir) { $roots += $modDir }
        if ($workshopDir -and (Test-ExistingPath $workshopDir)) { $roots += $workshopDir }
        foreach ($root in $roots) {
            if (-not (Test-DriveReady $root)) { continue }
            $hit = @(Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter 'libs' -ErrorAction SilentlyContinue | Where-Object {
                (Test-ExistingPath (Join-SafePath $_.FullName $dllName)) -and
                (Test-ExistingPath (Join-SafePath $_.FullName $jarName))
            } | Select-Object -First 1)
            if ($hit.Count -eq 1) {
                $libs = $hit[0].FullName
                break
            }
        }
    }

    if (-not $libs) {
        throw 'No esta el parche en Zomboid\mods\Fix_ZombieBuddy_King\libs (zbNative.dll y ZombieBuddy.jar). Sin esas librerias la ultima version de Steam no carga los mods Java.'
    }

    Copy-Item -LiteralPath (Join-SafePath $libs $dllName) (Join-SafePath $gameDir $dllName) -Force
    Copy-Item -LiteralPath (Join-SafePath $libs $jarName) (Join-SafePath $gameDir $jarName) -Force
    Say '    Parche aplicado. Estas dos librerias reemplazan a las de ZombieBuddy:' Green
    Say "    $libs" DarkGray
    Say "    $dllName y $jarName -> raiz del juego" Green
}

# ---------- Editar ProjectZomboid64.bat ----------
function Patch-Bat([string]$gameDir) {
    $bat = Join-SafePath $gameDir 'ProjectZomboid64.bat'
    if (-not (Test-Path -LiteralPath $bat)) {
        Say "    ProjectZomboid64.bat no encontrado (puede ser normal en algunas instalaciones)." Yellow
        return $false
    }
    Backup-File $bat
    $content = Get-Content -LiteralPath $bat -Raw

    if ($content -match '(?im)^SET\s+_JAVA_OPTIONS\s*=') {
        $content = [regex]::Replace($content, '(?im)^(SET\s+_JAVA_OPTIONS\s*=).*', 'SET _JAVA_OPTIONS=-agentlib:zbNative')
    } else {
        # Insertar al principio si no existe
        $content = "SET _JAVA_OPTIONS=-agentlib:zbNative`r`n" + $content
    }
    [IO.File]::WriteAllText($bat, $content)
    Say "    ProjectZomboid64.bat -> SET _JAVA_OPTIONS=-agentlib:zbNative" Green
    return $true
}

# ---------- Editar ProjectZomboid64.json (RAM + agent) ----------
function Patch-Json([string]$gameDir, [int]$ramMB) {
    $json = Join-SafePath $gameDir 'ProjectZomboid64.json'
    if (-not (Test-Path -LiteralPath $json)) {
        Say "    ProjectZomboid64.json no encontrado." Yellow
        return $false
    }
    Backup-File $json
    $t = Get-Content -LiteralPath $json -Raw

    # Inyectar agentlib si no esta
    if ($t -notmatch 'agentlib:zbNative') {
        $t = ([regex]'"vmArgs"\s*:\s*\[').Replace($t, "`"vmArgs`": [`r`n`t`t`"-agentlib:zbNative`",", 1)
    }

    # Subir -Xmx si es menor
    if ($t -match '-Xmx(\d+)([mMgG])') {
        $cur = [int]$Matches[1]
        if ($Matches[2] -match '[gG]') { $cur *= 1024 }
        if ($cur -lt $ramMB) {
            $t = $t -replace '-Xmx\d+[mMgG]', "-Xmx${ramMB}m"
        }
    }

    try {
        $null = $t | ConvertFrom-Json
    } catch {
        Say "    ERROR: el JSON quedaria invalido, no se modifico." Red
        return $false
    }
    [IO.File]::WriteAllText($json, $t)
    Say "    ProjectZomboid64.json actualizado (agent + RAM >= ${ramMB} MB)." Green
    return $true
}

# ---------- Crear acceso directo al .bat ----------
function Create-Shortcut([string]$gameDir) {
    $bat = Join-SafePath $gameDir 'ProjectZomboid64.bat'
    if (-not (Test-Path -LiteralPath $bat)) { return $null }

    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-SafePath $desktop 'Project Zomboid (Viewpoint).lnk'

    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath = $bat
    $sc.WorkingDirectory = $gameDir
    $sc.Description = 'Project Zomboid con Project Viewpoint / ZombieBuddy'
    # Intentar icono del exe si existe
    $exe = Join-SafePath $gameDir 'ProjectZomboid64.exe'
    if (Test-Path -LiteralPath $exe) {
        $sc.IconLocation = "$exe,0"
    }
    $sc.Save()
    Say "    Acceso directo creado en el Escritorio: Project Zomboid (Viewpoint).lnk" Green
    return $lnkPath
}

# =============================================================================
function Invoke-Setup {
    Say ''
    Say '============================================================' Cyan
    Say '  Project Viewpoint Setup  (No-Steam / GOG / SteamCMD)' Cyan
    Say '============================================================' Cyan
    Say ''
    Show-Credits
    Say ''
    Say 'Este script:' White
    Say '  1. Usa SteamCMD (anonimo) para descargar los mods del Workshop' Gray
    Say '  2. Los copia a Zomboid\mods y los deja activos en default.txt' Gray
    Say '  3. Instala ZombieBuddy y lo sustituye por el parche de Fix_ZombieBuddy_King' Gray
    Say '  4. Configura ProjectZomboid64.bat y ProjectZomboid64.json' Gray
    Say '  5. Crea un acceso directo en el Escritorio para lanzar con el .bat' Gray
    Say ''

    # --- Rutas ---
    Say '[1/7] Rutas...' Cyan

    $steamCmd = Find-SteamCMD
    if (-not $steamCmd) {
        $steamCmd = Install-SteamCMD
    } else {
        Say "    SteamCMD detectado: $steamCmd" Green
        $ans = Read-Host '    Usar esta ruta? (S/n)'
        if ($ans -match '^[nN]') {
            $steamCmd = Ask-Path 'Ruta completa a steamcmd.exe'
        }
    }
    if (-not (Test-ExistingPath $steamCmd)) {
        throw "No se encontro steamcmd.exe en: $steamCmd"
    }

    $gameDir = Find-GameDir
    if ($gameDir) {
        Say '    Carpeta de instalacion detectada:' Green
        Say "    $gameDir" White
        Say '    Es la carpeta del juego (ProjectZomboid64.exe), no la de mods ni la de partidas.' DarkGray
        $ans = Read-Host '    Usar esta carpeta? (S/n)'
        if ($ans -match '^[nN]') { $gameDir = $null }
    } else {
        Say '    No encontre sola la carpeta de instalacion de Project Zomboid.' Yellow
    }

    while (-not (Test-GameDir $gameDir)) {
        if ($gameDir) {
            Say ''
            Say "    '$gameDir' no es la carpeta del juego." Yellow
            Say '    Tiene que contener ProjectZomboid64.exe o ProjectZomboid64.bat.' Yellow
        }
        $picked = Select-GameFolder
        $resolved = Resolve-GameDir $picked
        if ($resolved -and ($resolved -ne $picked)) {
            Say '    Encontre el juego dentro de la carpeta que elegiste:' Green
            Say "    $resolved" White
        }
        if ($resolved) { $gameDir = $resolved } else { $gameDir = $picked }
    }
    Say "    Juego: $gameDir" Green

    $downloadRoot = Join-SafePath $env:TEMP 'PZViewpointWorkshop'
    Ensure-Dir $downloadRoot
    Ensure-Dir $LocalModsDir
    Ensure-Dir $StateDir

    # --- Descargas ---
    Say ''
    Say '[2/7] Descargando mods con SteamCMD (anonimo)...' Cyan
    Say '    Esto puede tardar varios minutos. No cierres la ventana.' DarkGray
    $downloaded = @{}
    foreach ($m in $Mods) {
        $path = Download-WorkshopItem $steamCmd $downloadRoot $m.Id $m.Name
        if ($path) { $downloaded[$m.Id] = $path }
    }

    if ($downloaded.Count -eq 0) {
        throw 'Ningun mod se pudo descargar. Prueba mas tarde o con login de Steam (ver instrucciones al final).'
    }

    # --- Instalar mods en Zomboid\mods ---
    Say ''
    Say '[3/7] Instalando mods en Zomboid\mods...' Cyan
    Say '    Copia cada mod a tu carpeta de usuario. Si ya estaba, primero borra esa copia.' DarkGray
    Say '    Los modelos 3D son muchos archivos y tardan. La marca | / - \ significa que sigue trabajando.' DarkGray
    $allCopied = @()
    foreach ($kv in $downloaded.GetEnumerator()) {
        $label = @($Mods | Where-Object { $_.Id -eq $kv.Key } | Select-Object -First 1).Name
        if (-not $label) { $label = $kv.Key }
        Say "    Paquete: $label" DarkGray
        $allCopied += Install-ModsFromWorkshop $kv.Value
    }
    if ($allCopied.Count -eq 0) {
        Say '    Advertencia: no se encontraron carpetas de mods dentro de las descargas.' Yellow
    }
    $defaultTxtExisted = Write-DefaultModList

    # --- ZombieBuddy files ---
    Say ''
    Say '[4/7] Instalando ZombieBuddy en la carpeta del juego...' Cyan
    $zb = Find-ZombieBuddyFiles @($downloaded.Values)
    if (-not $zb.Dll) { throw 'No se encontro zbNative.dll en las descargas de ZombieBuddy.' }
    if (-not $zb.Jar) { throw 'No se encontro ZombieBuddy.jar en las descargas.' }

    $targetDll = Join-SafePath $gameDir 'zbNative.dll'
    $targetJar = Join-SafePath $gameDir 'ZombieBuddy.jar'
    Copy-Item -LiteralPath $zb.Dll $targetDll -Force
    Copy-Item -LiteralPath $zb.Jar $targetJar -Force
    Say "    zbNative.dll  -> $targetDll" Green
    Say "    ZombieBuddy.jar -> $targetJar" Green
    Say '    Sustituyendo por las librerias parcheadas de Fix_ZombieBuddy_King...' Cyan
    Copy-ZombieBuddyPatch $gameDir $downloaded['3811151399']

    # --- Configurar bat + json ---
    Say ''
    Say '[5/7] Configurando lanzadores...' Cyan

    # RAM: 6 GB si el PC tiene >= 12 GB, 4 GB si tiene >= 8 GB
    $totalMB = [int]((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $ramMB = if ($totalMB -ge 12000) { 6144 } elseif ($totalMB -ge 7500) { 4096 } else { 3072 }
    Say "    RAM del sistema: ~$([math]::Round($totalMB/1024,1)) GB -> se usara -Xmx${ramMB}m" DarkGray

    $batOk  = Patch-Bat $gameDir
    $jsonOk = Patch-Json $gameDir $ramMB

    if (-not $batOk -and -not $jsonOk) {
        Say '    ADVERTENCIA: no se pudo modificar ni el .bat ni el .json.' Yellow
        Say '    Tendras que configurar el agent manualmente.' Yellow
    }

    # --- Acceso directo ---
    Say ''
    Say '[6/7] Creando acceso directo...' Cyan
    $shortcut = Create-Shortcut $gameDir

    # --- Guardar estado ---
    $state = @{
        gameDir     = $gameDir
        steamCmd    = $steamCmd
        downloaded        = @($downloaded.Keys)
        defaultTxtExisted = [bool]$defaultTxtExisted
        installedAt       = (Get-Date).ToString('o')
    }
    [IO.File]::WriteAllText($StateFile, ($state | ConvertTo-Json -Depth 4))

    # --- Final ---
    Say ''
    Say '[7/7] LISTO' Cyan
    Say ''
    Say '============================================================' Green
    Say '  INSTALACION COMPLETADA' Green
    Say '============================================================' Green
    Say ''
    Say 'COMO JUGAR A PARTIR DE AHORA:' White
    Say ''
    if ($shortcut) {
        Say '  1. Usa el acceso directo del Escritorio:' Cyan
        Say '       "Project Zomboid (Viewpoint)"' White
        Say '     (apunta al ProjectZomboid64.bat, no al .exe)' DarkGray
    } else {
        Say '  1. Ve a la carpeta del juego y ejecuta:' Cyan
        Say "       $gameDir\ProjectZomboid64.bat" White
    }
    Say ''
    Say '  2. Cuando arranque el juego, ZombieBuddy mostrara una ventana' Cyan
    Say '     pidiendo permiso para el mod Java de Viewpoint.' Cyan
    Say '     -> ACEPTA / ALLOW  (si no, no funcionara la primera persona)' Yellow
    Say ''
    Say '  3. Los mods ya quedan activos en Zomboid\mods\default.txt' Cyan
    Say '     (ZombieBuddy, ViewpointFurnitureFix, Viewpoint,' White
    Say '      Fix_ZombieBuddy_King y PZVoxelStudioViewpoint).' White
    Say '     En el menu Mods puedes confirmar que el preset Default los tiene.' DarkGray
    Say ''
    Say '  4. Carga una partida (nueva o existente). En juego:' Cyan
    Say '       - Tecla DELETE  = menu de Viewpoint (camara / shaders)' White
    Say '       - Tecla O       = cambiar entre ISO / 1a / 3a persona (segun config)' White
    Say ''
    Say 'NOTAS IMPORTANTES:' Yellow
    Say '  - NO lances el juego con el .exe normal si quieres Viewpoint.' DarkGray
    Say '  - Usa siempre el .bat o el acceso directo creado.' DarkGray
    Say '  - Si actualizas el juego, puede que haya que volver a correr este script.' DarkGray
    Say '  - Los backups de .bat y .json estan con extension .pvsetup.bak' DarkGray
    Say ''
    Say '------------------------------------------------------------' DarkGray
    Show-Credits
    Say ''
    if ($downloaded.Count -lt $Mods.Count) {
        Say 'ADVERTENCIA: algunos mods no se descargaron.' Yellow
        Say 'Puedes volver a ejecutar este script mas tarde o descargarlos a mano.' Yellow
        Say ''
    }
}

# =============================================================================
function Invoke-Reset {
    Say ''
    Say 'RESET: deshaciendo cambios de este instalador...' Yellow
    if (-not (Test-Path -LiteralPath $StateFile)) {
        Say 'No hay estado guardado. Nada que resetear automaticamente.' Yellow
        return
    }
    $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    $gameDir = $state.gameDir

    if ($gameDir -and (Test-Path -LiteralPath $gameDir)) {
        foreach ($f in @('zbNative.dll', 'ZombieBuddy.jar', 'ZombieBuddy.jar.new')) {
            $p = Join-SafePath $gameDir $f
            if (Test-Path -LiteralPath $p) {
                Remove-Item -LiteralPath $p -Force
                Say "Eliminado: $f" Green
            }
        }
        foreach ($f in @('ProjectZomboid64.bat', 'ProjectZomboid64.json')) {
            $orig = Join-SafePath $gameDir "$f.pvsetup.bak"
            $cur  = Join-SafePath $gameDir $f
            if (Test-Path -LiteralPath $orig) {
                Copy-Item -LiteralPath $orig $cur -Force
                Remove-Item -LiteralPath $orig -Force
                Say "Restaurado: $f" Green
            }
        }
    }

    $lnk = Join-SafePath ([Environment]::GetFolderPath('Desktop')) 'Project Zomboid (Viewpoint).lnk'
    if (Test-Path -LiteralPath $lnk) {
        Remove-Item -LiteralPath $lnk -Force
        Say 'Acceso directo eliminado.' Green
    }

    $defaultTxt = Join-SafePath $LocalModsDir 'default.txt'
    $defaultBak = "$defaultTxt.pvsetup.bak"
    if (Test-Path -LiteralPath $defaultBak) {
        Copy-Item -LiteralPath $defaultBak $defaultTxt -Force
        Remove-Item -LiteralPath $defaultBak -Force
        Say 'Restaurado: mods\default.txt' Green
    } elseif ($state.defaultTxtExisted -eq $false -and (Test-Path -LiteralPath $defaultTxt)) {
        Remove-Item -LiteralPath $defaultTxt -Force
        Say 'Eliminado: mods\default.txt (no existia antes del setup)' Green
    }

    # No borramos los mods de Zomboid\mods (el usuario puede quererlos)
    Say 'Los mods en Zomboid\mods NO se eliminan (puedes borrarlos a mano si quieres).' DarkGray
    Remove-Item -LiteralPath $StateDir -Recurse -Force -ErrorAction SilentlyContinue
    Say ''
    Say 'Reset terminado.' Cyan
}

# =============================================================================
# Menu
$choice = $null
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Project Viewpoint Setup (No-Steam)'
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(460, 292)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Instala Project Viewpoint + ZombieBuddy sin necesidad de tener el juego en Steam.`nDescarga los mods con SteamCMD y configura el lanzador (.bat)."
    $lbl.Location = New-Object System.Drawing.Point(15, 15)
    $lbl.Size = New-Object System.Drawing.Size(430, 55)
    $form.Controls.Add($lbl)

    $bSetup = New-Object System.Windows.Forms.Button
    $bSetup.Text = 'Setup (Instalar)'
    $bSetup.Location = New-Object System.Drawing.Point(30, 90)
    $bSetup.Size = New-Object System.Drawing.Size(160, 50)
    $bSetup.Add_Click({ $script:choice = 'setup'; $form.Close() })
    $form.Controls.Add($bSetup)

    $bReset = New-Object System.Windows.Forms.Button
    $bReset.Text = 'Reset (Deshacer)'
    $bReset.Location = New-Object System.Drawing.Point(250, 90)
    $bReset.Size = New-Object System.Drawing.Size(160, 50)
    $bReset.Add_Click({ $script:choice = 'reset'; $form.Close() })
    $form.Controls.Add($bReset)

    $credit = New-Object System.Windows.Forms.Label
    $credit.Text = "Autor: Yorlandiscuba, cubano. Hecho con la cuota de luz del dia.`nEstrella (no gasta corriente): github.com/Yorlandiscuba/Instalador-3d`nCreadores: compartan este link. Me ayuda a sobrevivir en la isla:`nhttps://link-center.net/8163108/9gBRbsulo3vJ"
    $credit.Location = New-Object System.Drawing.Point(15, 155)
    $credit.Size = New-Object System.Drawing.Size(430, 120)
    $form.Controls.Add($credit)

    $form.AcceptButton = $bSetup
    [void]$form.ShowDialog()
} catch {
    $a = Read-Host 'Escribe 1 para Setup o 2 para Reset'
    if ($a -eq '1') { $choice = 'setup' } elseif ($a -eq '2') { $choice = 'reset' }
}

try {
    switch ($choice) {
        'setup' { Invoke-Setup }
        'reset' { Invoke-Reset }
        default { Say 'Cancelado.' }
    }
} catch {
    Say ''
    Say "ERROR: $($_.Exception.Message)" Red
    Say ''
    Say 'Si SteamCMD falla con algunos mods, prueba mas tarde o con login de cuenta.' Yellow
}
