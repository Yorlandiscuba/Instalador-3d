# Project Viewpoint Setup (No-Steam / GOG / SteamCMD)

Instalador de Windows para [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528) y los mods que necesita, pensado para quien tiene Project Zomboid por GOG, en una carpeta propia, o sin querer abrir el cliente de Steam.

Todo el programa está en un solo archivo: [`Project-Viewpoint-Setup-NoSteam.bat`](Project-Viewpoint-Setup-NoSteam.bat). No baja otro script. No pide usuario ni contraseña de Steam.

El juego **no** se descarga. Tiene que estar ya instalado.

## Qué hace

1. Localiza SteamCMD, o lo instala desde el zip oficial de Valve si no está.
2. Localiza la carpeta de instalación de Project Zomboid (la del `.exe`, no la de partidas).
3. Con SteamCMD en modo anónimo, descarga 5 items públicos del Workshop del juego (AppID `108600`).
4. Copia esos mods a `%USERPROFILE%\Zomboid\mods`.
5. Escribe `%USERPROFILE%\Zomboid\mods\default.txt` para dejarlos activos al arrancar.
6. Copia `zbNative.dll` y `ZombieBuddy.jar` (salen del item de ZombieBuddy) junto al ejecutable del juego, y enseguida los sustituye por las copias parcheadas de `Zomboid\mods\Fix_ZombieBuddy_King\libs`. Esas son las que hacen que la última versión de Steam cargue los mods Java.
7. Ajusta `ProjectZomboid64.bat` y `ProjectZomboid64.json` para cargar el agente `zbNative` y, si hace falta, subir la RAM.
8. Crea en el Escritorio el acceso directo `Project Zomboid (Viewpoint).lnk`, que apunta al `.bat`.

## Qué no hace

- No descarga Project Zomboid.
- No inicia sesión con una cuenta de Steam. El único login es `+login anonymous`.
- No lee ni guarda contraseñas.
- No envía datos a ningún sitio que no sea la CDN de Valve (solo si falta SteamCMD) y los servidores de Steam a los que se conecta el propio `steamcmd.exe`.
- No borra partidas (`Zomboid\Saves`) ni la instalación del juego.
- No cambia la política de ejecución de PowerShell del sistema. `ExecutionPolicy Bypass` vale solo para el proceso que abre este `.bat`.

## Cómo usarlo

1. Instala Project Zomboid (Steam, GOG u otra carpeta).
2. Ejecuta `Project-Viewpoint-Setup-NoSteam.bat`.
3. Elige **Setup (Instalar)** o **Reset (Deshacer)**.
4. Si SteamCMD o el juego no se detectan solos, el script lo dice y abre el selector de carpetas de Windows.
5. Para jugar, usa el acceso directo del Escritorio o `ProjectZomboid64.bat`. El `.exe` normal no carga el agente de ZombieBuddy.
6. La primera vez, ZombieBuddy puede pedir permiso para el mod Java de Viewpoint. Hay que aceptarlo.

Requisito: Windows con PowerShell 5.1 (el que trae Windows 10/11) e internet durante la instalación.

## De dónde descarga

En el `.bat` solo hay una URL. El resto de las descargas las hace `steamcmd.exe`, que es el cliente de línea de comandos de Valve.

| Qué | Origen | Cuándo |
| --- | --- | --- |
| SteamCMD | [https://client-update.steamstatic.com/installer/steamcmd.zip](https://client-update.steamstatic.com/installer/steamcmd.zip) | Solo si no encuentra un `steamcmd.exe` ya instalado. Es el zip que documenta Valve en [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD). |
| Mods del Workshop | Servidores de Steam, vía SteamCMD | Siempre en el paso 2, con la cuenta anónima. |

El zip se guarda un momento en `%TEMP%\steamcmd.zip`, se descomprime en `steamcmd\` junto a este script y el zip se borra. Queda `steamcmd\steamcmd.exe`.

Cada mod se pide así (sin más argumentos):

```text
steamcmd.exe +login anonymous +force_install_dir %TEMP%\PZViewpointWorkshop +workshop_download_item 108600 <ID> +quit
```

`108600` es el AppID de Project Zomboid. El item queda en:

```text
%TEMP%\PZViewpointWorkshop\steamapps\workshop\content\108600\<ID>\
```

SteamCMD, al ejecutarse, también puede actualizarse solo desde los servidores de Steam. Eso lo hace el programa de Valve, no una URL escrita en este script.

Si un autor no permite la descarga anónima, ese mod falla y el script sigue con los demás. No hay un modo para meter usuario y contraseña.

## Mods que descarga

Items públicos del Workshop de Project Zomboid. El script no los renombra: copia las carpetas tal como vienen dentro del item.

| ID | Nombre en el script | Página del Workshop |
| --- | --- | --- |
| `3619862853` | ZombieBuddy | [enlace](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853) |
| `3809306528` | Project Viewpoint | [enlace](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528) |
| `3810302175` | 3D models for Viewpoint | [enlace](https://steamcommunity.com/sharedfiles/filedetails/?id=3810302175) |
| `3811151399` | Fix_ZombieBuddy_King | [enlace](https://steamcommunity.com/sharedfiles/filedetails/?id=3811151399) |
| `3811400314` | Project ViewPoint: 3D Interiors & Native Aim | [enlace](https://steamcommunity.com/sharedfiles/filedetails/?id=3811400314) |

El id de la página del Workshop y el id interno del mod (el de `mod.info`, que es el que va en `default.txt`) son cosas distintas. Esos ids internos están en la sección [`default.txt`](#defaulttxt).

## Pasos del Setup

### 1/7. Rutas

**SteamCMD.** No usa letras de disco fijas. Mira solo unidades que estén conectadas en ese PC, en este orden:

- `steamcmd\steamcmd.exe` junto a este script
- `%USERPROFILE%\steamcmd\steamcmd.exe`
- `%USERPROFILE%\Desktop\steamcmd\steamcmd.exe`
- `<unidad>:\steamcmd\steamcmd.exe` en cada disco presente (`C:`, `D:`, etc.)

Si no hay ninguno, descarga el zip oficial descrito arriba. Si respondes que no a la ruta detectada, puedes escribir otra a mano.

**Carpeta del juego.** En cada disco conectado busca `ProjectZomboid64.exe` o `ProjectZomboid64.bat` bajo `Steam\steamapps\common\ProjectZomboid`, `SteamLibrary\...`, `GOG Games\Project Zomboid`, `Games\Project Zomboid` y `Program Files\Steam\...`. También lee `HKCU\Software\Valve\Steam` (`SteamPath`, solo lectura) y `steamapps\libraryfolders.vdf`. Una biblioteca que apunte a un disco que ya no existe se ignora.

Si la encuentra, pregunta si esa es la correcta. Si no, abre el cuadro **Seleccionar carpeta** del Explorador. Tiene que ser la carpeta de instalación, no `Documentos\Zomboid` ni `Zomboid\mods`. Si eliges una carpeta padre y dentro solo hay una instalación, usa esa.

### 2/7. Descarga del Workshop

Lanza SteamCMD una vez por cada id de la tabla, con `+login anonymous`. Puede tardar varios minutos. Un fallo no corta el resto. Si no se baja ninguno, el script se detiene.

### 3/7. Copia a `Zomboid\mods`

No descarga nada aquí. Copia carpetas en el disco.

De cada item bajado toma la subcarpeta `mods`. Si no existe, usa la carpeta del item. Cada subcarpeta se copia a:

```text
%USERPROFILE%\Zomboid\mods\<nombre>
```

Si ese destino ya existía, lo borra entero y copia la versión nueva. Los mods de modelos 3D tienen muchos archivos, así que tarda. Mientras borra o copia, la consola mueve `| / - \`.

Después escribe `default.txt` (ver más abajo). Si ya existía, deja una copia `default.txt.pvsetup.bak` la primera vez.

### 4/7. ZombieBuddy dentro del juego

Busca dentro de lo descargado, no en internet:

- `zbNative.dll` (la última que encuentre)
- `ZombieBuddy.jar` (la primera que encuentre)

Los copia a la carpeta del juego, al lado de `ProjectZomboid64.exe`:

- `<juego>\zbNative.dll`
- `<juego>\ZombieBuddy.jar`

Si falta uno de los dos, se detiene. No los sustituye por una descarga directa.

Después, en el mismo paso, los pisa con el parche de la comunidad. Esos archivos no se bajan de otra web: salen del mod `Fix_ZombieBuddy_King` que ya se copió a la carpeta de mods:

- `%USERPROFILE%\Zomboid\mods\Fix_ZombieBuddy_King\libs\zbNative.dll`
- `%USERPROFILE%\Zomboid\mods\Fix_ZombieBuddy_King\libs\ZombieBuddy.jar`

Van otra vez a `<juego>\zbNative.dll` y `<juego>\ZombieBuddy.jar`. Sin este reemplazo, la última versión de Steam no carga los mods Java. Si esa carpeta `libs` no está, el script se detiene.

### 5/7. Lanzadores

Lee la RAM con `Win32_ComputerSystem.TotalPhysicalMemory` (solo lectura) y elige un mínimo:

| RAM del PC | `-Xmx` que exige |
| --- | --- |
| 12 GB o más | 6144 MB |
| 8 GB o más (desde unos 7,5 GB) | 4096 MB |
| Menos | 3072 MB |

`ProjectZomboid64.bat`: deja `SET _JAVA_OPTIONS=-agentlib:zbNative`. Si esa línea ya existía, la reemplaza. Si no, la pone al principio.

`ProjectZomboid64.json`: añade `"-agentlib:zbNative"` al inicio de `vmArgs` si no estaba. Sube `-Xmx` solo cuando el valor actual es menor. No lo baja. Si el texto dejara de ser JSON válido, no guarda el archivo.

Antes de tocar cada uno, si no hay backup, copia el original a `ProjectZomboid64.bat.pvsetup.bak` y `ProjectZomboid64.json.pvsetup.bak` en la misma carpeta del juego.

### 6/7. Acceso directo

Crea en el Escritorio `Project Zomboid (Viewpoint).lnk`.

- Destino: `<juego>\ProjectZomboid64.bat`
- Carpeta de trabajo: la del juego
- Icono: `ProjectZomboid64.exe`, si existe

### 7/7. Estado

Guarda `%LOCALAPPDATA%\ProjectViewpointSetupNoSteam\state.json` con la carpeta del juego, la ruta de SteamCMD, los ids descargados, si `default.txt` ya existía y la fecha. Reset lo usa para deshacer. No incluye contraseñas.

## `default.txt`

Ruta: `%USERPROFILE%\Zomboid\mods\default.txt`. Es el preset Default de Project Zomboid. El script lo reemplaza por completo con:

```text
VERSION = 1,

mods
{
    mod = ZombieBuddy,
    mod = ViewpointFurnitureFix,
    mod = Viewpoint,
    mod = Fix_ZombieBuddy_King,
    mod = PZVoxelStudioViewpoint,
}

maps
{
}
```

Otros mods que tuvieras en ese preset dejan de estar en la lista. El archivo anterior queda en `default.txt.pvsetup.bak` si existía.

## Reset

El botón **Reset (Deshacer)** usa `state.json` y:

- Borra `zbNative.dll`, `ZombieBuddy.jar` y `ZombieBuddy.jar.new` de la carpeta del juego.
- Restaura `ProjectZomboid64.bat` y `ProjectZomboid64.json` desde su `.pvsetup.bak`, y borra el backup.
- Borra el acceso directo del Escritorio.
- Restaura `default.txt` desde su backup, o lo borra si el Setup lo había creado y antes no existía.
- Borra la carpeta `ProjectViewpointSetupNoSteam`.

No borra las carpetas de mods en `Zomboid\mods`. Esas hay que quitarlas a mano si no se quieren.

## Cómo auditarlo

El archivo es texto. Ábrelo y busca:

| Buscar | Para ver |
| --- | --- |
| `https://` | La única URL: el zip de SteamCMD. |
| `Invoke-WebRequest` | La única descarga hecha por el script (ese zip). |
| `+login` | Tiene que decir `anonymous`. No hay otro login. |
| `workshop_download_item` | AppID `108600` y los cinco ids de la tabla. |
| `zbNative` | Dónde se copia la DLL/JAR y dónde se añade el agente Java. |
| `Remove-Item` | Borrados: copia vieja de un mod, el zip temporal, y lo que deshace Reset. |
| `WriteAllText` | `default.txt`, los lanzadores del juego y `state.json`. |
| `HKCU:` | Una lectura de `SteamPath` para encontrar el juego. |

El `.bat` no llama a PowerShell remoto. Las primeras líneas leen **este mismo archivo**, cortan por la marca `#PSSTART#` y ejecutan ese texto:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath '%~f0' -Raw) -split ('#PS'+'START#'))[1]"
```

`%~f0` es la ruta de este `.bat`. `PV_SETUP_DIR` es su carpeta, porque al ejecutarlo así PowerShell no rellena `$PSScriptRoot`.
