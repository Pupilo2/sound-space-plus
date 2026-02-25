# 11 - Plugins y Addons

## Indice

1. [Vision general](#vision-general)
2. [Tabla de addons](#tabla-de-addons)
3. [Discord Game SDK](#discord-game-sdk)
4. [godot-openvr](#godot-openvr)
5. [native_dialogs](#native_dialogs)
6. [Configuracion en project.godot](#configuracion-en-projectgodot)
7. [Diagrama de dependencias](#diagrama-de-dependencias)

---

## Vision general

Sound Space Plus (Rhythia) integra tres addons nativos de Godot 3.x que extienden la funcionalidad del motor para ofrecer:

- **Presencia en Discord** mediante el SDK oficial de Discord Game.
- **Soporte de realidad virtual** a traves de OpenVR/SteamVR.
- **Dialogos nativos del sistema operativo** para seleccion de archivos, carpetas y mensajes.

Cada addon reside en `addons/` y se activa a traves de `plugin.cfg` o configuracion directa en `project.godot`. Solo Discord Game SDK se registra como autoload global; OpenVR se carga como singleton de GDNative y native_dialogs provee tipos personalizados al editor.

---

## Tabla de addons

| Addon | Directorio | Proposito | Autoload | Activacion |
|---|---|---|---|---|
| Discord Game SDK | `addons/discord_game_sdk/` | Rich Presence, lobbies, overlay de Discord | `Discord` (global) | `plugin.cfg` + autoload en `project.godot` |
| Godot OpenVR | `addons/godot-openvr/` | Soporte VR via OpenVR/SteamVR | No (singleton GDNative) | `plugin.cfg` + `gdnative/singletons` |
| Native Dialogs | `addons/native_dialogs/` | Dialogos nativos del SO (archivos, carpetas, mensajes) | No (tipos personalizados) | Uso directo en escenas |

---

## Discord Game SDK

### Archivo principal: `discord.gd`

**Ruta:** `addons/discord_game_sdk/discord.gd`
**Autoload:** Registrado como `Discord` en el arbol de escenas global.

Este script extiende `Node` y actua como punto de acceso unico al SDK de Discord. Encapsula toda la comunicacion con el cliente de Discord mediante clases proxy internas.

### Inicializacion

```gdscript
func _ready():
    if ProjectSettings.get_setting("application/config/discord_rpc"):
        discore_core_ = DiscordCore.new()
        if discore_core_:
            discore_core_.create(1231699688340590722, CreateFlags.NoRequireDiscord)

            activity_manager = ActivityManager_.new(discore_core_.get_activity_manager())
            lobby_manager = LobbyManager_.new(discore_core_.get_lobby_manager())
            overlay_manager = OverlayManager_.new(discore_core_.get_overlay_manager())
```

La inicializacion depende de la configuracion `application/config/discord_rpc` en `project.godot`. Si esta desactivada (por ejemplo en movil, HTML5 o macOS), el core no se crea y los managers quedan nulos. El flag `NoRequireDiscord` permite que el juego funcione aunque Discord no este instalado.

El ID de aplicacion de Discord es `1231699688340590722`.

### Arquitectura de clases proxy

`discord.gd` define un patron Proxy para envolver los objetos nativos de GDNative:

```
Proxy_ (base)
  +-- User              -> DiscordUser
  +-- LobbyTransaction  -> DiscordLobbyTransaction
  +-- Activity           -> DiscordActivity
  +-- ActivityManager_   -> DiscordActivityManager (senales: activity_join, activity_invite, activity_join_request)
  +-- LobbyManager_      -> DiscordLobbyManager (senales: lobby_message, member_connect)
  +-- OverlayManager_    -> DiscordOverlayManager
```

La clase `Proxy_` base proporciona `call_()` y `callback_()` que verifican si el objeto nativo existe antes de invocar metodos, evitando errores cuando Discord no esta disponible.

### Enumeraciones

| Enum | Descripcion |
|---|---|
| `Result` | Codigos de resultado del SDK (Ok, ServiceUnavailable, InternalError, etc.) |
| `CreateFlags` | Flags de creacion: `Default` (0), `NoRequireDiscord` (1) |
| `ActivityType` | Tipo de actividad: Playing, Streaming, Listening, Watching |
| `ActivityActionType` | Acciones de actividad: Join, Spectate |
| `LobbyType` | Tipo de lobby: Private, Public |

### Rich Presence: estados del juego

El juego actualiza la presencia de Discord en varios momentos:

| Contexto | Script | Details | State |
|---|---|---|---|
| Inicializacion | `scripts/init.gd` | "Initialization" | "Starting the game" / "Reloading content" / "Mass-converting songs" |
| Menu principal | `scripts/ui/menu/menu2.gd` | "Main Menu" | "Selecting a song" |
| Menu (idle 5 min) | `scripts/ui/menu/menu2.gd` | "Main Menu" | "Listening to music" |
| Jugando | `scripts/Rhythia.gd` | Nombre de la cancion | Modificadores activos (o "No modifiers") |
| Content Manager | `scripts/ui/cmgr/contentmgr.gd` | "Content Manager" | Estado variable |

Todos los estados usan `icon-bg` como imagen grande del asset.

**Ejemplo de actualizacion de actividad (en `menu2.gd`):**

```gdscript
if ProjectSettings.get_setting("application/config/discord_rpc"):
    var activity = Discord.Activity.new()
    activity.set_type(Discord.ActivityType.Playing)
    activity.set_details("Main Menu")
    activity.set_state("Selecting a song")

    var assets = activity.get_assets()
    assets.set_large_image("icon-bg")

    Discord.activity_manager.update_activity(activity)
```

### Managers expuestos

| Manager | Variable | Funcionalidad |
|---|---|---|
| `ActivityManager_` | `Discord.activity_manager` | Actualizar/limpiar actividad, registrar comandos |
| `LobbyManager_` | `Discord.lobby_manager` | Crear lobbies, enviar mensajes, obtener miembros |
| `OverlayManager_` | `Discord.overlay_manager` | Abrir invitaciones de actividad en el overlay |

### Callbacks y procesamiento

```gdscript
func _process(delta:float) -> void:
    if discore_core_:
        discore_core_.run_callbacks()
```

`run_callbacks()` se ejecuta cada frame para procesar eventos pendientes del SDK de Discord.

### Estructura del addon

```
addons/discord_game_sdk/
  discord.gd                         # Script principal (autoload "Discord")
  plugin.gd                          # Registra el autoload en el editor
  plugin.cfg                         # Metadatos del plugin (autor: samsface)
  discord_sdk.gdnlib                 # Biblioteca nativa multiplataforma
  discord-game-sdk-godot.dll         # Binario Windows
  libdiscord-game-sdk-godot.dylib    # Binario macOS
  libdiscord-game-sdk-godot.so       # Binario Linux
  libdiscord_game_sdk.so             # Biblioteca compartida del SDK
  discord_core.gdns                  # NativeScript: DiscordCore
  discord_activity.gdns              # NativeScript: DiscordActivity
  discord_activity_assets.gdns       # NativeScript: DiscordActivityAssets
  discord_activity_manager.gdns      # NativeScript: DiscordActivityManager
  discord_activity_party.gdns        # NativeScript: DiscordActivityParty
  discord_activity_secrets.gdns      # NativeScript: DiscordActivitySecrets
  discord_activity_timestamps.gdns   # NativeScript: DiscordActivityTimestamps
  discord_lobby.gdns                 # NativeScript: DiscordLobby
  discord_lobby_manager.gdns         # NativeScript: DiscordLobbyManager
  discord_lobby_transaction.gdns     # NativeScript: DiscordLobbyTransaction
  discord_overlay_manager.gdns       # NativeScript: DiscordOverlayManager
  discord_party_size.gdns            # NativeScript: DiscordPartySize
  discord_result.gdns                # NativeScript: DiscordResult
  discord_user.gdns                  # NativeScript: DiscordUser
  example/
    rich_presence/                   # Ejemplo de Rich Presence
      rich_presence.gd
      rich_presence.tscn
    lobby/                           # Ejemplo de sistema de lobbies
      lobby.gd, lobby.tscn, ...
```

---

## godot-openvr

### Descripcion

Plugin de OpenVR/SteamVR para Godot 3.x. Permite que el juego funcione con cascos de realidad virtual compatibles con SteamVR (Valve Index, HTC Vive, Oculus via SteamVR, Windows Mixed Reality, etc.).

**Autor:** Bastiaan Olij y contribuidores
**Version:** 1.1.0

> Para documentacion detallada del sistema VR del juego, consultar [10-vr.md](10-vr.md).

### Inicializacion VR (`ovr_main.gd`)

El script `ovr_main.gd` extiende `ARVROrigin` y se encarga de:

1. Cargar la configuracion de OpenVR (`OpenVRConfig.gdns`).
2. Buscar la interfaz "OpenVR" en `ARVRServer`.
3. Activar el modo ARVR en el viewport.
4. Desactivar vsync (necesario para no limitar a 60fps).
5. Ajustar la tasa de fisicas al refresh rate del HMD.

```gdscript
export (String) var default_action_set = "/actions/godot"
export (NodePath) var viewport = null
export var physics_factor = 2
```

### Sistema de acciones VR

Las acciones se definen en `addons/godot-openvr/actions/actions.json`:

| Accion | Tipo | Requerimiento |
|---|---|---|
| `/actions/godot/in/trigger` | boolean | mandatory |
| `/actions/godot/in/analog_trigger` | vector1 | suggested |
| `/actions/godot/in/grip` | boolean | suggested |
| `/actions/godot/in/analog_grip` | vector1 | suggested |
| `/actions/godot/in/analog` | vector2 | suggested |
| `/actions/godot/in/analog_click` | boolean | suggested |
| `/actions/godot/in/button_ax` | boolean | optional |
| `/actions/godot/in/button_by` | boolean | optional |
| `/actions/godot/out/haptic` | vibration | optional |
| `/actions/godot/in/left_hand` | skeleton | - |
| `/actions/godot/in/right_hand` | skeleton | - |

### Bindings por controlador

El addon incluye archivos de bindings para cada tipo de controlador:

| Archivo | Controlador |
|---|---|
| `bindings_index_controller.json` | Valve Index (Knuckles) |
| `bindings_oculus_touch.json` | Oculus Touch |
| `bindings_vive_controller.json` | HTC Vive |
| `bindings_holographic_controller.json` | Windows Mixed Reality |
| `bindings_generic.json` | Controlador generico |
| `bindings_gamepad.json` | Gamepad |

### Busqueda de `actions.json`

El plugin busca el archivo de acciones en este orden de prioridad:

1. Carpeta `actions/` junto al ejecutable.
2. `res://actions/actions.json` dentro del proyecto.
3. `res://addons/godot-openvr/actions/actions.json` (ubicacion por defecto del addon).

OpenVR no puede leer archivos dentro del paquete exportado, por lo que `OpenVRExportPlugin.gd` copia automaticamente los archivos de acciones a la carpeta de exportacion.

### Escenas y scripts incluidos

| Escena/Script | Descripcion |
|---|---|
| `ovr_main.gd` / `ovr_first_person.tscn` | Inicializacion VR y configuracion de ARVROrigin |
| `ovr_controller.gd` / `ovr_controller.tscn` | Controlador VR con visibilidad automatica |
| `ovr_render_model.gd` / `ovr_render_model.tscn` | Carga dinamica del mesh 3D del controlador |
| `ovr_shader_cache.gd` / `ovr_shader_cache.tscn` | Cache de shaders (se oculta tras 2 frames) |
| `ovr_left_hand.tscn` / `ovr_right_hand.tscn` | Modelos de manos VR |
| `framecounter_in_3d.tscn` | Contador de frames en 3D |

### Estructura del addon

```
addons/godot-openvr/
  EditorPlugin.gd              # Plugin del editor, registra el export plugin
  OpenVRExportPlugin.gd        # Copia archivos de acciones al exportar
  plugin.cfg                   # Metadatos del plugin
  godot_openvr.gdnlib          # Biblioteca nativa (singleton GDNative)
  OpenVRConfig.gdns            # Configuracion de OpenVR
  OpenVRAction.gdns            # Acciones VR
  OpenVRController.gdns        # Controlador VR
  OpenVRHaptics.gdns           # Retroalimentacion haptica
  OpenVROverlay.gdns           # Overlay VR
  OpenVRPose.gdns              # Pose/posicion del dispositivo
  OpenVRRenderModel.gdns       # Modelo de render del controlador
  OpenVRSkeleton.gdns          # Skeleton de mano
  actions/                     # Definiciones de acciones y bindings
    actions.json
    bindings_*.json
  bin/                         # Binarios nativos
    win64/                     # libgodot_openvr.dll, openvr_api.dll
    x11/                       # libgodot_openvr.so, libopenvr_api.so
    osx/                       # (vacio, referencia README)
  meshes/                      # Modelos 3D de manos VR
  scenes/                      # Escenas y scripts prefabricados
```

---

## native_dialogs

### Descripcion

Plugin que permite interactuar con dialogos nativos del sistema operativo, reemplazando los dialogos de archivos internos de Godot con la experiencia nativa de cada plataforma.

**Autor:** Teggy
**Version:** 1.0.0

### Tipos de dialogos disponibles

El addon expone cinco tipos personalizados de nodo a traves de `plugin.gd`:

| Tipo de nodo | Script nativo | Funcion |
|---|---|---|
| `NativeDialogMessage` | `native_dialog_message.gdns` | Dialogos de mensaje (OK, OK/Cancel, Yes/No, etc.) |
| `NativeDialogNotify` | `native_dialog_notify.gdns` | Notificaciones del sistema |
| `NativeDialogOpenFile` | `native_dialog_open_file.gdns` | Dialogo para abrir archivos |
| `NativeDialogSaveFile` | `native_dialog_save_file.gdns` | Dialogo para guardar archivos |
| `NativeDialogSelectFolder` | `native_dialog_select_folder.gdns` | Dialogo para seleccionar carpeta |

### Enumeraciones (`native_dialogs.gd`)

```gdscript
enum MessageChoices { OK, OK_CANCEL, YES_NO, YES_NO_CANCEL }
enum MessageIcons { INFO, WARNING, ERROR, QUESTION }
enum MessageResults { OK, CANCEL, YES, NO }
enum NotifyIcons { INFO, WARNING, ERROR }
```

### Integracion con FileSelector.gd

El script `scripts/ui/FileSelector.gd` (clase `FileSelector2D`) utiliza native_dialogs como mecanismo principal de seleccion de archivos, con un fallback a los dialogos internos de Godot:

```gdscript
func _ready():
    if (
        !ProjectSettings.get_setting("application/config/disable_native_file_dialogs") and
        $OpenFile.has_signal("files_selected") and
        $SaveFile.has_signal("file_selected") and
        $Folder.has_signal("folder_selected")
    ):
        use_native = true
        # Conecta senales de dialogos nativos
    else:
        # Usa dialogos internos de Godot como fallback
```

**Logica de seleccion:**

1. Si `disable_native_file_dialogs` es `false` Y los nodos nativos existen con las senales esperadas: usa dialogos nativos.
2. En caso contrario (movil, web, macOS, o si el plugin no esta disponible): usa `FileDialog` de Godot.

Los metodos expuestos por `FileSelector2D` son:

| Metodo | Parametros | Funcion |
|---|---|---|
| `open_file()` | obj, method, filters, multiselect, initial_path | Abre dialogo para seleccionar archivos |
| `save_file()` | obj, method, filters, initial_path | Abre dialogo para guardar un archivo |
| `open_folder()` | obj, method, initial_path | Abre dialogo para seleccionar carpeta |

### Soporte multiplataforma

La configuracion en `project.godot` desactiva los dialogos nativos en plataformas donde no funcionan:

| Plataforma | `disable_native_file_dialogs` |
|---|---|
| Desktop (Windows/Linux) | `false` (usa nativos) |
| Android | `true` (usa fallback Godot) |
| Web/HTML5 | `true` (usa fallback Godot) |
| macOS | `true` (usa fallback Godot) |

### Estructura del addon

```
addons/native_dialogs/
  native_dialogs.gd            # Constantes y enumeraciones
  plugin.gd                    # Registro de tipos personalizados en el editor
  plugin.cfg                   # Metadatos del plugin
  bin/
    native_dialogs.gdnlib      # Biblioteca nativa multiplataforma
    native_dialog_message.gdns
    native_dialog_notify.gdns
    native_dialog_open_file.gdns
    native_dialog_save_file.gdns
    native_dialog_select_folder.gdns
    win64/libnativedialogs.dll  # Binario Windows
    x11/libnativedialogs.so     # Binario Linux
    osx/libnativedialogs.dylib  # Binario macOS
  icons/                        # Iconos para el editor de Godot
```

---

## Configuracion en project.godot

### Autoloads

```ini
[autoload]
Discord="*res://addons/discord_game_sdk/discord.gd"
```

Discord es el unico addon registrado como autoload. El asterisco (`*`) indica que se carga automaticamente al iniciar el juego.

### Plugins del editor

```ini
[editor_plugins]
enabled=PoolStringArray( "res://addons/discord_game_sdk/plugin.cfg", "res://addons/godot-openvr/plugin.cfg" )
```

Nota: `native_dialogs` no esta en la lista de plugins habilitados del editor; sus nodos se instancian directamente en escenas (por ejemplo en `prefabs/menu/filesel.tscn`).

### Singletons GDNative

```ini
[gdnative]
singletons=[ "res://addons/godot-openvr/godot_openvr.gdnlib" ]
```

OpenVR se registra como singleton de GDNative, lo que permite que la interfaz "OpenVR" este disponible en `ARVRServer`.

### Configuracion de Discord RPC por plataforma

```ini
[application]
config/discord_rpc=true
config/discord_rpc.editor=true
config/discord_rpc.OSX=false
config/discord_rpc.mobile=false
config/discord_rpc.HTML5=false
```

| Plataforma | Discord RPC |
|---|---|
| Windows / Linux | Activado |
| Editor | Activado |
| macOS | Desactivado |
| Movil (Android/iOS) | Desactivado |
| HTML5 / Web | Desactivado |

### Seccion de presencia de Discord

```ini
[discord_presence]
first_button/label="go to godot's website lol"
settings/change_time_per_screen=true
```

Esta seccion define parametros adicionales para la presencia de Discord, incluyendo botones y comportamiento de timestamps.

### Configuracion de dialogos nativos

```ini
config/disable_native_file_dialogs=false
config/disable_native_file_dialogs.Android=true
config/disable_native_file_dialogs.web=true
config/disable_native_file_dialogs.OSX=true
```

---

## Diagrama de dependencias

```
project.godot
  |
  |-- [autoload] Discord ---------> addons/discord_game_sdk/discord.gd
  |                                    |
  |                                    +-- DiscordCore (discord_core.gdns)
  |                                    +-- DiscordActivity (discord_activity.gdns)
  |                                    +-- DiscordActivityManager (discord_activity_manager.gdns)
  |                                    +-- DiscordLobbyManager (discord_lobby_manager.gdns)
  |                                    +-- DiscordOverlayManager (discord_overlay_manager.gdns)
  |                                    +-- discord_sdk.gdnlib (DLL/SO/DYLIB)
  |                                    |
  |                                    +-- Usado por:
  |                                         scripts/init.gd
  |                                         scripts/Rhythia.gd
  |                                         scripts/ui/menu/menu2.gd
  |                                         scripts/ui/cmgr/contentmgr.gd
  |
  |-- [gdnative singleton] -------> addons/godot-openvr/godot_openvr.gdnlib
  |                                    |
  |                                    +-- ARVRServer.find_interface("OpenVR")
  |                                    +-- OpenVRConfig.gdns
  |                                    +-- OpenVRAction.gdns
  |                                    +-- scenes/ovr_main.gd (ARVROrigin)
  |                                    +-- scenes/ovr_controller.gd (ARVRController)
  |                                    +-- actions/actions.json + bindings
  |                                    +-- bin/ (DLL/SO por plataforma)
  |
  |-- [tipos personalizados] -----> addons/native_dialogs/
  |                                    |
  |                                    +-- NativeDialogOpenFile
  |                                    +-- NativeDialogSaveFile
  |                                    +-- NativeDialogSelectFolder
  |                                    +-- NativeDialogMessage
  |                                    +-- NativeDialogNotify
  |                                    +-- native_dialogs.gdnlib (DLL/SO/DYLIB)
  |                                    |
  |                                    +-- Usado por:
  |                                         scripts/ui/FileSelector.gd
  |                                         prefabs/menu/filesel.tscn
  |
  +-- [configuracion]
       application/config/discord_rpc          -> Activa/desactiva Discord
       application/config/disable_native_file_dialogs -> Activa/desactiva dialogos nativos
       discord_presence/*                      -> Parametros de Rich Presence
```

### Flujo de datos entre addons y el juego

```
+-------------------+       +------------------+       +-------------------+
|   Scripts del     |       |    Discord       |       |   Cliente de      |
|   juego           | ----> |    (autoload)    | ----> |   Discord         |
|   (init, menu,    |       |    discord.gd    |       |   (Rich Presence) |
|    Rhythia, cmgr) |       +------------------+       +-------------------+
+-------------------+
        |
        |               +------------------+       +-------------------+
        |               |   ARVRServer     |       |   SteamVR /       |
        +-------------> |   (OpenVR)       | ----> |   OpenVR Runtime  |
        |               |   godot_openvr   |       +-------------------+
        |               +------------------+
        |
        |               +------------------+       +-------------------+
        |               |   FileSelector2D |       |   Dialogo nativo  |
        +-------------> |   FileSelector.gd| ----> |   del SO          |
                        |   (usa native_   |       |   (o fallback     |
                        |    dialogs)      |       |    Godot)         |
                        +------------------+       +-------------------+
```

---

## Notas adicionales

- Los tres addons utilizan **GDNative** (`.gdnlib` + `.gdns`) para acceder a bibliotecas nativas en C/C++, lo que permite funcionalidad que no esta disponible directamente en GDScript.
- Cada addon incluye binarios precompilados para **Windows** (`.dll`), **Linux** (`.so`) y **macOS** (`.dylib`).
- La configuracion por plataforma en `project.godot` (sufijos como `.mobile`, `.HTML5`, `.OSX`) permite desactivar funcionalidades que no aplican en ciertos entornos.
- El plugin de Discord usa un patron de **tolerancia a fallos**: si Discord no esta instalado o el core falla, los managers proxy simplemente devuelven codigos de error sin interrumpir el juego.
