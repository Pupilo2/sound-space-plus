# 01 - Globals y Estado Global

> Documentacion de arquitectura para **Sound Space Plus (Rhythia)** - Motor: Godot 3.x

---

## Indice

1. [Descripcion general](#descripcion-general)
2. [Globals.gd (Autoload)](#globalsgd-autoload)
   - [Enums](#enums)
   - [Constantes](#constantes)
   - [Variables globales](#variables-globales)
   - [Senales](#senales-globals)
   - [Metodos clave](#metodos-clave)
3. [Rhythia.gd (Autoload)](#rhythiagd-autoload)
   - [Senales](#senales-rhythia)
   - [Directorios de usuario](#directorios-de-usuario)
   - [Registros de contenido](#registros-de-contenido)
   - [Estado de seleccion actual](#estado-de-seleccion-actual)
   - [Settings de gameplay](#settings-de-gameplay)
   - [Sistema de cola](#sistema-de-cola)
   - [VR](#vr)
   - [Estado de fin de cancion](#estado-de-fin-de-cancion)
   - [Replay](#replay)
4. [init.gd (Punto de entrada)](#initgd-punto-de-entrada)
5. [Intro.gd (Splash/Intro)](#introgd-splashintro)
6. [Diagrama de conexiones](#diagrama-de-conexiones)

---

## Descripcion general

El estado global de Sound Space Plus se gestiona a traves de dos nodos **Autoload** principales:

| Autoload | Archivo | Responsabilidad |
|----------|---------|-----------------|
| `Globals` | `scripts/Globals.gd` | Constantes, enums, funciones utilitarias, managers de UI |
| `Rhythia` | `scripts/Rhythia.gd` | Estado del juego, configuracion persistida, registros de contenido, seleccion |

Ambos se cargan automaticamente al inicio del proyecto y estan disponibles desde cualquier script del juego. El arranque pasa por dos escenas adicionales: `Intro.tscn` (splash opcional) e `init.tscn` (pantalla de carga).

---

## Globals.gd (Autoload)

- **Extiende**: `Node`
- **Archivo**: `scripts/Globals.gd`
- **Proposito**: Repositorio central de constantes, enumeraciones, funciones utilitarias y managers de interfaz de usuario.

### Enums

#### Modos de camara

| Nombre | Valor |
|--------|-------|
| `CAMERA_HALF_LOCK` | 0 |
| `CAMERA_FULL_LOCK` | 1 |

#### Estados de resultado (Result State)

Controlan los diferentes estados posibles durante y despues de una partida.

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `RS_CURSOR` | 0 | Estado del cursor |
| `RS_HIT` | 1 | Nota acertada |
| `RS_MISS` | 2 | Nota fallada |
| `RS_PAUSE` | 3 | Juego pausado |
| `RS_GIVEUP` | 4 | Jugador se rinde |
| `RS_END` | 5 | Fin de cancion |
| `RS_START_UNPAUSE` | 6 | Inicio de des-pausa |
| `RS_CANCEL_UNPAUSE` | 7 | Cancelar des-pausa |
| `RS_FINISH_UNPAUSE` | 8 | Des-pausa completada |
| `RS_SKIP` | 9 | Saltar seccion |
| `RS_GIVEUP_CANCEL` | 10 | Cancelar rendicion |

#### Repositorios de mapas (Map Repository)

Define la ubicacion y formato de origen de un mapa.

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `MAPR_FILE` | 0 | Archivo en directorio de mapas |
| `MAPR_FILE_ABSOLUTE` | 1 | Archivo con ruta absoluta |
| `MAPR_FILE_SONG_ABSOLUTE` | 2 | Archivo con ruta de cancion absoluta |
| `MAPR_EMBEDDED` | 3 | Embebido en el ejecutable |
| `MAPR_EMBEDDED_SONG_ABSOLUTE` | 4 | Embebido con cancion en ruta absoluta |

#### Tipos de registro

| Nombre | Valor |
|--------|-------|
| `REGISTRY_MAP` | 0 |
| `REGISTRY_COLORSET` | 1 |

#### Posiciones de amigo (Friend Position)

Define donde aparece el avatar del amigo en la interfaz durante el juego.

| Nombre | Valor | Posicion |
|--------|-------|----------|
| `FRIEND_LOWER_RIGHT` | 0 | Inferior derecha |
| `FRIEND_LOWER_LEFT` | 1 | Inferior izquierda |
| `FRIEND_UPPER_RIGHT` | 2 | Superior derecha |
| `FRIEND_UPPER_LEFT` | 3 | Superior izquierda |
| `FRIEND_FILL_GRID` | 4 | Llenar grilla |
| `FRIEND_BEHIND_GRID` | 5 | Detras de la grilla |
| `FRIEND_BELOW_UI_L` | 6 | Debajo de UI izquierda |
| `FRIEND_BELOW_UI_R` | 7 | Debajo de UI derecha |

#### Tipos de cursor

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `CURSOR_CUSTOM_COLOR` | 0 | Color personalizado |
| `CURSOR_RAINBOW` | 1 | Arcoiris animado |
| `CURSOR_NOTE_COLOR` | 2 | Color de la nota |

#### Niveles de velocidad (Speed)

Modifican la velocidad de reproduccion de las canciones.

| Nombre | Valor | Multiplicador | Descripcion |
|--------|-------|---------------|-------------|
| `SPEED_NORMAL` | 0 | `1.0` | Velocidad normal |
| `SPEED_MMM` | 1 | `1/1.35` (~0.74) | Mas lento (---) |
| `SPEED_MM` | 2 | `1/1.25` (0.80) | Mas lento (--) |
| `SPEED_M` | 3 | `1/1.15` (~0.87) | Mas lento (-) |
| `SPEED_P` | 4 | `1.15` | Mas rapido (+) |
| `SPEED_PP` | 5 | `1.25` | Mas rapido (++) |
| `SPEED_PPP` | 6 | `1.35` | Mas rapido (+++) |
| `SPEED_CUSTOM` | 7 | `Rhythia.custom_speed` | Velocidad personalizada |
| `SPEED_PPPP` | 8 | `1.45` | Mas rapido (++++) |

Los multiplicadores se almacenan en el array `speed_multi`:

```gdscript
onready var speed_multi:Array = [
    1,                      # SPEED_NORMAL
    1/1.35,                 # SPEED_MMM (---)
    1/1.25,                 # SPEED_MM (--)
    1/1.15,                 # SPEED_M (-)
    1.15,                   # SPEED_P (+)
    1.25,                   # SPEED_PP (++)
    1.35,                   # SPEED_PPP (+++)
    Rhythia.custom_speed,   # SPEED_CUSTOM
    1.45,                   # SPEED_PPPP (++++)
]
```

#### Fin del juego (End Type)

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `END_PASS` | 0 | Cancion completada |
| `END_FAIL` | 1 | Fallo (sin vida) |
| `END_GIVEUP` | 2 | Rendicion voluntaria |

#### Estado de notas (Note State)

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `NSTATE_ACTIVE` | 0 | Nota activa (en vuelo) |
| `NSTATE_HIT` | 1 | Nota acertada |
| `NSTATE_MISS` | 2 | Nota fallada |

#### Busqueda (Search)

Filtros disponibles para la busqueda de canciones.

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `SEARCH_ALLTEXT` | 0 | Buscar en todo el texto |
| `SEARCH_ID` | 1 | Buscar por ID |
| `SEARCH_NAME` | 2 | Buscar por nombre |
| `SEARCH_CREATOR` | 3 | Buscar por creador |
| `SEARCH_RARITY` | 4 | Buscar por rareza |
| `SEARCH_DIFFICULTY` | 5 | Buscar por dificultad |
| `SEARCH_TYPE` | 6 | Buscar por tipo |

#### Dificultad (Difficulty)

| Nombre | Valor | Nombre visible |
|--------|-------|----------------|
| `DIFF_UNKNOWN` | -1 | N/A |
| `DIFF_EASY` | 0 | EASY |
| `DIFF_MEDIUM` | 1 | MEDIUM |
| `DIFF_HARD` | 2 | HARD |
| `DIFF_LOGIC` | 3 | LOGIC? |
| `DIFF_AMOGUS` | 4 | (caracter especial) |

#### Formatos de mapa (Map Format)

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `MAP_TXT` | 0 | Formato texto plano |
| `MAP_RAW` | 1 | Formato binario crudo |
| `MAP_VULNUS` | 2 | Formato Vulnus |
| `MAP_SSPM` | 3 | Formato SSPM v1 |
| `MAP_NET` | 4 | Formato de red/online |
| `MAP_SSPM2` | 5 | Formato SSPM v2 |

#### Modelos de salud (Health Model)

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `HP_SOUNDSPACE` | 0 | Modelo de salud de Sound Space (por defecto) |
| `HP_OLD` | 1 | Modelo de salud antiguo/legacy |

#### Grados (Grade System)

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `GRADE_SSP` | 0 | Sistema de grados Sound Space Plus |
| `GRADE_LEGACY` | 1 | Sistema de grados legacy |

#### VR (Tipo de hardware)

| Nombre | Valor |
|--------|-------|
| `VR_GENERIC` | 0 |
| `VR_OCULUS` | 1 |
| `VR_VIVE` | 2 |

#### Notificaciones (Notification Type)

| Nombre | Valor | Descripcion |
|--------|-------|-------------|
| `NOTIFY_INFO` | 0 | Informacion general |
| `NOTIFY_WARN` | 1 | Advertencia |
| `NOTIFY_ERROR` | 2 | Error |
| `NOTIFY_SUCCEED` | 3 | Operacion exitosa |

---

### Constantes

#### `difficulty_names: Dictionary`

Mapeo de nivel de dificultad a nombre visible:

```gdscript
const difficulty_names:Dictionary = {
    -1: "N/A",
    0: "EASY",
    1: "MEDIUM",
    2: "HARD",
    3: "LOGIC?",
    4: "助",
}
```

#### `difficulty_colors: Dictionary`

Colores asociados a cada nivel de dificultad:

```gdscript
const difficulty_colors:Dictionary = {
    -1: Color("#ffffff"),   # Blanco (desconocido)
    0:  Color("#00ff00"),   # Verde (EASY)
    1:  Color("#ffb900"),   # Amarillo/naranja (MEDIUM)
    2:  Color("#ff0000"),   # Rojo (HARD)
    3:  Color("#d76aff"),   # Purpura (LOGIC?)
    4:  Color("#36304f"),   # Violeta oscuro (助)
}
```

#### `locale: Array`

Idiomas soportados por el juego:

```gdscript
const locale:Array = ["en", "ja", "fr", "es"]
```

#### `official_map_difficulties: Dictionary`

Diccionario con mas de 1000 entradas que mapea hashes de canciones oficiales a su nivel de dificultad. Ejemplo:

```gdscript
const official_map_difficulties:Dictionary = {
    2078819639: 0,  # EASY
    3666416563: 0,  # EASY
    2075061500: 1,  # MEDIUM
    # ... mas de 1000 entradas
}
```

Las claves son hashes numericos de las canciones y los valores corresponden a las constantes `DIFF_*`.

---

### Variables globales

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `rootg` | `Viewport` | Referencia al nodo raiz (`get_tree().root`) |
| `audioLoader` | `AudioLoader` | Instancia del cargador de archivos de audio |
| `imageLoader` | `ImageLoader` | Instancia del cargador de imagenes |
| `confirm_prompt` | `ConfirmationPrompt2D` | Dialogo de confirmacion global |
| `string_prompt` | `StringPrompt2D` | Prompt de entrada de texto global |
| `file_sel` | `FileSelector2D` | Selector de archivos global |
| `notify_gui` | `Notify2D` | Sistema de notificaciones en pantalla |
| `error_sound` | `AudioStream` | Sonido de error cargado |
| `fps_visible` | `bool` | Si el contador de FPS esta visible |
| `fps_disp` | `Label` | Label para mostrar FPS en pantalla |
| `console_open` | `bool` | Si la consola de debug esta abierta |
| `con` | `LineEdit` | Campo de texto de la consola de debug |
| `cmdline` | `Dictionary` | Argumentos de linea de comandos parseados |
| `url_regex` | `RegEx` | Expresion regular compilada para validacion de URLs |
| `errornum` | `int` | Codigo de error global |

---

### Senales (Globals)

| Senal | Descripcion |
|-------|-------------|
| `recurse_result` | Emitida con el resultado de `get_files_recursive()` en modo async |
| `console_sent` | Emitida cuando se ingresa un comando en la consola de debug (parametros: `cmd`, `args`) |

---

### Metodos clave

#### `p(path: String) -> String`

Convierte rutas con prefijo `user://` a la ruta real del sistema de archivos. En Android, redirige al directorio Desktop del sistema en lugar del directorio de datos de usuario de Godot.

```gdscript
func p(path:String) -> String:
    var base_path = "user://"
    if OS.has_feature("Android"):
        base_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP, false) + "/"
    return path.replace("user://", base_path)
```

**Ejemplo de uso:**
```gdscript
# En PC: retorna "user://maps"
# En Android: retorna "/storage/emulated/0/Desktop/maps"
var maps_dir = Globals.p("user://maps")
```

---

#### `comma_sep(number) -> String`

Formatea un numero insertando comas como separadores de miles.

```gdscript
# Ejemplo:
Globals.comma_sep(1000)     # "1,000"
Globals.comma_sep(1234567)  # "1,234,567"
```

---

#### `get_files_recursive(paths, max_layers, filter_ext, folders_with, pause_amt)`

Busca archivos recursivamente en multiples directorios con soporte asincrono.

**Parametros:**

| Parametro | Tipo | Default | Descripcion |
|-----------|------|---------|-------------|
| `paths` | `Array` | - | Directorios raiz donde buscar |
| `max_layers` | `int` | `5` | Profundidad maxima de recursion |
| `filter_ext` | `String` | `""` | Extension de archivo a filtrar (vacio = todos) |
| `folders_with` | `String` | `""` | Buscar carpetas que contengan este archivo |
| `pause_amt` | `int` | `-1` | Intervalo de frames para yield (-1 = sincrono) |

**Retorna:** `Dictionary` con claves `files` (Array) y `folders` (Array).

**Modo asincrono:** Si `pause_amt >= 0`, la funcion usa `yield` para devolver control al motor cada cierto numero de iteraciones, y emite la senal `recurse_result` al terminar.

```gdscript
# Busqueda sincrona
var result = Globals.get_files_recursive([maps_dir], 3, "sspm")

# Busqueda asincrona (no bloquea frames)
Globals.get_files_recursive([maps_dir], 3, "sspm", "", 100)
var result = yield(Globals, "recurse_result")
```

---

#### `notify(type, body, title, time)`

Muestra una notificacion en pantalla a traves del sistema de notificaciones global.

**Parametros:**

| Parametro | Tipo | Default | Descripcion |
|-----------|------|---------|-------------|
| `type` | `int` | - | Tipo de notificacion (`NOTIFY_INFO`, `NOTIFY_WARN`, `NOTIFY_ERROR`, `NOTIFY_SUCCEED`) |
| `body` | `String` | - | Texto del cuerpo de la notificacion |
| `title` | `String` | `"Notification"` | Titulo de la notificacion |
| `time` | `float` | `5` | Duracion en segundos |

```gdscript
Globals.notify(Globals.NOTIFY_SUCCEED, "Mapa descargado exitosamente", "Descarga", 3)
Globals.notify(Globals.NOTIFY_ERROR, "No se pudo conectar al servidor", "Error")
```

---

#### `is_valid_url(text: String) -> bool`

Valida si un texto es una URL valida usando una expresion regular.

```gdscript
# La regex compilada en _ready() acepta:
# ((https?)://)[\\w\\-.]{2,256}(:\\d{1,5})?(/[\\w@:%._\\-+~&=]+)+/?
Globals.is_valid_url("https://example.com/path")  # true
Globals.is_valid_url("texto normal")               # false
```

---

#### `_ready()`

Metodo de inicializacion del autoload `Globals`. Ejecuta las siguientes operaciones:

1. Inicia un thread que ejecuta `Rhythia.do_init()`
2. Lee `settings.json` para determinar si se debe mostrar la intro
3. Compila la expresion regular de validacion de URLs
4. Carga e instancia los managers de UI:
   - `ConfirmationPrompt2D` (dialogos de confirmacion)
   - `StringPrompt2D` (prompts de texto)
   - `FileSelector2D` (selector de archivos)
   - `Notify2D` (notificaciones)
5. Configura el display de FPS
6. Parsea argumentos de linea de comandos en `cmdline`
7. En modo debug, muestra FPS automaticamente

---

#### `_process(delta)`

Bucle principal que se ejecuta cada frame:

1. Eleva el `notify_gui` al frente de la jerarquia visual
2. Maneja la consola de debug (abrir, cerrar, ejecutar comandos)
3. Actualiza el display de FPS si esta visible
4. Escucha el atajo de teclado para alternar la visibilidad de FPS

---

## Rhythia.gd (Autoload)

- **Extiende**: `Node`
- **Archivo**: `scripts/Rhythia.gd`
- **Proposito**: Gestor central del estado del juego, configuracion del usuario, registros de contenido instalado, y estado de seleccion actual.

### Senales (Rhythia)

El autoload `Rhythia` define 16 senales para comunicar cambios de estado a toda la aplicacion:

| Senal | Descripcion |
|-------|-------------|
| `mods_changed` | Un modificador de juego fue activado o desactivado |
| `speed_mod_changed` | El nivel de velocidad cambio |
| `selected_song_changed` | La cancion seleccionada cambio |
| `selected_space_changed` | El mundo de fondo seleccionado cambio |
| `selected_colorset_changed` | El esquema de color seleccionado cambio |
| `selected_mesh_changed` | El mesh de nota seleccionado cambio |
| `selected_hit_effect_changed` | El efecto de hit seleccionado cambio |
| `selected_miss_effect_changed` | El efecto de miss seleccionado cambio |
| `init_stage_reached` | Se completo una etapa de inicializacion |
| `init_stage_num` | Progreso numerico de la inicializacion |
| `map_list_ready` | La lista de canciones termino de cargarse |
| `volume_changed` | El volumen de musica cambio |
| `favorite_songs_changed` | La lista de favoritos fue modificada |
| `menu_music_state_changed` | El estado de la musica de menu cambio |
| `download_start` | Se inicio la descarga de un mapa online |
| `download_done` | La descarga de un mapa se completo |

---

### Directorios de usuario

Rhythia crea y gestiona los siguientes directorios en el espacio de usuario (todas las rutas pasan por `Globals.p()`):

| Variable | Ruta | Contenido |
|----------|------|-----------|
| `user_pack_dir` | `user://packs` | Paquetes de contenido |
| `user_mod_dir` | `user://mods` | Mods instalados |
| `user_vmap_dir` | `user://vmaps` | Mapas virtuales |
| `user_map_dir` | `user://maps` | Mapas de canciones |
| `user_best_dir` | `user://bests` | Records personales por cancion |
| `user_colorset_dir` | `user://colorsets` | Esquemas de color personalizados |
| `user_friend_dir` | `user://friend` | Datos de amigos |
| `user_mesh_dir` | `user://meshes` | Estilos de mesh de notas |

---

### Registros de contenido

Los registros gestionan el contenido instalado y disponible. Cada registro es una instancia de la clase `Registry`:

| Variable | Tipo | Contenido |
|----------|------|-----------|
| `registry_colorset` | `Registry` | Esquemas de color cargados |
| `registry_song` | `Registry` | Canciones y mapas disponibles |
| `registry_world` | `Registry` | Mundos de fondo (backgrounds) |
| `registry_mesh` | `Registry` | Estilos de mesh para notas |
| `registry_effect` | `Registry` | Efectos de particulas (hit/miss) |

---

### Estado de seleccion actual

Variables que representan lo que el jugador tiene seleccionado actualmente:

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `selected_space` | `BackgroundWorld` | Mundo de fondo activo |
| `selected_colorset` | `ColorSet` | Esquema de color activo |
| `selected_song` | `Song` | Cancion seleccionada |
| `selected_mesh` | `NoteMesh` | Mesh de nota activo |
| `selected_hit_effect` | `NoteEffect` | Efecto visual al acertar nota |
| `selected_miss_effect` | `NoteEffect` | Efecto visual al fallar nota |

Cada seleccion tiene su funcion `select_*()` correspondiente que actualiza la variable y emite la senal asociada:

```gdscript
func select_colorset(set: ColorSet):
    if set:
        selected_colorset = set
        emit_signal("selected_colorset_changed", set)

func select_song(song: Song):
    # Si es un mapa online, descarga primero
    if song.is_online:
        emit_signal("download_start")
        # ... logica de descarga async ...
    else:
        selected_song = song
        emit_signal("selected_song_changed", song)
```

> **Nota:** `select_song()` tiene logica especial para mapas online: pausa el arbol de escenas, inicia la descarga via `Online.download_map()`, y espera con `yield` hasta que se complete.

---

### Settings de gameplay

Todos los settings de gameplay usan `setget` para emitir automaticamente la senal `mods_changed` (o senales adicionales) cuando se modifican.

#### Modificadores normales

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `mod_speed_level` | `int` | `SPEED_NORMAL` | Nivel de velocidad |
| `custom_speed` | `float` | `1.0` | Multiplicador de velocidad personalizada |
| `mod_nofail` | `bool` | `false` | Modo sin fallo (no se pierde vida) |
| `mod_extra_energy` | `bool` | `false` | Energia extra (modo facil) |
| `mod_no_regen` | `bool` | `false` | Sin regeneracion de vida |
| `mod_sudden_death` | `bool` | `false` | Muerte instantanea al fallar |
| `mod_chaos` | `bool` | `false` | Notas con posiciones aleatorias |
| `mod_earthquake` | `bool` | `false` | La camara tiembla |
| `mod_ghost` | `bool` | `false` | Notas desaparecen antes de llegar |
| `mod_nearsighted` | `bool` | `false` | Rango de vision reducido |
| `mod_hardrock` | `bool` | `false` | Hard Rock (dificultad aumentada) |
| `mod_flashlight` | `bool` | `false` | Solo se ve el area cercana al cursor |
| `mod_mirror_x` | `bool` | `false` | Espejo horizontal |
| `mod_mirror_y` | `bool` | `false` | Espejo vertical |

**Exclusiones mutuas entre mods:**

- `mod_nofail` desactiva: `mod_extra_energy`, `mod_no_regen`, `mod_sudden_death`
- `mod_sudden_death` desactiva: `mod_extra_energy`, `mod_no_regen`, `mod_nofail`
- `mod_extra_energy` desactiva: `mod_sudden_death`, `mod_nofail`
- `visual_mode` activa automaticamente `mod_nofail`

#### Valores personalizados

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `start_offset` | `float` | `0` | Offset de inicio en la cancion |
| `note_hitbox_size` | `float` | `1.140` | Tamano del hitbox de las notas |
| `hitwindow_ms` | `float` | `55` | Ventana de timing en milisegundos |
| `health_model` | `int` | `HP_SOUNDSPACE` | Modelo de salud activo |
| `grade_system` | `int` | `GRADE_SSP` | Sistema de calificacion |

#### Configuracion visual de notas

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `approach_rate` | `float` | `40` | Tasa de aproximacion de notas |
| `spawn_distance` | `float` | `40` | Distancia de aparicion |
| `note_size` | `float` | `1` | Tamano de las notas |
| `note_opacity` | `float` | `1` | Opacidad de las notas |
| `note_spawn_effect` | `bool` | `false` | Efecto al aparecer notas |
| `note_spin_x` | `float` | `0` | Rotacion X de las notas |
| `note_spin_y` | `float` | `0` | Rotacion Y de las notas |
| `note_spin_z` | `float` | `0` | Rotacion Z de las notas |
| `fade_length` | `float` | `0.5` | Duracion del fade de notas |
| `do_note_pushback` | `bool` | `true` | Notas pasan mas alla de la grilla al fallar |

#### Configuracion de camara y controles

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `sensitivity` | `float` | `0.5` | Sensibilidad del mouse |
| `parallax` | `float` | `6.5` | Efecto parallax de camara |
| `ui_parallax` | `float` | `1.63` | Parallax de la interfaz |
| `grid_parallax` | `float` | `0` | Parallax de la grilla |
| `fov` | `float` | `70` | Campo de vision |
| `hit_fov` | `bool` | `false` | FOV dinamico al acertar |
| `camera_mode` | `int` | `CAMERA_HALF_LOCK` | Modo de camara |
| `lock_mouse` | `bool` | `true` | Bloquear raton en la ventana |
| `absolute_mode` | `bool` | `false` | Modo de posicionamiento absoluto |
| `invert_mouse` | `bool` | `false` | Invertir controles del raton |

#### Configuracion de audio

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `music_volume_db` | `float` | `0` | Volumen de musica (dB) |
| `play_hit_snd` | `bool` | `true` | Reproducir sonido al acertar |
| `play_miss_snd` | `bool` | `true` | Reproducir sonido al fallar |
| `sfx_2d` | `bool` | `false` | Efectos de sonido en 2D |
| `music_offset` | `float` | `0` | Offset de audio (compensacion) |
| `auto_preview_song` | `bool` | `true` | Vista previa automatica de canciones |
| `play_menu_music` | `bool` | `true` | Musica de menu activa |

#### Configuracion del HUD

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `display_true_combo` | `bool` | `true` | Mostrar combo real |
| `show_config` | `bool` | `true` | Mostrar configuracion en pantalla |
| `enable_grid` | `bool` | `false` | Mostrar grilla |
| `enable_border` | `bool` | `true` | Mostrar bordes |
| `show_hp_bar` | `bool` | `true` | Barra de vida visible |
| `show_timer` | `bool` | `true` | Temporizador visible |
| `show_cursor` | `bool` | `true` | Cursor visible |
| `show_accuracy_bar` | `bool` | `true` | Barra de precision |
| `show_letter_grade` | `bool` | `true` | Letra de grado visible |
| `simple_hud` | `bool` | `false` | HUD simplificado |
| `faraway_hud` | `bool` | `true` | HUD alejado (perspectiva) |
| `friend_position` | `int` | `FRIEND_BEHIND_GRID` | Posicion del avatar de amigo |

---

### Sistema de cola

Permite reproducir multiples canciones en secuencia.

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `queue_active` | `bool` | `false` | Cola activa |
| `queue_pos` | `int` | `0` | Posicion actual en la cola |
| `song_queue` | `Array` | `[]` | Lista de canciones en cola |
| `just_ended_queue` | `bool` | `false` | Se acaba de terminar la cola |

**Metodos de cola:**

```gdscript
# Prepara la cola para iniciar reproduccion
func prepare_queue():
    record_replays = false
    queue_active = true
    queue_pos = 0
    # ... reinicia contadores ...

# Avanza a la siguiente cancion en la cola
func get_next() -> Song:
    queue_pos += 1
    # Acumula estadisticas (misses, hits, combo...)
    if song_end_type == Globals.END_GIVEUP or queue_pos == song_queue.size():
        just_ended_queue = true
        queue_active = false
        return null
    return song_queue[queue_pos]
```

---

### VR

Soporte para realidad virtual con multiples plataformas.

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `vr` | `bool` | `false` | VR esta activo |
| `fake_vr` | `bool` | `false` | Modo VR simulado (debug) |
| `vr_available` | `bool` | `false` | Hardware VR detectado |
| `vr_interface` | `ARVRInterface` | `null` | Interfaz ARVR activa |
| `vr_player` | `VRPlayer` | `null` | Nodo del jugador VR |
| `vr_left_handed` | `bool` | `false` | Modo zurdo |
| `vr_controller_type` | `int` | `VR_GENERIC` | Tipo de controlador |

**`start_vr()`** inicializa el hardware VR:

1. Desactiva HDR y vsync
2. Fija target FPS a 90
3. Si se mantiene `SHIFT`, activa `fake_vr` (modo debug sin hardware)
4. Configura los bindings de input (grip, trigger, menu)
5. Instancia `VRPlayer.tscn` en la raiz
6. Cambia el menu target a `vr/vrmenu.tscn`

---

### Estado de fin de cancion

Almacena los resultados de la ultima cancion jugada para mostrar en la pantalla de resultados:

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `just_ended_song` | `bool` | Se acaba de terminar una cancion |
| `song_end_type` | `int` | Tipo de fin (`END_PASS`, `END_FAIL`, `END_GIVEUP`) |
| `song_end_misses` | `int` | Notas falladas |
| `song_end_hits` | `int` | Notas acertadas |
| `song_end_total_notes` | `int` | Total de notas en el mapa |
| `song_end_position` | `float` | Posicion alcanzada (ms) |
| `song_end_pause_count` | `int` | Cantidad de veces que se pauso |
| `song_end_accuracy_str` | `String` | Precision formateada como texto |
| `song_end_time_str` | `String` | Tiempo formateado como texto |
| `song_end_length` | `float` | Duracion total de la cancion |
| `song_end_combo` | `int` | Combo maximo alcanzado |

---

### Replay

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `replay` | `Replay` | - | Objeto de replay actual |
| `replay_path` | `String` | `""` | Ruta del archivo de replay |
| `was_replay` | `bool` | `false` | La ultima partida fue una repeticion |
| `replaying` | `bool` | `false` | Se esta reproduciendo un replay |
| `record_replays` | `bool` | `false` | Grabar replays habilitado |
| `alt_cam` | `bool` | `false` | Camara alternativa en replay |
| `record_limit` | `int` | `0` | Limite de replays guardados |
| `record_mode` | `int` | `1` | Modo de grabacion |

> **Nota:** Cuando `replaying` es `true`, varias propiedades como `approach_rate`, `spawn_distance`, `fov`, `parallax` y `fade_length` consultan los valores almacenados en `replay.settings` en lugar de los valores actuales del jugador.

---

### Personal Bests y estado de mods

El sistema de records personales genera una cadena unica (PB string) que codifica la combinacion exacta de mods y settings activos:

```gdscript
func generate_pb_str(for_pb: bool = false) -> String:
    # Ejemplo de salida: "hbox:1.14;hitw:55;s:="
    # Codifica: speed, health model, hitwindow, hitbox, approach_rate,
    #           y todos los mods activos
```

Esto permite almacenar records separados por combinacion de mods, de forma que cambiar la velocidad o activar un modificador no sobrescribe un record obtenido con otra configuracion.

---

## init.gd (Punto de entrada)

- **Extiende**: `Node`
- **Escena**: `scenes/init.tscn`
- **Proposito**: Pantalla de carga que muestra el progreso de inicializacion y transiciona al menu principal.

### Variables

| Variable | Tipo | Default | Descripcion |
|----------|------|---------|-------------|
| `thread` | `Thread` | `Thread.new()` | Thread de inicializacion |
| `target` | `String` | `Rhythia.menu_target` | Escena destino (menu) |
| `leaving` | `bool` | `false` | En proceso de transicion |
| `black_fade_target` | `bool` | `false` | Objetivo del fade negro |
| `black_fade` | `float` | `0` | Valor actual del fade (0-1) |

### Flujo de ejecucion

1. **`_ready()`**:
   - Despausa el arbol de escenas
   - Inicializa fade negro a opaco (`black_fade = 1`)
   - Conecta la senal `init_stage_reached` de Rhythia al metodo `stage()`
   - Solicita permisos del SO (`OS.request_permissions()`)
   - Espera 0.5 segundos, luego maximiza la ventana si esta configurado
   - Si no es la primera inicializacion, llama directamente a `stage("", true)`
   - Si es primera init y ya se hizo una previamente, inicia thread `Rhythia.do_init()`
   - Configura Discord RPC con estado "Initialization"

2. **`stage(text, done)`**:
   - Actualiza el `Label2` con el texto de progreso
   - Si `done == true`: cambia texto a "Loading menu" y encola la carga del menu via `RQueue.queue_resource()`

3. **`_process(delta)`**:
   - Anima el fade negro suavemente (0.3 segundos de transicion)
   - Verifica si el recurso del menu esta listo via `RQueue.is_ready()`
   - Cuando el recurso esta listo y el fade alcanza opacidad total, transiciona a la escena del menu

---

## Intro.gd (Splash/Intro)

- **Extiende**: `Spatial`
- **Escena**: `scenes/Intro.tscn`
- **Proposito**: Secuencia de splash animada con el avatar del juego antes del menu principal.
- **Puede desactivarse** estableciendo `disable_intro: true` en `user://settings.json`.

### Variables

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `running` | `bool` | La animacion esta en ejecucion |
| `panning` | `bool` | La camara esta haciendo paneo |
| `ifading` | `bool` | (no utilizado en la logica actual) |
| `fading` | `bool` | La escena esta desvaneciendose |
| `can_skip` | `bool` | Se puede saltar la intro |
| `can_skip2` | `bool` | Se puede saltar la segunda fase |

### Flujo de la secuencia

1. **Inicio (0-4s)**: Pantalla negra, corrige posiciones del avatar
2. **Animacion (4-5s)**: Inicia animacion "Float" del avatar, `running = true`
3. **Musica (5s)**: Reproduce audio, `can_skip = true`
4. **Paneo (11.5s)**: Cambia a `Camera2`, `panning = true`
5. **Fade out (25.5s)**: `fading = true`, desvanecer a negro
6. **Transicion (29.5s)**: Cambia a `scenes/init.tscn`

El jugador puede saltar la intro en cualquier momento despues de que `can_skip` sea `true`, presionando la accion `pause` o tocando la pantalla en Android.

### Contenido especial

La intro tiene logica para personalizar el avatar segun condiciones especiales:
- **Lacunella**: Muestra pelo especial si `Rhythia.is_lacunella_enabled()` y no es 7 o 19 de junio
- **Fechas especiales (7 y 19 de junio)**: Muestra un avatar alternativo con pelo y orejas diferentes

---

## Diagrama de conexiones

```
┌──────────────────────────────────────────────────────┐
│                  FLUJO DE INICIO                      │
├──────────────────────────────────────────────────────┤
│                                                       │
│  project.godot                                        │
│       │                                               │
│       ▼                                               │
│  Globals._ready()                                     │
│       │── Crea thread → Rhythia.do_init()             │
│       │── Carga UI managers (confirm, string,         │
│       │   filesel, notify)                            │
│       │── Parsea argumentos cmdline                   │
│       │── Lee settings.json (disable_intro?)          │
│       │                                               │
│       ▼                                               │
│  Intro.tscn (opcional, si disable_intro != true)      │
│       │── Animacion del avatar (~29s)                 │
│       │── Puede saltarse con pause/tap                │
│       │                                               │
│       ▼                                               │
│  init.tscn                                            │
│       │── Conecta init_stage_reached                  │
│       │── Muestra progreso de inicializacion          │
│       │── Precarga menu via RQueue                    │
│       │── Fade out cuando el recurso esta listo       │
│       │                                               │
│       ▼                                               │
│  menu2.tscn (menu principal)                          │
│       │── Usa registros de Rhythia para contenido     │
│       │── Emite senales de seleccion                  │
│       │                                               │
│       ▼                                               │
│  songload.tscn → song player (gameplay)               │
└──────────────────────────────────────────────────────┘
```

### Relacion entre Globals y Rhythia

```
┌─────────────────────┐         ┌─────────────────────┐
│     Globals.gd      │         │     Rhythia.gd      │
│  (Autoload #1)      │         │  (Autoload #2)      │
├─────────────────────┤         ├─────────────────────┤
│                     │         │                     │
│  Enums y constantes │◄────────│  Usa enums para     │
│  (RS_*, SPEED_*,    │         │  estados y configs   │
│   DIFF_*, etc.)     │         │                     │
│                     │         │  Registros:          │
│  UI Managers:       │         │  - registry_song     │
│  - confirm_prompt   │         │  - registry_colorset │
│  - string_prompt    │         │  - registry_world    │
│  - file_sel         │         │  - registry_mesh     │
│  - notify_gui       │         │  - registry_effect   │
│                     │         │                     │
│  Utilidades:        │         │  Estado de juego:    │
│  - p()              │◄────────│  - selected_song     │
│  - comma_sep()      │         │  - mod_* flags       │
│  - get_files_rec()  │         │  - song_end_*        │
│  - notify()         │         │  - replay            │
│                     │         │  - song_queue        │
│  speed_multi[]      │◄───────►│  custom_speed        │
│                     │         │  (se actualiza en    │
│                     │         │   speed_multi[7])    │
└─────────────────────┘         └─────────────────────┘
```

### Flujo de bus de audio (configurado en `Rhythia._ready()`)

```
Master (50%)
├── Music (50%)
├── HitSound (30%)
├── MissSound (60%)
├── FailSound (60%)
├── PBSound (60%)
└── OtherSound (fail_asp)
```
