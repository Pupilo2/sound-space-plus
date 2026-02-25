# 13 - Escenas y Cargadores

> Documentacion de arquitectura para **Sound Space Plus (Rhythia)** - Motor: Godot 3.x

---

## Indice

1. [Vision general](#vision-general)
2. [Escenas principales](#escenas-principales)
   - [init.tscn (Punto de entrada)](#inittscn-punto-de-entrada)
   - [Intro.tscn (Secuencia de introduccion)](#introtscn-secuencia-de-introduccion)
   - [menu2.tscn (Menu principal)](#menu2tscn-menu-principal)
   - [song.tscn (Gameplay)](#songtscn-gameplay)
   - [Escenas secundarias del menu](#escenas-secundarias-del-menu)
3. [Escenas de carga (loaders/)](#escenas-de-carga-loaders)
   - [menuload.tscn - Carga del menu](#menuloadtscn---carga-del-menu)
   - [songload.tscn - Carga de cancion](#songloadtscn---carga-de-cancion)
   - [contentmgrload.tscn - Carga del content manager](#contentmgrloadtscn---carga-del-content-manager)
   - [Patron comun de los loaders](#patron-comun-de-los-loaders)
4. [Scripts de loaders (scripts/loaders/)](#scripts-de-loaders-scriptsloaders)
   - [menuload.gd](#menuloadgd)
   - [songload.gd](#songloadgd)
   - [contentmgrload.gd](#contentmgrloadgd)
   - [Uso de ResourceQueue (RQueue)](#uso-de-resourcequeue-rqueue)
5. [Escenas de error (errors/)](#escenas-de-error-errors)
   - [Tabla de escenas de error](#tabla-de-escenas-de-error)
   - [Patron comun de errores](#patron-comun-de-errores)
   - [DeleteSettingsFile.gd](#deletesettingsfilegd)
6. [Prefabs reutilizables (prefabs/)](#prefabs-reutilizables-prefabs)
7. [Escenas de test (scenes/test/)](#escenas-de-test-scenestest)
8. [Flujo de navegacion completo](#flujo-de-navegacion-completo)
   - [Diagrama de navegacion](#diagrama-de-navegacion)
   - [Tabla completa de escenas](#tabla-completa-de-escenas)

---

## Vision general

Sound Space Plus organiza su flujo de escenas en tres grandes categorias:

| Categoria | Directorio | Funcion |
|-----------|------------|---------|
| **Escenas principales** | `scenes/` y `scenes/menu/` | Pantallas de juego y menus |
| **Cargadores (loaders)** | `scenes/loaders/` | Transiciones con precarga asincrona de recursos |
| **Escenas de error** | `scenes/errors/` | Pantallas de error con informacion diagnostica |

La navegacion entre escenas nunca es directa: siempre se pasa por una **escena loader intermedia** que se encarga de:

1. Mostrar una pantalla de carga (fondo negro con spinner animado).
2. Encolar el recurso destino en `RQueue` (ResourceQueue) para carga asincrona en hilo separado.
3. Aplicar un **fade out** (oscurecimiento gradual).
4. Verificar que el recurso se cargo correctamente.
5. Cambiar a la escena destino con `change_scene_to()`.

Si ocurre un error en cualquier punto, el flujo se redirige a la escena de error correspondiente en `scenes/errors/`.

Ademas, el proyecto utiliza **prefabs** (`prefabs/`) como componentes de escena reutilizables que se instancian dentro de las escenas principales.

---

## Escenas principales

### init.tscn (Punto de entrada)

- **Ruta**: `scenes/init.tscn`
- **Script**: `scripts/init.gd`
- **Tipo raiz**: `ColorRect` (fondo negro)
- **Rol**: Es la `main_scene` del proyecto (definida en `project.godot`). Se ejecuta al iniciar el juego.

**Estructura de nodos:**

| Nodo | Tipo | Proposito |
|------|------|-----------|
| `Label` | Label | Texto "Loading" |
| `Label2` | Label | Texto de estado actual (p.ej. "Waiting for engine") |
| `VersionNumber` | Label | Muestra version de Rhythia (con script `VersionNumber.gd`) |
| `Spinner` | ReferenceRect | Animacion de carga (8 bloques que parpadean en secuencia) |
| `Patreon` | ReferenceRect | Lista de patrons (script `LSPatronList.gd`) |
| `BlackFade` | ColorRect | Overlay para efecto de fade in/out |
| `Music` | AudioStreamPlayer | Musica opcional de carga |

**Flujo de init.gd:**

```gdscript
func _ready():
    # 1. Despausa el arbol
    get_tree().paused = false

    # 2. Conecta senal de progreso de inicializacion
    Rhythia.connect("init_stage_reached", self, "stage")

    # 3. Si ya esta inicializado, salta directo a cargar menu
    if not Rhythia.is_init:
        stage("", true)  # Encola menu_target en RQueue
        return

    # 4. Si no, ejecuta do_init en hilo separado
    thread.start(Rhythia, "do_init")

func stage(text, done):
    # Cuando do_init termina, encola la escena del menu
    if done:
        RQueue.queue_resource(target)  # target = Rhythia.menu_target

func _process(delta):
    # Maneja fade y espera a que RQueue tenga el recurso listo
    if RQueue.is_ready(target):
        result = RQueue.get_resource(target)
        leaving = true
        black_fade_target = true
    if leaving and result and black_fade == 1:
        get_tree().change_scene_to(result)
```

El destino por defecto (`menu_target`) es `res://scenes/menu/menu2.tscn`, configurable en `project.godot` como `application/config/default_menu_target`. En modo VR, se redirige a `res://vr/vrmenu.tscn`.

---

### Intro.tscn (Secuencia de introduccion)

- **Ruta**: `scenes/Intro.tscn`
- **Script**: `scripts/Intro.gd`
- **Tipo raiz**: `Spatial` (escena 3D)
- **Rol**: Splash animado que muestra el avatar del juego con musica y movimiento de camara.

**Comportamiento:**

1. Se muestra **antes** de `init.tscn`, activado por `Globals.gd` en `_ready()`:
   ```gdscript
   # En Globals.gd:
   if !disable_intro:
       get_tree().call_deferred("change_scene", "res://scenes/Intro.tscn")
   ```
2. La intro se puede desactivar con `disable_intro` en `user://settings.json`.
3. La secuencia dura ~28 segundos con animacion de avatar, paneo de camara y fade.
4. El jugador puede saltarla presionando pausa (o tocando la pantalla en Android).
5. Al terminar o saltar, siempre navega a `init.tscn`:
   ```gdscript
   get_tree().change_scene("res://scenes/init.tscn")
   ```

**Caracteristicas especiales:**
- Detecta fechas especiales (6 de junio, 19 de junio) para cambiar el aspecto del avatar.
- Soporta el modo Lacunella para cambios de apariencia del avatar.

---

### menu2.tscn (Menu principal)

- **Ruta**: `scenes/menu/menu2.tscn`
- **Script**: `scripts/ui/menu/menu2.gd` (entre otros)
- **Rol**: Menu principal del juego, desde donde se seleccionan canciones, se accede a settings, al editor de avatar, al content manager, etc.

Es la escena destino por defecto de todos los loaders de menu. Desde aqui se puede navegar a:

| Destino | Metodo de navegacion |
|---------|---------------------|
| Jugar cancion | `songload.tscn` -> `song.tscn` |
| Content Manager | `contentmgrload.tscn` -> `contentmgr.tscn` |
| Editor de Avatar | Directo a `AvatarEditor.tscn` |
| Seleccion de idioma | Directo a `language.tscn` |
| Resultados de cola | Directo a `queue_pass.tscn` |

---

### song.tscn (Gameplay)

- **Ruta**: `scenes/song.tscn`
- **Script**: `scripts/game/Game.gd` (entre otros)
- **Rol**: Escena principal de juego donde el jugador interactua con las notas al ritmo de la musica.

Se carga siempre a traves de `songload.tscn`. Al finalizar la partida:
- Si hay mas canciones en cola: `songload.tscn` (siguiente cancion).
- Si no: `menuload.tscn` (vuelta al menu).
- Reinicio rapido: Recarga directa de `song.tscn`.

---

### Escenas secundarias del menu

| Escena | Ruta | Proposito |
|--------|------|-----------|
| `AvatarEditor.tscn` | `scenes/menu/AvatarEditor.tscn` | Editor visual del avatar del jugador |
| `contentmgr.tscn` | `scenes/menu/contentmgr.tscn` | Gestor de contenido (agregar/gestionar canciones) |
| `language.tscn` | `scenes/menu/language.tscn` | Pantalla de seleccion de idioma |
| `queue_pass.tscn` | `scenes/menu/queue_pass.tscn` | Pantalla de resultados tras jugar una cola de canciones |
| `oldmenu2.tscn` | `scenes/menu/oldmenu2.tscn` | Menu antiguo (legacy), conservado por compatibilidad |

---

## Escenas de carga (loaders/)

Todas las escenas loader se encuentran en `scenes/loaders/` y comparten una estructura visual identica:

### Estructura comun de nodos (escena .tscn)

| Nodo | Tipo | Proposito |
|------|------|-----------|
| `Control` (raiz) | `ColorRect` | Fondo negro, contiene el script del loader |
| `Label` | Label | Texto "Loading" (invisible por defecto en algunos loaders) |
| `Label2` | Label | Texto "Waiting for engine" |
| `VersionNumber` | Label | Numero de version con icono |
| `Spinner` | ReferenceRect | Animacion de spinner con 8 cuadros (script inline) |
| `BlackFade` | ColorRect | Overlay para transicion fade in/out |
| `Music` | AudioStreamPlayer | Musica de carga (opcional) |

El **Spinner** usa un GDScript inline que cicla 8 nodos hijos (`0`-`7`) cada 0.17 segundos, creando una animacion de carga cuadrada:

```gdscript
# Script inline del Spinner
extends Control

var switch_time:float = 0.17
var t:float = switch_time
var i:int = -1

func _process(delta):
    var up = false
    t += delta
    if t >= switch_time:
        t -= switch_time
        up = true
        i += 1
        if i > 7: i -= 8
    for n in get_children():
        var ni = int(n.name)
        if up and i == ni:
            n.modulate.a = 1
        else:
            n.modulate.a = max(n.modulate.a - (delta * 1.35), 0)
```

---

### menuload.tscn - Carga del menu

- **Ruta**: `scenes/loaders/menuload.tscn`
- **Script**: `scripts/loaders/menuload.gd`
- **Destino**: `Rhythia.menu_target` (por defecto `res://scenes/menu/menu2.tscn`)
- **En error**: Redirige a `scenes/errors/menuload.tscn`

Se usa para:
- Volver al menu desde el gameplay (`song.tscn`).
- Recargar el menu despues de cambiar settings.
- Salir del content manager.

---

### songload.tscn - Carga de cancion

- **Ruta**: `scenes/loaders/songload.tscn`
- **Script**: `scripts/loaders/songload.gd`
- **Destino**: `res://scenes/song.tscn` + mundo de fondo (`Rhythia.selected_space.path`)
- **En error**: Redirige a `scenes/errors/songload.tscn`
- **Nodo extra**: `P` (ProgressBar) para mostrar progreso de carga de replay

Se usa para:
- Iniciar una partida desde el menu.
- Cargar la siguiente cancion en una cola.

**Particularidad**: Carga dos recursos en paralelo (la escena del juego y el mundo 3D de fondo).

---

### contentmgrload.tscn - Carga del content manager

- **Ruta**: `scenes/loaders/contentmgrload.tscn`
- **Script**: `scripts/loaders/contentmgrload.gd`
- **Destino**: `res://scenes/menu/contentmgr.tscn`
- **En error**: Redirige a `scenes/errors/menuload.tscn` (reutiliza la escena de error del menu)

Se usa para navegar al gestor de contenido desde el menu principal.

---

### Patron comun de los loaders

Todos los loaders implementan el mismo patron de carga en tres fases:

```
[Fase 1: Inicio]          [Fase 2: Espera]         [Fase 3: Transicion]
     |                          |                          |
  _ready()                 _process()                 _process()
     |                          |                          |
  black_fade = 1           RQueue.is_ready()?         black_fade == 1?
  RQueue.queue_resource()   -> result = get_resource()  -> change_scene_to(result)
  fade IN (oscurecer)       -> black_fade_target = true
     |                          |
  Si error:                 Si error:
  -> change_scene(error)    -> change_scene(error)
```

---

## Scripts de loaders (scripts/loaders/)

### menuload.gd

- **Extiende**: `Node`
- **Archivo**: `scripts/loaders/menuload.gd`

**Variables de estado:**

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `leaving` | bool | Indica si ya se inicio la transicion de salida |
| `target` | String | Ruta de la escena destino (`Rhythia.menu_target`) |
| `black_fade_target` | bool | Objetivo del fade (true = opaco, false = transparente) |
| `black_fade` | float | Valor actual de opacidad del fade (0.0 - 1.0) |
| `result` | Variant | Recurso cargado por RQueue |

**Flujo detallado:**

```gdscript
func _ready():
    get_tree().paused = false
    # Si estamos en VR, redirige al menu VR
    if Rhythia.vr:
        target = "res://vr/vrmenu.tscn"

    # Limpieza de estado
    PhysicsServer.set_active(true)
    Input.set_custom_mouse_cursor(null)
    Rhythia.load_color_txt()
    Rhythia.conmgr_transit = null
    Rhythia.loaded_world = null

    # Restaura estado si veniamos de un replay
    Rhythia.was_replay = Rhythia.replaying
    Rhythia.replaying = false
    if Rhythia.was_replay:
        Rhythia.restore_prev_state()

    # Descarta notas de la cancion anterior
    if Rhythia.selected_song:
        Rhythia.selected_song.discard_notes()

    # Inicia fade y carga
    black_fade = 1  # Empieza opaco
    var res = RQueue.queue_resource(target)
    if res != OK:
        Rhythia.errorstr = "queue_resource returned %s" % res
        get_tree().change_scene("res://scenes/errors/menuload.tscn")
```

**Velocidad de fade**: 0.3 segundos tanto para aparecer como para desaparecer.

---

### songload.gd

- **Extiende**: `Node`
- **Archivo**: `scripts/loaders/songload.gd`

**Diferencias con menuload.gd:**

| Aspecto | menuload.gd | songload.gd |
|---------|-------------|-------------|
| Recursos a cargar | 1 (escena del menu) | 2 (escena del juego + mundo de fondo) |
| Precarga de audio | No | Si (miss, hit, fail, pb, menu_bgm) |
| Warnings pre-juego | No | Si (notas vacias, audio roto, trail alto, etc.) |
| Soporte de replay | Limpieza | Carga del archivo de replay |
| Barra de progreso | No | Si (nodo `$P`, ProgressBar) |

**Flujo detallado:**

```gdscript
func _ready():
    # Encola dos recursos en paralelo
    var res = RQueue.queue_resource(target)    # song.tscn
    var res2 = RQueue.queue_resource(target2)  # mundo de fondo

    # Precarga efectos de sonido personalizados
    Rhythia.miss_snd = Rhythia.get_stream_with_default("user://miss", Rhythia.def_miss_snd)
    Rhythia.hit_snd = Rhythia.get_stream_with_default("user://hit", Rhythia.def_hit_snd)
    Rhythia.fail_snd = Rhythia.get_stream_with_default("user://fail", Rhythia.def_fail_snd)
    Rhythia.pb_snd = Rhythia.get_stream_with_default("user://new_best", Rhythia.def_pb_snd)

func finish():
    # Se llama cuando ambos recursos estan listos
    result = RQueue.get_resource(target)
    result2 = RQueue.get_resource(target2)
    Rhythia.loaded_world = result2

    # Maneja carga de replay si aplica
    if Rhythia.replaying:
        Rhythia.save_current_state()
        Rhythia.replay.read_data(Rhythia.replay_path)
        yield(Rhythia.replay, "done_loading")

    # Sistema de warnings (no desactivables)
    # - Mapa sin notas -> fuerza vuelta al menu
    # - Audio roto -> opcion de continuar o volver

    # Warnings desactivables (Rhythia.show_warnings)
    # - Trail detail muy alto -> riesgo de crash
    # - Approach rate <= 0 -> comportamiento no estandar
    # - Hitwindow <= 18ms -> notas imposibles de acertar
```

**Metodo `warning_menu_exit()`**: Muestra un dialogo de confirmacion y al cerrar navega a `menuload.tscn` para volver al menu.

---

### contentmgrload.gd

- **Extiende**: `Node`
- **Archivo**: `scripts/loaders/contentmgrload.gd`

Es el loader mas simple. Sigue exactamente el mismo patron que `menuload.gd`, pero:
- El destino es fijo: `res://scenes/menu/contentmgr.tscn`.
- En caso de error, establece `Rhythia.menu_target` al content manager y redirige a `scenes/errors/menuload.tscn`.
- La velocidad de fade out es ligeramente mas lenta (0.5 segundos vs 0.3 segundos).

---

### Uso de ResourceQueue (RQueue)

El singleton `RQueue` (`scripts/content/resources/ResourceQueue.gd`) es un sistema de carga asincrona basado en hilos que todos los loaders utilizan. Se registra como autoload.

**API principal:**

| Metodo | Descripcion |
|--------|-------------|
| `queue_resource(path, front?)` | Encola un recurso para carga asincrona. Retorna `OK` o un codigo de error. |
| `is_ready(path)` | Retorna `true` si el recurso termino de cargarse. |
| `get_resource(path)` | Retorna el recurso cargado. Bloquea si aun no esta listo. |
| `cancel_resource(path)` | Cancela la carga de un recurso encolado. |
| `get_progress(path)` | Retorna el progreso de carga como float (0.0 - 1.0). |

**Arquitectura interna:**

```gdscript
# RQueue usa un hilo dedicado con Mutex y Semaphore
var thread      # Thread de carga
var mutex       # Mutex para acceso seguro a la cola
var semaphore   # Semaphore para despertar el hilo cuando hay trabajo
var queue = []  # Cola de ResourceInteractiveLoader
var pending = {} # Dict path -> ResourceInteractiveLoader o Resource cargado

func queue_resource(path):
    # 1. Si ya esta en pending, retorna OK (evita duplicados)
    # 2. Si esta en cache de Godot, carga inmediatamente
    # 3. Si no, crea ResourceInteractiveLoader y encola
    var res = ResourceLoader.load_interactive(path)
    queue.push_back(res)
    pending[path] = res

func thread_process():
    # Llama poll() en el ResourceInteractiveLoader actual
    # Cuando poll() retorna ERR_FILE_EOF, el recurso esta listo
    # Reemplaza el loader en pending con el recurso final
```

**Manejo de errores en los loaders:**

Cada loader verifica dos puntos de fallo:

1. **Al encolar** (`_ready()`): Si `queue_resource()` no retorna `OK`.
2. **Al obtener** (`_process()`): Si `get_resource()` retorna un no-objeto (null).

En ambos casos, se establece `Rhythia.errorstr` con un mensaje descriptivo y se navega a la escena de error correspondiente.

---

## Escenas de error (errors/)

### Tabla de escenas de error

| Escena | Ruta | Script | Tipo de error |
|--------|------|--------|---------------|
| `menuload.tscn` | `scenes/errors/menuload.tscn` | `scenes/errors/menuload.gd` | Error al cargar el menu principal |
| `songload.tscn` | `scenes/errors/songload.tscn` | `scenes/errors/songload.gd` | Error al cargar la escena de juego |
| `content.tscn` | `scenes/errors/content.tscn` | `scenes/errors/content.gd` | Error de contenido / archivos criticos faltantes |
| `settings.tscn` | `scenes/errors/settings.tscn` | `scenes/errors/settings.gd` | Error al cargar el archivo de configuracion |
| `userfolder.tscn` | `scenes/errors/userfolder.tscn` | `scenes/errors/userfolder.gd` | Error al abrir la carpeta de usuario |
| `cmdline.tscn` | `scenes/errors/cmdline.tscn` | `scenes/errors/cmdline.gd` | Error en argumentos de linea de comandos |
| `onboardingload.tscn` | `scenes/errors/onboardingload.tscn` | `scenes/errors/onboardingload.gd` | Error al cargar el onboarding |

### Patron comun de errores

Todas las escenas de error comparten la misma estructura:

**Estructura de nodos:**

| Nodo | Tipo | Proposito |
|------|------|-----------|
| `Control` (raiz) | `ColorRect` | Fondo negro con script de error |
| `CenterContainer` | CenterContainer | Centra la imagen de error |
| `TextureRect` | TextureRect | Imagen especifica del tipo de error |
| `Info` | Label | Texto con informacion diagnostica |
| `AudioStreamPlayer` | AudioStreamPlayer | Musica de error (`error_loop.ogg`) |
| `BlackFade` | ColorRect | Fade in al entrar |

**Script comun (ejemplo de `menuload.gd`):**

```gdscript
extends ColorRect

func _ready():
    # Reduce FPS para no desperdiciar GPU en la pantalla de error
    Engine.target_fps = 30

    # Muestra informacion diagnostica
    $Info.text = """-- menu load error --
rhythia version: %s
platform: %s
error info: %s
menu target: %s""" % [
        ProjectSettings.get_setting("application/config/version"),
        OS.get_name(),
        Rhythia.errorstr,
        Rhythia.menu_target,
    ]

    # Adapta fuente para moviles
    if OS.has_feature("mobile"):
        $Info.get("custom_fonts/font").size = 28

    # Actualiza Discord Rich Presence con estado de error
    if ProjectSettings.get_setting("application/config/discord_rpc"):
        var activity = Discord.Activity.new()
        activity.set_details("experiencing a cattr moment")
        activity.set_state("(menu loading error)")
        # ...
```

**Informacion mostrada por cada escena de error:**

| Escena | Campos mostrados |
|--------|-----------------|
| `menuload` | Version, plataforma, `Rhythia.errorstr`, `Rhythia.menu_target` |
| `songload` | Version, plataforma, `Rhythia.errorstr` |
| `content` | Version, plataforma, `Rhythia.errorstr`, `Rhythia.menu_target` |
| `settings` | Version, plataforma, `Rhythia.errornum` (codigo de error) |
| `userfolder` | Version, plataforma, `Globals.errornum` (nota especial para Android) |
| `cmdline` | Version, `Rhythia.errorstr` |
| `onboardingload` | Version, plataforma, `Rhythia.errorstr`, `Rhythia.menu_target` |

**Nota**: En la escena de error `userfolder`, si la plataforma es Android, se solicitan permisos de almacenamiento y se muestra un mensaje adicional explicando la necesidad de permisos.

---

### DeleteSettingsFile.gd

- **Archivo**: `scenes/errors/DeleteSettingsFile.gd`
- **Extiende**: `Button`
- **Se usa en**: `scenes/errors/settings.tscn`

Es un boton especial que aparece en la pantalla de error de configuracion. Permite al usuario reiniciar sus settings eliminando el archivo `user://settings.json`.

**Flujo:**

1. El usuario pulsa el boton.
2. Se muestra un dialogo de confirmacion ("Are you sure you want to reset your settings?").
3. Si confirma, se elimina `user://settings.json` con `Directory.remove()`.
4. Si la eliminacion es exitosa, se reinicia el juego navegando a `init.tscn`:
   ```gdscript
   Engine.target_fps = 0  # Restaura FPS
   get_tree().change_scene("res://scenes/init.tscn")
   ```
5. Si falla la eliminacion, muestra un nuevo dialogo con el codigo de error y sugiere eliminacion manual o soporte en Discord.

---

## Prefabs reutilizables (prefabs/)

Los prefabs son escenas `.tscn` reutilizables que se instancian como componentes dentro de las escenas principales.

| Prefab | Ruta | Proposito |
|--------|------|-----------|
| `Avatar.tscn` | `prefabs/Avatar.tscn` | Modelo 3D del avatar del jugador (usado en menu, intro y gameplay) |
| `ARVRAvatar.tscn` | `prefabs/ARVRAvatar.tscn` | Variante del avatar para modo VR con tracking de manos |
| `HUD.tscn` | `prefabs/game/HUD.tscn` | Interfaz de usuario durante el gameplay (puntuacion, combo, precision, etc.) |
| `confirm.tscn` | `prefabs/menu/confirm.tscn` | Dialogo de confirmacion generico (utilizado via `Globals.confirm_prompt`) |
| `credits.tscn` | `prefabs/menu/credits.tscn` | Pantalla de creditos del juego |
| `filesel.tscn` | `prefabs/menu/filesel.tscn` | Selector de archivos para importar canciones/skins |
| `notification_gui.tscn` | `prefabs/menu/notification_gui.tscn` | Sistema de notificaciones en pantalla (logros, descargas, errores) |
| `settings_page.tscn` | `prefabs/menu/settings_page.tscn` | Pagina de configuracion reutilizable |
| `string.tscn` | `prefabs/menu/string.tscn` | Prompt de entrada de texto (para nombres, URLs, etc.) |

**Uso del dialogo de confirmacion (`confirm.tscn`):**

El prefab `confirm.tscn` se accede globalmente via `Globals.confirm_prompt` y se utiliza extensivamente en los loaders (especialmente `songload.gd`) para mostrar warnings:

```gdscript
# Ejemplo de uso en songload.gd
Globals.confirm_prompt.open(
    "This map doesn't have any notes.",
    "Warning",
    [{text="Return to menu"}]
)
var option = yield(Globals.confirm_prompt, "option_selected")
Globals.confirm_prompt.close()
```

---

## Escenas de test (scenes/test/)

| Escena | Ruta | Proposito |
|--------|------|-----------|
| `tempaccessories.tscn` | `scenes/test/tempaccessories.tscn` | Pruebas de accesorios del avatar |
| `tempshirts.tscn` | `scenes/test/tempshirts.tscn` | Pruebas de camisetas del avatar |
| `testenv.tscn` | `scenes/test/testenv.tscn` | Entorno de pruebas general |

Estas escenas no forman parte del flujo de navegacion normal del juego. Son herramientas de desarrollo para probar componentes individuales.

---

## Flujo de navegacion completo

### Diagrama de navegacion

```
                    [ARRANQUE DEL JUEGO]
                           |
                    Globals._ready()
                           |
              disable_intro == false?
                    /            \
                  SI              NO
                  |                |
           Intro.tscn         init.tscn
           (Splash 3D)       (Carga inicial)
           ~28 seg o skip         |
                  |          Rhythia.do_init()
                  |          (hilo separado)
                  |               |
                  +--------> init.tscn
                              |
                         RQueue carga
                         menu_target
                              |
                         menu2.tscn
                       (Menu principal)
                              |
            +-----------+-----+------+-----------+--------+
            |           |            |           |        |
       songload    contentmgr    Avatar     language  queue_pass
         .tscn      load.tscn    Editor      .tscn     .tscn
            |           |         .tscn
            |           |
        song.tscn   contentmgr
       (Gameplay)     .tscn
            |
     +------+------+
     |             |
  menuload     songload
   .tscn        .tscn
  (volver)   (siguiente
              en cola)

  En cualquier momento, un error redirige a:
  scenes/errors/*.tscn
```

**Rutas de navegacion detalladas:**

| Origen | Accion | Loader intermedio | Destino |
|--------|--------|-------------------|---------|
| `Globals._ready()` | Arranque con intro | (ninguno) | `Intro.tscn` |
| `Intro.tscn` | Finaliza/skip | (ninguno) | `init.tscn` |
| `init.tscn` | Carga completa | (el mismo es un loader) | `menu2.tscn` |
| `menu2.tscn` | Jugar cancion | `songload.tscn` | `song.tscn` |
| `menu2.tscn` | Content Manager | `contentmgrload.tscn` | `contentmgr.tscn` |
| `menu2.tscn` | Editor de Avatar | (ninguno) | `AvatarEditor.tscn` |
| `menu2.tscn` | Seleccion de idioma | (ninguno) | `language.tscn` |
| `song.tscn` | Fin de partida | `menuload.tscn` | `menu2.tscn` |
| `song.tscn` | Reinicio rapido | (ninguno) | `song.tscn` |
| `song.tscn` | Siguiente en cola | `songload.tscn` | `song.tscn` |
| `queue_pass.tscn` | Siguiente cancion | `songload.tscn` | `song.tscn` |
| `queue_pass.tscn` | Volver al menu | `menuload.tscn` | `menu2.tscn` |
| `contentmgr.tscn` | Salir | `menuload.tscn` | `menu2.tscn` |
| Cambiar perfil | Recargar todo | (ninguno) | `init.tscn` |
| Recargar contenido | Recargar todo | (ninguno) | `init.tscn` |
| Convertir archivos | Recargar todo | (ninguno) | `init.tscn` |
| Error de settings | Reset settings | (ninguno) | `init.tscn` |

---

### Tabla completa de escenas

| # | Escena | Ruta | Script principal | Categoria | Proposito |
|---|--------|------|-----------------|-----------|-----------|
| 1 | `init.tscn` | `scenes/init.tscn` | `scripts/init.gd` | Principal | Punto de entrada, inicializacion del juego |
| 2 | `Intro.tscn` | `scenes/Intro.tscn` | `scripts/Intro.gd` | Principal | Splash animado de introduccion |
| 3 | `menu2.tscn` | `scenes/menu/menu2.tscn` | `scripts/ui/menu/menu2.gd` | Menu | Menu principal del juego |
| 4 | `song.tscn` | `scenes/song.tscn` | `scripts/game/Game.gd` | Gameplay | Escena de juego/gameplay |
| 5 | `AvatarEditor.tscn` | `scenes/menu/AvatarEditor.tscn` | -- | Menu | Editor de avatar del jugador |
| 6 | `contentmgr.tscn` | `scenes/menu/contentmgr.tscn` | -- | Menu | Gestor de contenido |
| 7 | `language.tscn` | `scenes/menu/language.tscn` | -- | Menu | Seleccion de idioma |
| 8 | `queue_pass.tscn` | `scenes/menu/queue_pass.tscn` | `scripts/ui/menu/queue/queue_pass.gd` | Menu | Resultados de cola de canciones |
| 9 | `oldmenu2.tscn` | `scenes/menu/oldmenu2.tscn` | -- | Menu | Menu antiguo (legacy) |
| 10 | `menuload.tscn` | `scenes/loaders/menuload.tscn` | `scripts/loaders/menuload.gd` | Loader | Cargador de menu con transicion |
| 11 | `songload.tscn` | `scenes/loaders/songload.tscn` | `scripts/loaders/songload.gd` | Loader | Cargador de cancion con validaciones |
| 12 | `contentmgrload.tscn` | `scenes/loaders/contentmgrload.tscn` | `scripts/loaders/contentmgrload.gd` | Loader | Cargador del content manager |
| 13 | `menuload.tscn` | `scenes/errors/menuload.tscn` | `scenes/errors/menuload.gd` | Error | Error al cargar menu |
| 14 | `songload.tscn` | `scenes/errors/songload.tscn` | `scenes/errors/songload.gd` | Error | Error al cargar cancion |
| 15 | `content.tscn` | `scenes/errors/content.tscn` | `scenes/errors/content.gd` | Error | Error de contenido critico |
| 16 | `settings.tscn` | `scenes/errors/settings.tscn` | `scenes/errors/settings.gd` | Error | Error de configuracion |
| 17 | `userfolder.tscn` | `scenes/errors/userfolder.tscn` | `scenes/errors/userfolder.gd` | Error | Error de carpeta de usuario |
| 18 | `cmdline.tscn` | `scenes/errors/cmdline.tscn` | `scenes/errors/cmdline.gd` | Error | Error de linea de comandos |
| 19 | `onboardingload.tscn` | `scenes/errors/onboardingload.tscn` | `scenes/errors/onboardingload.gd` | Error | Error de onboarding |
| 20 | `tempaccessories.tscn` | `scenes/test/tempaccessories.tscn` | -- | Test | Pruebas de accesorios |
| 21 | `tempshirts.tscn` | `scenes/test/tempshirts.tscn` | -- | Test | Pruebas de camisetas |
| 22 | `testenv.tscn` | `scenes/test/testenv.tscn` | -- | Test | Entorno de pruebas |

---

> **Nota**: `init.tscn` funciona internamente como un loader (usa el mismo patron de RQueue + fade), pero es tambien la escena principal del proyecto (`main_scene` en `project.godot`). A diferencia de los loaders dedicados, `init.tscn` ejecuta la inicializacion completa del juego (`Rhythia.do_init()`) en un hilo separado antes de cargar la escena destino.
