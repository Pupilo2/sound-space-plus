# 05 - Interfaz de Usuario y Menus

## Vision general

Sound Space Plus (Rhythia) implementa su interfaz de usuario completa mediante nodos 2D de Godot 3.x. El sistema de UI abarca:

- **Menu principal** (`menu2.tscn`) - Hub central con sidebar de navegacion, lista de mapas, informacion de cancion, modificadores, resultados y ajustes.
- **Componentes compartidos** - Dialogos de confirmacion, prompts de texto, selector de archivos y notificaciones, instanciados globalmente desde `Globals.gd`.
- **Content Manager** (`contentmgr.tscn`) - Pantalla dedicada para importar mapas en multiples formatos.
- **Sistema de cola** (`queue_pass.tscn`) - Pantalla intermedia para reproduccion secuencial de multiples canciones.
- **Pantallas auxiliares** - Selector de idioma, editor de avatar, pantalla de descarga, creditos.

Todos los componentes UI se comunican con el estado global del juego a traves de los autoloads `Rhythia` y `Globals`. La navegacion entre pantallas se realiza mediante `get_tree().change_scene()` con transiciones de fundido negro.

---

## Componentes de UI compartidos

Los componentes compartidos son instanciados una unica vez por `Globals.gd` durante `_ready()` y agregados al nodo raiz. Esto permite que cualquier script del juego los invoque sin necesidad de instanciarlos nuevamente.

### Inicializacion en Globals.gd

```gdscript
# Globals.gd - lineas 677-687
confirm_prompt = load("res://prefabs/menu/confirm.tscn").instance()
rootg.call_deferred("add_child", confirm_prompt)

string_prompt = load("res://prefabs/menu/string.tscn").instance()
rootg.call_deferred("add_child", string_prompt)

file_sel = load("res://prefabs/menu/filesel.tscn").instance()
rootg.call_deferred("add_child", file_sel)

notify_gui = load("res://prefabs/menu/notification_gui.tscn").instance()
rootg.call_deferred("add_child", notify_gui)
```

Las referencias globales son:

| Variable | Tipo | Prefab |
|----------|------|--------|
| `Globals.confirm_prompt` | `ConfirmationPrompt2D` | `prefabs/menu/confirm.tscn` |
| `Globals.string_prompt` | `StringPrompt2D` | `prefabs/menu/string.tscn` |
| `Globals.file_sel` | `FileSelector2D` | `prefabs/menu/filesel.tscn` |
| `Globals.notify_gui` | `Notify2D` | `prefabs/menu/notification_gui.tscn` |

---

### ConfirmationPrompt2D

**Archivo:** `scripts/ui/ConfirmationPrompt2D.gd`
**Clase:** `ConfirmationPrompt2D` (extiende `ColorRect`)
**Prefab:** `prefabs/menu/confirm.tscn`

Dialogo modal de confirmacion con hasta 4 botones configurables. Soporta un temporizador de espera (`wait`) que desactiva un boton hasta que pase el tiempo indicado (por ejemplo, para prevenir clicks accidentales en acciones destructivas).

**Senales:**
- `option_selected(index:int)` - Emitida cuando el usuario elige una opcion.
- `done_opening` - La animacion de apertura ha terminado.
- `done_closing` - La animacion de cierre ha terminado.

**Sonidos integrados:**
- `$Alert` - Sonido al abrir el prompt.
- `$Next` - Sonido de confirmacion.
- `$Back` - Sonido de cancelacion.

**API principal:**

```gdscript
# Abrir un dialogo de confirmacion
func open(body:String, title:String="Confirm", options:Array=[
    { text="Cancel" },
    { text="OK", wait=3 }  # Boton desactivado por 3 segundos
])

# Cerrar el dialogo
func close()
```

**Ejemplo de uso (desde MapActions.gd):**

```gdscript
Globals.confirm_prompt.open(
    "Are you sure you want to delete this map?",
    "Delete Map",
    [{ text = "Cancel" }, { text = "OK", wait = 1 }]
)
Globals.confirm_prompt.s_alert.play()
var response:int = yield(Globals.confirm_prompt, "option_selected")
Globals.confirm_prompt.close()
if response == 1:
    Rhythia.selected_song.delete()
```

**Animacion:** Utiliza `Tween` para deslizar el contenedor horizontalmente (`rect_position`) y hacer fade del `modulate` en 0.4 segundos con `TRANS_SINE`.

---

### StringPrompt2D

**Archivo:** `scripts/ui/StringPrompt2D.gd`
**Clase:** `StringPrompt2D` (extiende `ColorRect`)
**Prefab:** `prefabs/menu/string.tscn`

Variante del dialogo de confirmacion que incluye un campo de entrada de texto (`LineEdit`). Comparte la misma estructura visual y logica de animacion que `ConfirmationPrompt2D`.

**API principal:**

```gdscript
func open(body:String, title:String="Confirm", input:String="Profile Name",
    options:Array=[
        { text="Cancel" },
        { text="OK", wait=3 }
    ]
)
```

**Senales:** Identicas a `ConfirmationPrompt2D` (`option_selected`, `done_opening`, `done_closing`).

El valor del texto ingresado se obtiene leyendo `Globals.string_prompt.input.text` despues de recibir la senal `option_selected`.

---

### FileSelector2D

**Archivo:** `scripts/ui/FileSelector.gd`
**Clase:** `FileSelector2D` (extiende `ColorRect`)
**Prefab:** `prefabs/menu/filesel.tscn`

Selector de archivos que soporta dos modos:
1. **Nativo** - Utiliza dialogos nativos del sistema operativo (`$OpenFile`, `$SaveFile`, `$Folder`) cuando estan disponibles y no estan desactivados en la configuracion del proyecto.
2. **Integrado** - Utiliza los dialogos de Godot (`FileDialog`) como fallback (`$C/OpenFile`, `$C/SaveFile`, `$C/Folder`).

**API principal:**

```gdscript
# Abrir archivo(s)
func open_file(obj:Object, method:String,
    filters:PoolStringArray = ["* ; All Files"],
    multiselect:bool = false,
    initial_path:String = "user://")

# Guardar archivo
func save_file(obj:Object, method:String,
    filters:PoolStringArray = ["* ; All Files"],
    initial_path:String = "user://")

# Seleccionar carpeta
func open_folder(obj:Object, method:String,
    initial_path:String = "user://")
```

**Patron de callback:** El selector no usa senales directas. En su lugar, recibe un `Object` y el nombre de un metodo al que llamara con el resultado. Esto permite un acoplamiento flexible con cualquier script.

```gdscript
# Ejemplo: abrir selector para guardar datos de mapa como .txt
Globals.file_sel.save_file(
    self,
    "save_song_txt",
    ["*.txt ; Text map data"],
    OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + "/%s.txt" % song_id
)
```

**Deteccion de modo nativo:** Se verifica en `_ready()` que las senales `files_selected`, `file_selected` y `folder_selected` existan en los nodos de dialogo nativo y que la opcion `disable_native_file_dialogs` no este activa.

---

### Notify2D

**Archivo:** `scripts/ui/Notify2D.gd`
**Clase:** `Notify2D` (extiende `VBoxContainer`)
**Prefab:** `prefabs/menu/notification_gui.tscn`

Sistema de notificaciones toast que muestra mensajes temporales en pantalla. Las notificaciones aparecen con fade-in, permanecen visibles por un tiempo y desaparecen con fade-out.

**Tipos de notificacion:**

| Constante | Valor | Color de linea | Color de titulo | Uso |
|-----------|-------|----------------|-----------------|-----|
| `Globals.NOTIFY_INFO` | `0` | `#254e7f` | `#89cbff` | Informacion general |
| `Globals.NOTIFY_WARN` | `1` | `#805a00` | `#ffbe6b` | Advertencias |
| `Globals.NOTIFY_ERROR` | `2` | `#800000` | `#ffa4a4` | Errores |
| `Globals.NOTIFY_SUCCEED` | `3` | `#257f33` | `#b1ff89` | Exito/confirmacion |

**API principal (a traves de Globals):**

```gdscript
# Funcion wrapper en Globals.gd
func notify(type:int, body:String, title:String="Notification", time:float=5):
    notify_gui.notify(type, body, title, time)
```

**Ejemplo de uso:**

```gdscript
Globals.notify(Globals.NOTIFY_SUCCEED, "Map converted successfully!", "Converted")
Globals.notify(Globals.NOTIFY_ERROR, "Failed to save file", "Error")
```

**Implementacion interna:** Cada notificacion es un duplicado del nodo plantilla `$Notify`. Se anima con `Tween`: fade-in de 0.25s, espera `time - 2` segundos, luego fade-out de 2 segundos, y finalmente se libera con `queue_free()`.

---

## Menu Principal (menu2.tscn)

### Escena y estructura

**Escena:** `scenes/menu/menu2.tscn`
**Script raiz:** `scripts/ui/menu/menu2.gd`
**Nodo raiz:** `Menu` (Node, nombre en el arbol: `Menu`)

El menu principal es la pantalla central del juego. Se accede despues de la intro/carga y es el punto de retorno tras completar una cancion.

### Script del menu (menu2.gd)

El script raiz maneja:

1. **Modos especiales:** Si `Rhythia.arcw_mode`, `Rhythia.sex_mode` o `Rhythia.memory_lane` estan activos, redirige inmediatamente a escenas alternativas.
2. **Audio:** Limpia efectos de pitch-shift del bus de musica al regresar de una cancion.
3. **Discord RPC:** Establece estado "Main Menu - Selecting a song" y cambia a "Listening to music" tras 5 minutos de inactividad.
4. **Transicion de fundido negro:** `BlackFade` es un `ColorRect` que se anima entre opaco y transparente para transiciones suaves.
5. **Recarga rapida:** `Shift+End` recarga el menu inmediatamente.

```gdscript
# Transicion de fundido negro
var black_fade_target:bool = false  # true = oscurecer, false = aclarar
var black_fade:float = 1            # 1 = completamente negro

func _process(delta):
    if black_fade_target && black_fade != 1:
        black_fade = min(black_fade + (delta/0.3), 1)
    elif !black_fade_target && black_fade != 0:
        black_fade = max(black_fade - (delta/0.5), 0)
    $BlackFade.color = Color(0,0,0, black_fade)
```

---

### Sidebar (Barra lateral de navegacion)

**Archivo:** `scripts/ui/menu/Sidebar.gd`
**Extiende:** `Panel`

La sidebar es el componente principal de navegacion. Contiene botones que alternan entre las paginas del menu.

**Paginas disponibles:**

| Indice | Pagina (nodo) | Boton | Descripcion |
|--------|---------------|-------|-------------|
| 0 | `Main/Maps` | `Results` | Lista de mapas y pantalla de resultados |
| 1 | `Main/Settings` | `Settings` | Configuracion del juego |
| 2 | `Main/Credits` | `Credits` | Creditos y Patreon |
| 3 | `Main/Content` | `ContentMgr` | Gestor de contenido (solo PC) |
| 4 | `Main/Language` | `Language` | Selector de idioma |

**Botones adicionales (sin pagina asociada):**
- `OldMenu` - Cambia al menu antiguo (oculto por defecto).
- `StartVR` - Inicia modo VR (oculto por defecto).
- `Quit` - Cierra el juego.

**Comportamiento de expansion:**
La sidebar se expande al pasar el mouse por encima (60px cerrada, 240px abierta). La animacion es fluida mediante interpolacion en `_process()`:

```gdscript
rect_size.x = 60 + (180 * open_amt)  # open_amt se interpola entre 0 y 1
```

**Atajo de teclado:** `ui_quicksettings` abre directamente la pagina de Settings.

---

### Lista de mapas

El juego implementa dos versiones de lista de mapas:

#### v2MapList (Vista de cuadricula)

**Archivo:** `scripts/ui/menu/buttons/v2MapList.gd`
**Extiende:** `GridContainer`

Vista de cuadricula paginada donde cada mapa se muestra como un icono cuadrado (132x132px). Los mapas se clasifican por dificultad y se muestran con colores distintivos. Soporta paginacion con scroll del mouse y botones de avance/retroceso.

#### v3MapList (Vista de lista vertical)

**Archivo:** `scripts/ui/menu/buttons/v3MapList.gd`
**Extiende:** `VBoxContainer`

Vista de lista vertical con scroll continuo. Cada mapa se muestra como un panel horizontal (350x90px). Soporta:
- **Arrastrar para scroll:** Deteccion de drag con `check_drag` y momentum.
- **Animacion de ancho:** Los items mas lejanos del centro se hacen mas estrechos (`tween_length()`).
- **Carga de covers en hilo:** Thread separado para cargar imagenes de portada sin bloquear el UI.
- **Eliminacion de diacriticos:** Funcion `strip_diacritics()` para prevenir texto zalgo que causa lag.

**Funcionalidad comun a ambas versiones:**

- **Busqueda por nombre:** Filtro de texto que busca en `song.name` (via `MapSearch.gd`).
- **Busqueda por autor:** Filtro adicional por `song.creator` (via `AuthorSearch.gd`).
- **Filtro de dificultad:** Toggles por cada nivel (Easy, Medium, Hard, Logic, Tasukete) via `diffSort.gd`.
- **Orden:** Invertir orden de dificultad (`DifficultySort.gd`) y nombre (`NameSort.gd`).
- **Favoritos:** Los mapas favoritos se muestran primero, con icono de estrella.
- **Mapas rotos:** Opcion para mostrar/ocultar mapas con errores (`MapIncludeBroken.gd`).
- **Mapas online:** Toggle para incluir mapas descargables (`SearchOnline.gd`).
- **Seleccion aleatoria:** Boton y tecla F2 para seleccionar un mapa al azar.
- **Doble click para jugar:** Seleccionar el mismo mapa dos veces en menos de 0.25s inicia la cancion.

**Senales emitidas:**
- `search_updated` - Cuando cambian los filtros de busqueda.
- `reset_filters` - Cuando se reinician todos los filtros.
- `lock_type` - Cuando se bloquea la entrada de texto (al iniciar una cancion).

---

### Pantalla de informacion de cancion (SongInfoScreen)

**Archivo:** `scripts/ui/menu/SongInfoScreen.gd`
**Extiende:** `Control`

Muestra informacion detallada del mapa seleccionado:
- ID, nombre, nombre de cancion, mapper.
- Dificultad con nombre y color.
- Duracion y cantidad de notas.
- Informacion de hitboxes y hitwindow actuales.
- Icono del mapa con portada o nombre.
- Advertencias si el mapa tiene problemas.
- Boton de jugar (`RunMapButton`), acciones del mapa y preview de musica.

Se actualiza automaticamente al conectarse a las senales `selected_song_changed`, `mods_changed` y `favorite_songs_changed` de `Rhythia`.

---

### Resultados (EndInfo)

**Archivo:** `scripts/ui/menu/buttons/EndInfo.gd`
**Extiende:** `Control`

Panel de resultados que se muestra despues de completar una cancion. Funciona en dos modos:

1. **Post-partida** (`Rhythia.just_ended_song == true`):
   - Muestra resultado: "You passed!", "You failed!", "New best!", "Replay passed/failed".
   - Estadisticas: accuracy (hits/total), misses, pausas, max combo, progreso.
   - Letra de calificacion con colores (SS rainbow, S, A, B, C, D, F).
   - Reproduce sonido de nuevo record personal si aplica.

2. **Personal Best** (cuando no se acaba de jugar):
   - Muestra el mejor resultado guardado o "No PB" si no existe.

**Sistema de calificacion:**

| Accuracy | Grado | Color |
|----------|-------|-------|
| 100% | SS | Arcoiris animado |
| >= 98% | S | `#91fffa` (cian) |
| >= 95% | A | `#91ff92` (verde) |
| >= 90% | B | `#e7ffc0` (verde claro) |
| >= 85% | C | `#fcf7b3` (amarillo) |
| >= 80% | D | `#fcd0b3` (naranja) |
| < 80% | F | `#ff8282` (rojo) |

---

### Botones de modificadores y gameplay

Los modificadores del juego se configuran desde el menu principal. Cada uno es un `CheckBox` o control especializado que sincroniza su estado con propiedades de `Rhythia`:

| Script | Tipo | Propiedad de Rhythia | Descripcion |
|--------|------|---------------------|-------------|
| `NoFail.gd` | CheckBox | `mod_nofail` | No morir al perder toda la vida |
| `SuddenDeath.gd` | CheckBox | `mod_sudden_death` | Morir al primer fallo |
| `EasyMode.gd` | CheckBox | `mod_extra_energy` | Energia extra |
| `HardMode.gd` | CheckBox | `mod_no_regen` | Sin regeneracion de vida |
| `Ghost.gd` | CheckBox | `mod_ghost` | Notas fantasma |
| `MirrorX.gd` | CheckBox | `mod_mirror_x` | Espejo horizontal |
| `MirrorY.gd` | CheckBox | `mod_mirror_y` | Espejo vertical |
| `ModChaos.gd` | CheckBox | `mod_chaos` | Notas caoticas |
| `ModFlashlight.gd` | CheckBox | `mod_flashlight` | Linterna (vision limitada) |
| `ModEarthquake.gd` | CheckBox | `mod_earthquake` | Temblor de pantalla |
| `ModHardRock.gd` | CheckBox | `mod_hardrock` | Hard Rock |
| `Nearsight.gd` | CheckBox | `mod_nearsight` | Vision cercana |
| `VisualMode.gd` | CheckBox | `visual_mode` | Modo visual (sin gameplay) |

**Patron comun de estos scripts:**

```gdscript
extends CheckBox

func _process(_d):
    if pressed != Rhythia.mod_ejemplo:
        Rhythia.mod_ejemplo = pressed

func upd(): pressed = Rhythia.mod_ejemplo

func _ready():
    upd()
    Rhythia.connect("mods_changed", self, "upd")
```

### Velocidad (SpeedMod)

**Archivo:** `scripts/ui/menu/buttons/SpeedMod.gd`
**Extiende:** `ReferenceRect`

Panel con 9 botones de velocidad (grupo de toggle):
- `MMM` (0.5x), `MM` (0.6x), `M` (0.75x), `Normal` (1.0x)
- `P` (1.25x), `PP` (1.5x), `PPP` (2.0x), `PPPP` (2.5x)
- `Custom` - Velocidad personalizada configurada en ajustes.

Cada boton modifica `Rhythia.mod_speed_level` usando las constantes `Globals.SPEED_*`.

### Modelo de salud (HpModel)

**Archivo:** `scripts/ui/menu/buttons/HpModel.gd`
**Extiende:** `MenuButton`

Dropdown para seleccionar el modelo de HP:
- **Default (Sound Space):** Modelo original del juego.
- **Old (easier):** 6 HP (10 en easy), regenera 1 HP por acierto.

### Sistema de calificacion (GradeSystem)

**Archivo:** `scripts/ui/menu/GradeSystem.gd`
**Extiende:** `MenuButton`

Dropdown para elegir entre:
- **Default (Rhythia):** Tipos de puntuacion extendidos.
- **Legacy (Sound Space):** Igual que el juego original.

---

### Acciones del mapa (MapActions)

**Archivo:** `scripts/ui/menu/buttons/MapActions.gd`
**Extiende:** `MenuButton`

Menu contextual con acciones sobre el mapa seleccionado:

| Indice | Accion | Condiciones |
|--------|--------|-------------|
| 0 | Eliminar mapa | Solo SSPM/SSPM2, no online, no single map mode |
| 1 | Convertir a SSPM v2 | No roto, no convertido, no SSPM2, no online |
| 2 | Copiar... (submenu) | ID, Path (solo local), Nombre |
| 3 | Cambiar dificultad (submenu) | Solo SSPM/SSPM2, no online |
| 4 | Exportar datos .txt | Siempre disponible |
| 5 | Exportar audio | No roto, no online |

La eliminacion requiere confirmacion a traves de `Globals.confirm_prompt` con espera de 1 segundo.

---

### Boton de jugar (RunMapButton)

**Archivo:** `scripts/ui/menu/buttons/RunMapButton.gd`
**Extiende:** `Button`

Boton principal para iniciar una cancion. Funcionalidades:

1. **Deteccion de controlador:** Si hay joypads conectados y `Rhythia.ignore_controller_detection` es falso, muestra un prompt de confirmacion antes de iniciar.
2. **Drag-and-drop:** Acepta archivos `.sspre` (replays) y `.sspm` (mapas) arrastrados sobre la ventana.
3. **Atajos:** Tecla `Space` y boton `A` del gamepad.
4. **Senal `lock_type`:** Emitida al presionar para bloquear campos de texto (`MapSearch`, `AuthorSearch`).
5. **Transicion:** Activa `black_fade_target`, espera 0.35s, y cambia a `scenes/loaders/songload.tscn`.

---

### Preview de musica (PlaySong)

**Archivo:** `scripts/ui/menu/buttons/PlaySong.gd`
**Extiende:** `Button`

Alterna entre reproducir y detener la musica del mapa seleccionado. Soporta:
- Preview automatico al seleccionar un mapa (`auto_preview_song`).
- Musica de menu de fondo (`menu_loop.ogg`).
- Fade-in de volumen para la musica de menu.
- Ajuste de pitch segun el mod de velocidad activo.

---

### Otros componentes del menu

| Script | Descripcion |
|--------|-------------|
| `Favorite.gd` | Toggle de favorito para el mapa seleccionado. Lee/escribe en `Rhythia.favorite_songs`. |
| `WarningBar.gd` | Barra animada en la parte inferior que muestra advertencias contextuales (single map mode, debug, experimental, controlador). Texto con scroll horizontal continuo. |
| `VersionNumber.gd` | Label que muestra "Rhythia [version]" desde `ProjectSettings`. |
| `rainbow.gd` | Aplica color arcoiris animado a cualquier `Control` usando `Rhythia.rainbow_t`. |
| `MenuMouse.gd` | Particulas 2D que siguen la posicion del mouse. |
| `DownloadScreen.gd` | Overlay de descarga que muestra progreso porcentual. Se activa/desactiva con las senales `download_start`/`download_done` de `Rhythia`. |
| `StartOffset.gd` | Slider + campo de texto para configurar el offset de inicio de la cancion en segundos. |
| `CSpeedLabel.gd` | Label que muestra la velocidad personalizada actual ("C (150%)"). |
| `clipinput.gd` | Control vacio que intercepta input (bloquea clicks a nodos detras). |
| `languagemenu.gd` | Dropdown para cambiar idioma (English, Japanese, French, Spanish). Usa `TranslationServer.set_locale()`. |
| `PatreonCredits.gd` | Carga y muestra nombres de patrons desde archivos `patreon1.txt`, `patreon2.txt`, `patreon3.txt`. |

---

## Sistema de Cola (Queue)

### Vision general

El sistema de cola permite reproducir multiples canciones secuencialmente. La cola se gestiona a traves de `Rhythia.song_queue` (Array de Song) y `Rhythia.queue_pos` (indice actual).

**Flujo de cola:**

```
Menu principal
    |
    v
[Agregar canciones a Rhythia.song_queue]
    |
    v
Rhythia.queue_active = true
    |
    v
songload.tscn --> song.tscn (jugar cancion)
    |
    v
queue_pass.tscn (pantalla intermedia)
    |            |
    |            v
    |    [Si hay mas canciones]
    |            |
    |            v
    |    songload.tscn --> song.tscn
    |            |
    |            v
    |    queue_pass.tscn ...
    |
    v
[Cola terminada o fallo]
    |
    v
menuload.tscn --> menu2.tscn
```

### queue_pass.gd

**Archivo:** `scripts/ui/menu/queue/queue_pass.gd`
**Escena:** `scenes/menu/queue_pass.tscn`
**Extiende:** `Node`

Pantalla de transicion entre canciones de la cola. Comportamiento:

1. Muestra los resultados de la cancion que acaba de terminar (via `QueueEndInfo`).
2. Si hay mas canciones, muestra "Next: [nombre]" y reproduce un preview.
3. Temporizador de 10 segundos con barra de progreso antes de avanzar automaticamente.
4. Si no hay mas canciones o el jugador fallo, muestra mensaje de fin y regresa al menu.
5. La transicion usa `black_fade` con velocidad de 0.3s.

**Logica de avance:**

```gdscript
if t >= 10:
    leaving = true
if leaving and black_fade == 1:
    if Rhythia.queue_active:
        Rhythia.select_song(next_song)
        get_tree().change_scene("res://scenes/loaders/songload.tscn")
    else:
        get_tree().change_scene("res://scenes/loaders/menuload.tscn")
```

### QueueEndInfo.gd

**Archivo:** `scripts/ui/menu/queue/QueueEndInfo.gd`
**Extiende:** `Control`

Muestra estadisticas acumuladas de la cola:
- Progreso: "X/Y songs done".
- Misses acumulados, pausas acumuladas.
- Accuracy acumulada (hits/total con porcentaje).
- Progreso temporal total.
- Letra de calificacion acumulada.

Lee datos de `Rhythia.queue_end_*` (misses, hits, total_notes, pause_count, position, length).

### QueueSongInfo.gd

**Archivo:** `scripts/ui/menu/queue/QueueSongInfo.gd`
**Extiende:** `Control`

Muestra los resultados individuales de la cancion que acaba de terminar dentro de la cola. Es muy similar a `EndInfo.gd` pero se muestra dentro de la pantalla de cola. Incluye:
- Resultado (passed/failed/new best).
- Accuracy, misses, pausas.
- Letra de calificacion.
- Verificacion y guardado de PB (`Rhythia.do_pb_check_and_set()`).

---

## Content Manager (cmgr/)

### Vision general

El Content Manager es una pantalla dedicada para importar mapas de diferentes formatos al juego.

**Escena:** `scenes/menu/contentmgr.tscn`
**Script raiz:** `scripts/ui/cmgr/contentmgr.gd`

### contentmgr.gd

**Archivo:** `scripts/ui/cmgr/contentmgr.gd`
**Extiende:** `Node`

Script raiz de la escena del Content Manager. Maneja:
- Transicion de fundido negro (identica al menu principal).
- Estado de Discord RPC: "Content Manager".
- Visibilidad del mouse.

### AddSong.gd

**Archivo:** `scripts/ui/cmgr/AddSong.gd`
**Extiende:** `Panel`

Script principal del flujo de importacion de mapas. Implementa un asistente multi-paso con las siguientes pantallas internas:

**Pantallas del asistente:**

| Pantalla | Descripcion |
|----------|-------------|
| `$SelectType` | Seleccion de formato: TXT, SSPM, Vulnus (.vmap), SSPM Review |
| `$TxtFile` | Editor de mapa TXT: datos del mapa, audio, metadatos, cover |
| `$VulnusFile` | Importacion de mapa Vulnus: archivo ZIP o carpeta |
| `$SelectDifficulty` | Seleccion de dificultad (para Vulnus con multiples dificultades) |
| `$Edit` | Edicion de metadatos: nombre, mapper, ID, dificultad, cover |
| `$Finish` | Resultado de la operacion (exito/error/espera) |

**Formatos soportados:**

| Tipo | Constante | Descripcion |
|------|-----------|-------------|
| TXT | `T_TXT` | Datos de mapa en texto plano + archivo de audio separado |
| SSPM | `T_SSPM` | Archivo `.sspm` de Sound Space Plus |
| Vulnus | `T_VULNUS` | Formato Vulnus con `meta.json` (carpeta o ZIP) |
| SSPM Review | `T_SSPMR` | SSPM para revision |

**Flujo de importacion TXT:**

1. Seleccionar datos del mapa (pegar texto o cargar archivo `.txt`).
2. Cargar archivo de audio (`.mp3` o `.ogg`).
3. Editar metadatos: nombre, mapper, ID (auto-generado o manual), dificultad.
4. Opcionalmente agregar cover (imagen).
5. Finalizar: convierte a `.sspm` y agrega al registro.

**Flujo de importacion Vulnus:**

1. Seleccionar archivo ZIP o carpeta.
2. Si es ZIP: extrae a carpeta temporal usando 7zip.
3. Localiza `meta.json` (soporta carpetas anidadas).
4. Lee metadatos: artista, titulo, mappers, dificultades, ruta de musica.
5. Si hay multiples dificultades, muestra selector.
6. Convierte a SSPM y agrega al registro.

**Generacion de ID:**

```gdscript
# Formato: mapper_nombre_cancion (caracteres alfanumericos y guiones)
func generate_id(sname:String, mapper:String):
    # Filtra caracteres invalidos, reemplaza espacios con '_'
    # Ejemplo: "MyMapper" + "Artist - Song" => "mymapper_artist_-_song"
```

### CMgrExit.gd

**Archivo:** `scripts/ui/cmgr/CMgrExit.gd`
**Extiende:** `Button`

Boton para salir del Content Manager. Al presionarlo:
1. Establece `Rhythia.conmgr_transit = null`.
2. Cambia escena a `scenes/loaders/menuload.tscn`.
3. Proteccion contra doble click con `has_been_pressed`.

### ContentMgrAddMap.gd

**Archivo:** `scripts/ui/menu/buttons/ContentMgrAddMap.gd`
**Extiende:** `Button`

Boton en el menu principal para acceder al Content Manager. Establece `Rhythia.conmgr_transit = "addsongs"` y cambia a `scenes/loaders/contentmgrload.tscn`. Solo visible si `enable_new_content_mgr` esta activo en ProjectSettings.

---

## Prefabs de UI

Los prefabs son escenas reutilizables instanciadas en tiempo de ejecucion:

| Prefab | Ruta | Script | Descripcion |
|--------|------|--------|-------------|
| `confirm.tscn` | `prefabs/menu/confirm.tscn` | `ConfirmationPrompt2D` | Dialogo de confirmacion modal |
| `string.tscn` | `prefabs/menu/string.tscn` | `StringPrompt2D` | Prompt de entrada de texto |
| `filesel.tscn` | `prefabs/menu/filesel.tscn` | `FileSelector2D` | Selector de archivos (nativo/integrado) |
| `notification_gui.tscn` | `prefabs/menu/notification_gui.tscn` | `Notify2D` | Contenedor de notificaciones toast |
| `settings_page.tscn` | `prefabs/menu/settings_page.tscn` | Varios | Pagina de configuracion embebida en el menu |
| `credits.tscn` | `prefabs/menu/credits.tscn` | Varios | Pantalla de creditos |

### Escenas de menu adicionales

| Escena | Ruta | Descripcion |
|--------|------|-------------|
| `menu2.tscn` | `scenes/menu/menu2.tscn` | Menu principal v2 |
| `oldmenu2.tscn` | `scenes/menu/oldmenu2.tscn` | Menu antiguo (legacy) |
| `queue_pass.tscn` | `scenes/menu/queue_pass.tscn` | Pantalla de transicion de cola |
| `contentmgr.tscn` | `scenes/menu/contentmgr.tscn` | Content Manager |
| `AvatarEditor.tscn` | `scenes/menu/AvatarEditor.tscn` | Editor de avatar |
| `language.tscn` | `scenes/menu/language.tscn` | Selector de idioma |
| `HUD.tscn` | `prefabs/game/HUD.tscn` | HUD durante el gameplay |

### Escenas de carga (loaders)

| Escena | Ruta | Destino |
|--------|------|---------|
| `menuload.tscn` | `scenes/loaders/menuload.tscn` | Menu principal |
| `songload.tscn` | `scenes/loaders/songload.tscn` | Pantalla de juego |
| `contentmgrload.tscn` | `scenes/loaders/contentmgrload.tscn` | Content Manager |

---

## Tabla de scripts de UI

### Componentes compartidos

| Script | Ruta | Proposito |
|--------|------|-----------|
| `ConfirmationPrompt2D.gd` | `scripts/ui/ConfirmationPrompt2D.gd` | Dialogo de confirmacion con botones y temporizador |
| `StringPrompt2D.gd` | `scripts/ui/StringPrompt2D.gd` | Dialogo con campo de entrada de texto |
| `FileSelector.gd` | `scripts/ui/FileSelector.gd` | Selector de archivos (nativo/fallback) |
| `Notify2D.gd` | `scripts/ui/Notify2D.gd` | Sistema de notificaciones toast |

### Menu principal

| Script | Ruta | Proposito |
|--------|------|-----------|
| `menu2.gd` | `scripts/ui/menu/menu2.gd` | Script raiz del menu principal (Discord RPC, transiciones, modos especiales) |
| `Sidebar.gd` | `scripts/ui/menu/Sidebar.gd` | Barra lateral de navegacion con expansion animada |
| `ResultsHolder.gd` | `scripts/ui/menu/ResultsHolder.gd` | Contenedor de resultados con modo centrado |
| `SongInfoScreen.gd` | `scripts/ui/menu/SongInfoScreen.gd` | Informacion detallada del mapa seleccionado |
| `DownloadScreen.gd` | `scripts/ui/menu/DownloadScreen.gd` | Overlay de progreso de descarga |
| `SearchOnline.gd` | `scripts/ui/menu/SearchOnline.gd` | Toggle para incluir mapas online en la busqueda |
| `GradeSystem.gd` | `scripts/ui/menu/GradeSystem.gd` | Selector de sistema de calificacion |
| `WarningBar.gd` | `scripts/ui/menu/WarningBar.gd` | Barra de advertencias contextuales con scroll |
| `VersionNumber.gd` | `scripts/ui/menu/VersionNumber.gd` | Label de version del juego |
| `rainbow.gd` | `scripts/ui/menu/rainbow.gd` | Efecto arcoiris animado para controles |
| `MenuMouse.gd` | `scripts/ui/menu/MenuMouse.gd` | Particulas 2D que siguen al cursor |
| `AuthorSearch.gd` | `scripts/ui/menu/AuthorSearch.gd` | Campo de busqueda por autor/mapper |
| `StartOffset.gd` | `scripts/ui/menu/StartOffset.gd` | Slider de offset de inicio de cancion |
| `languagemenu.gd` | `scripts/ui/menu/languagemenu.gd` | Menu de seleccion de idioma |

### Botones del menu

| Script | Ruta | Proposito |
|--------|------|-----------|
| `RunMapButton.gd` | `scripts/ui/menu/buttons/RunMapButton.gd` | Boton principal para iniciar cancion (con deteccion de controlador) |
| `PlaySong.gd` | `scripts/ui/menu/buttons/PlaySong.gd` | Preview/reproduccion de musica del mapa |
| `MapSearch.gd` | `scripts/ui/menu/buttons/MapSearch.gd` | Campo de busqueda por nombre de mapa |
| `v2MapList.gd` | `scripts/ui/menu/buttons/v2MapList.gd` | Lista de mapas en cuadricula paginada |
| `v3MapList.gd` | `scripts/ui/menu/buttons/v3MapList.gd` | Lista de mapas en lista vertical con scroll |
| `MapActions.gd` | `scripts/ui/menu/buttons/MapActions.gd` | Menu contextual de acciones del mapa |
| `MapIcon.gd` | `scripts/ui/menu/buttons/MapIcon.gd` | Panel individual de mapa (filtrado de visibilidad) |
| `Favorite.gd` | `scripts/ui/menu/buttons/Favorite.gd` | Toggle de mapa favorito |
| `EndInfo.gd` | `scripts/ui/menu/buttons/EndInfo.gd` | Pantalla de resultados post-partida y PB |
| `SpeedMod.gd` | `scripts/ui/menu/buttons/SpeedMod.gd` | Panel de seleccion de velocidad (9 niveles + custom) |
| `CSpeedLabel.gd` | `scripts/ui/menu/buttons/CSpeedLabel.gd` | Label de velocidad personalizada |
| `NoFail.gd` | `scripts/ui/menu/buttons/NoFail.gd` | Mod: No Fail |
| `SuddenDeath.gd` | `scripts/ui/menu/buttons/SuddenDeath.gd` | Mod: Sudden Death |
| `EasyMode.gd` | `scripts/ui/menu/buttons/EasyMode.gd` | Mod: Extra Energy |
| `HardMode.gd` | `scripts/ui/menu/buttons/HardMode.gd` | Mod: No Regen |
| `Ghost.gd` | `scripts/ui/menu/buttons/Ghost.gd` | Mod: Ghost notes |
| `MirrorX.gd` | `scripts/ui/menu/buttons/MirrorX.gd` | Mod: Espejo horizontal |
| `MirrorY.gd` | `scripts/ui/menu/buttons/MirrorY.gd` | Mod: Espejo vertical |
| `ModChaos.gd` | `scripts/ui/menu/buttons/ModChaos.gd` | Mod: Chaos |
| `ModFlashlight.gd` | `scripts/ui/menu/buttons/ModFlashlight.gd` | Mod: Flashlight |
| `ModEarthquake.gd` | `scripts/ui/menu/buttons/ModEarthquake.gd` | Mod: Earthquake |
| `ModHardRock.gd` | `scripts/ui/menu/buttons/ModHardRock.gd` | Mod: Hard Rock |
| `Nearsight.gd` | `scripts/ui/menu/buttons/Nearsight.gd` | Mod: Nearsight |
| `VisualMode.gd` | `scripts/ui/menu/buttons/VisualMode.gd` | Mod: Visual Mode |
| `HpModel.gd` | `scripts/ui/menu/buttons/HpModel.gd` | Selector de modelo de HP |
| `DifficultySort.gd` | `scripts/ui/menu/buttons/DifficultySort.gd` | Toggle invertir orden de dificultad |
| `NameSort.gd` | `scripts/ui/menu/buttons/NameSort.gd` | Toggle invertir orden de nombre |
| `diffSort.gd` | `scripts/ui/menu/buttons/diffSort.gd` | Filtros de dificultad por categoria |
| `MapIncludeBroken.gd` | `scripts/ui/menu/buttons/MapIncludeBroken.gd` | Toggle mostrar mapas rotos |
| `PlayAutoSwitch.gd` | `scripts/ui/menu/buttons/PlayAutoSwitch.gd` | Toggle auto-switch a pantalla de play |
| `SetDifficulty.gd` | `scripts/ui/menu/buttons/SetDifficulty.gd` | Dropdown para cambiar dificultad del mapa |
| `Convert.gd` | `scripts/ui/menu/buttons/Convert.gd` | Boton convertir mapa a SSPM v2 |
| `ExportTxt.gd` | `scripts/ui/menu/buttons/ExportTxt.gd` | Boton exportar datos del mapa como .txt |
| `ContentMgrAddMap.gd` | `scripts/ui/menu/buttons/ContentMgrAddMap.gd` | Boton acceso al Content Manager |
| `Quit.gd` | `scripts/ui/menu/buttons/Quit.gd` | Boton cerrar juego |
| `Language.gd` | `scripts/ui/menu/buttons/Language.gd` | Boton cambiar idioma |
| `PatreonCredits.gd` | `scripts/ui/menu/buttons/PatreonCredits.gd` | Carga y muestra nombres de patrons |
| `clipinput.gd` | `scripts/ui/menu/buttons/clipinput.gd` | Control bloqueador de input |

### Cola (Queue)

| Script | Ruta | Proposito |
|--------|------|-----------|
| `queue_pass.gd` | `scripts/ui/menu/queue/queue_pass.gd` | Pantalla de transicion entre canciones de la cola |
| `QueueEndInfo.gd` | `scripts/ui/menu/queue/QueueEndInfo.gd` | Estadisticas acumuladas de la cola |
| `QueueSongInfo.gd` | `scripts/ui/menu/queue/QueueSongInfo.gd` | Resultados individuales dentro de la cola |

### Content Manager

| Script | Ruta | Proposito |
|--------|------|-----------|
| `contentmgr.gd` | `scripts/ui/cmgr/contentmgr.gd` | Script raiz del Content Manager (transiciones, RPC) |
| `AddSong.gd` | `scripts/ui/cmgr/AddSong.gd` | Asistente de importacion multi-formato (TXT, SSPM, Vulnus) |
| `CMgrExit.gd` | `scripts/ui/cmgr/CMgrExit.gd` | Boton salir del Content Manager |

---

## Diagrama de navegacion entre pantallas

```
                        [Inicio]
                           |
                     scenes/init.tscn
                           |
                     scenes/Intro.tscn
                           |
              scenes/loaders/menuload.tscn
                           |
                  +--------+---------+
                  |                  |
          scenes/menu/         scenes/menu/
          menu2.tscn           oldmenu2.tscn
          (Menu principal)     (Menu legacy)
                  |
     +----+------+------+-------+------+
     |    |      |      |       |      |
  [Maps] [Settings] [Credits] [CMgr] [Language]
     |                          |
     |              scenes/loaders/
     |              contentmgrload.tscn
     |                          |
     |              scenes/menu/
     |              contentmgr.tscn
     |              (AddSong flujo)
     |                          |
     |                   [Volver al menu]
     |
     +--- [Seleccionar mapa] ---> [Ver info + resultados]
     |
     +--- [Jugar cancion] -------> scenes/loaders/songload.tscn
                                          |
                                    scenes/song.tscn
                                    (Gameplay)
                                          |
                              +-----------+-----------+
                              |                       |
                      [Modo normal]           [Modo cola]
                              |                       |
                    scenes/loaders/           scenes/menu/
                    menuload.tscn             queue_pass.tscn
                              |                       |
                    menu2.tscn              +----+----+
                    (con resultados)        |         |
                                      [Siguiente] [Fin cola]
                                            |         |
                                      songload.tscn  menuload.tscn
```

---

## Conexion con Globals y Rhythia

### Senales de Rhythia usadas por el UI

| Senal | Scripts que la escuchan | Proposito |
|-------|------------------------|-----------|
| `selected_song_changed` | `EndInfo`, `SongInfoScreen`, `PlaySong`, `MapActions`, `Favorite`, `SetDifficulty`, `MapSearch`, `StartOffset` | Actualizar UI cuando se selecciona un nuevo mapa |
| `mods_changed` | Todos los CheckBox de mods, `EndInfo`, `SongInfoScreen`, `CSpeedLabel` | Sincronizar estado de mods |
| `speed_mod_changed` | `PlaySong`, `CSpeedLabel` | Actualizar pitch de preview y label de velocidad |
| `favorite_songs_changed` | `v2MapList`, `v3MapList`, `Favorite`, `SongInfoScreen` | Recargar lista y actualizar icono de favorito |
| `map_list_ready` | `EndInfo` (yield) | Esperar a que la lista de mapas este cargada |
| `download_start` | `DownloadScreen` | Mostrar overlay de descarga |
| `download_done` | `DownloadScreen`, `v2MapList`, `v3MapList` | Ocultar overlay, actualizar iconos de nube |
| `menu_music_state_changed` | `PlaySong` | Toggle musica de menu |

### Variables de Rhythia leidas por el UI

| Variable | Tipo | Usado por |
|----------|------|-----------|
| `selected_song` | `Song` | Todos los scripts de info/acciones/play |
| `just_ended_song` | `bool` | `EndInfo`, `QueueSongInfo` |
| `song_end_type` | `int` | `EndInfo`, `QueueSongInfo`, `queue_pass` |
| `song_end_hits/misses/total_notes` | `int` | `EndInfo`, `QueueSongInfo` |
| `song_end_combo/pause_count` | `int` | `EndInfo`, `QueueSongInfo` |
| `song_end_position/length/time_str` | `float/String` | `EndInfo`, `QueueSongInfo` |
| `queue_active` | `bool` | `queue_pass` |
| `song_queue` | `Array` | `QueueEndInfo` |
| `queue_pos` | `int` | `QueueEndInfo` |
| `queue_end_*` | Varios | `QueueEndInfo` |
| `favorite_songs` | `Array` | `Favorite`, `v2MapList`, `v3MapList` |
| `mod_speed_level` | `int` | `SpeedMod`, `PlaySong` |
| `single_map_mode` | `bool` | `Sidebar`, `Favorite`, `SongInfoScreen`, `WarningBar` |
| `rainbow_t` | `float` | `rainbow.gd`, `EndInfo`, `QueueEndInfo` |
| `registry_song` | `SongRegistry` | `v2MapList`, `v3MapList`, `AddSong` |
| `render_scale` | `float` | `FileSelector` |

### Variables de Globals usadas por el UI

| Variable/Constante | Tipo | Usado por |
|---------------------|------|-----------|
| `confirm_prompt` | `ConfirmationPrompt2D` | `MapActions`, `RunMapButton`, y otros dialogos |
| `string_prompt` | `StringPrompt2D` | Prompts de texto (perfiles, etc.) |
| `file_sel` | `FileSelector2D` | `MapActions`, `AddSong`, y exportaciones |
| `notify_gui` / `notify()` | `Notify2D` / func | Notificaciones en todo el juego |
| `speed_multi` | `Array` | `PlaySong`, `SpeedMod`, `StartOffset` |
| `DIFF_*` | `int` | `diffSort`, `v2MapList`, `v3MapList` |
| `difficulty_names` | `Dictionary` | `SongInfoScreen`, `AddSong` |
| `difficulty_colors` | `Dictionary` | `SongInfoScreen` |
| `END_PASS/END_FAIL/END_GIVEUP` | `int` | `EndInfo`, `QueueSongInfo`, `queue_pass` |
| `MAP_SSPM/MAP_SSPM2/MAP_TXT/MAP_RAW/MAP_NET` | `int` | `MapActions`, `SongInfoScreen`, `AddSong`, `Convert` |
| `NOTIFY_INFO/WARN/ERROR/SUCCEED` | `int` | Todos los scripts que emiten notificaciones |
