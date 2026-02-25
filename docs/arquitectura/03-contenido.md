# Sistema de Contenido

El sistema de contenido de Sound Space Plus (Rhythia) gestiona todos los recursos del juego:
canciones, esquemas de color, mundos de fondo, meshes de notas, efectos de notas y replays.
Se organiza a traves de un patron **Registry** que actua como catalogo centralizado con
indices paralelos para busquedas eficientes.

---

## Tabla de contenidos

1. [Registry - Registro de contenido](#1-registry---registro-de-contenido)
2. [Song - Modelo de cancion](#2-song---modelo-de-cancion)
3. [Note - Entidad visual de nota](#3-note---entidad-visual-de-nota)
4. [NoteMesh - Estilo visual de mesh](#4-notemesh---estilo-visual-de-mesh)
5. [NoteEffect - Efecto de particulas](#5-noteeffect---efecto-de-particulas)
6. [ColorSet - Esquema de colores](#6-colorset---esquema-de-colores)
7. [BackgroundWorld - Mundo de fondo](#7-backgroundworld---mundo-de-fondo)
8. [Replay - Grabacion y reproduccion](#8-replay---grabacion-y-reproduccion)
9. [Diagramas de arquitectura](#9-diagramas-de-arquitectura)

---

## 1. Registry - Registro de contenido

**Archivo:** `scripts/content/Registry.gd`
**Extiende:** `Resource`
**Nombre de clase:** `Registry`

### Proposito

`Registry` es el contenedor principal para colecciones de contenido del juego. Almacena
items de cualquier tipo soportado y mantiene indices paralelos para permitir busquedas
rapidas por ID, nombre, creador, dificultad, rareza y tipo. Soporta subregistros anidados
para organizar contenido en paquetes (como DLC).

### Senal

| Senal              | Descripcion                                      |
|--------------------|--------------------------------------------------|
| `done_loading_reg` | Emitida cuando el registro termina de cargarse   |
| `percent_progress` | Emitida para reportar progreso de carga          |

### Estructura de datos

El registro utiliza **arrays paralelos** como sistema de indexacion. Cada item agregado
ocupa la misma posicion en todos los arrays de indice, lo que permite acceso O(1) por
posicion y busqueda lineal por cualquier campo.

```
items[0]           = Song(...)
idx_id[0]          = "mi_cancion_001"
idx_name[0]        = "Mi Cancion"
idx_creator[0]     = "Artista"
idx_difficulty[0]  = 3
idx_rarity[0]      = null
idx_type[0]        = "Song"
```

| Propiedad           | Tipo         | Descripcion                                        |
|---------------------|--------------|----------------------------------------------------|
| `items`             | `Array`      | Todos los items almacenados en el registro         |
| `idx_id`            | `Array`      | Indice paralelo de IDs                             |
| `idx_name`          | `Array`      | Indice paralelo de nombres                         |
| `idx_creator`       | `Array`      | Indice paralelo de creadores                       |
| `idx_difficulty`    | `Array`      | Indice paralelo de dificultades                    |
| `idx_rarity`        | `Array`      | Indice paralelo de rarezas                         |
| `idx_type`          | `Array`      | Indice paralelo de tipos (string)                  |
| `has_subregistries` | `bool`       | Indica si contiene subregistros anidados           |
| `fast_idc`          | `Dictionary` | Cache de ID a indice para eliminacion rapida       |

### Tipos soportados

El metodo `add_item()` acepta los siguientes tipos de contenido:

| Tipo              | Campos indexados                  | Notas                            |
|-------------------|-----------------------------------|----------------------------------|
| `Song`            | id, name, creator, difficulty     | Verifica duplicados por ID       |
| `ColorSet`        | id, name, creator                 | Reemplaza si ya existe el ID     |
| `BackgroundWorld` | id, name, creator                 | Reemplaza si ya existe el ID     |
| `NoteMesh`        | id, name, creator                 | Reemplaza si ya existe el ID     |
| `NoteEffect`      | id, name, creator                 | Reemplaza si ya existe el ID     |
| `Registry`        | (sin indices)                     | Marcado como subregistro         |

### Metodos principales

#### `add_item(item, subregistry:bool=false, replaceSongs:bool=false) -> bool`

Agrega un item al registro y actualiza todos los indices paralelos. El comportamiento
varia segun el tipo:

- **Subregistro:** Si `subregistry=true`, agrega como Registry anidado sin indexar campos.
- **Song:** Si `replaceSongs=false` (por defecto), rechaza canciones con ID duplicado
  retornando `false`. Si `replaceSongs=true`, elimina la cancion anterior antes de agregar.
- **Otros tipos:** Siempre reemplaza items con el mismo ID via `check_and_remove_id()`.

#### `check_and_remove_id(id:String)`

Busca un item por ID en `idx_id`. Si lo encuentra, elimina la entrada de todos los
arrays paralelos y del cache `fast_idc`. Esto mantiene la consistencia entre indices.

#### `get_items() -> Array`

Retorna todos los items. Si el registro contiene subregistros (`has_subregistries=true`),
aplana recursivamente llamando `get_items()` en cada subregistro de tipo `"Registry"`.
Los items que no son registros se agregan directamente.

#### `get_item(value, searchType:int, checkSubRegistries:bool=true)`

Busca un item por valor. Con `SEARCH_ID`, busca primero en `idx_id` con `find()`, luego
hace comparacion de strings, y finalmente busca recursivamente en subregistros.

#### `add_sspm_map(path:String) -> Song`

Crea una nueva instancia de `Song`, llama `load_from_sspm(path)` y agrega el resultado
al registro. Si la carga falla (retorna un String de error), imprime el error y retorna
`null`.

#### `add_sspm_cached_map(path:String, cache:Dictionary) -> bool`

Restaura una cancion desde datos cacheados previamente serializados. Llama
`load_from_cache(cache)` en una nueva instancia de `Song`. Retorna `true` si tiene exito.

#### `make_sspm_cache(_v:int) -> Dictionary`

Genera un diccionario serializable con los caches de todas las canciones en formato SSPM
o SSPM2. Itera sobre `items` y llama `make_cache()` en cada cancion cuyo tipo sea
`MAP_SSPM` o `MAP_SSPM2`. La clave es `filePath` y el valor es el cache de la cancion.

#### `add_vulnus_map(folder_path:String) -> Song`

Carga un mapa en formato Vulnus desde una carpeta. Si la cancion tiene multiples
dificultades (determinado por `get_vulnus_map_difficulty_list()`), carga cada dificultad
como una instancia separada de `Song` y las agrega individualmente al registro.

#### `load_png(file:String) -> Texture`

Delegacion a `Globals.imageLoader.load_file(file)` para cargar imagenes PNG.

#### `load_registry_file(path:String, regtype:int, regDisplayName:String="")`

Carga un archivo de registro de texto. Para registros de tipo `REGISTRY_MAP`, parsea
cada linea con formato `type:~:id:~:name:~:creator:~:difficulty:~:rarity:~:musicPath:~:dataOrPath`.
Soporta multiples tipos de referencia a archivos (`MAPR_FILE`, `MAPR_FILE_ABSOLUTE`,
`MAPR_FILE_SONG_ABSOLUTE`, `MAPR_EMBEDDED`, `MAPR_EMBEDDED_SONG_ABSOLUTE`). Usa `yield`
cada 12 items para ceder control al hilo principal y evitar bloqueos.

#### `search(value, searchType:int, checkSubRegistries:bool=true) -> Array`

Busqueda avanzada por texto (stub, no implementada actualmente).

---

## 2. Song - Modelo de cancion

**Archivo:** `scripts/content/game/Song.gd`
**Extiende:** `Resource`
**Nombre de clase:** `Song`

### Proposito

`Song` es el modelo de datos central para una cancion o mapa. Contiene metadatos
(nombre, creador, dificultad), datos de notas, informacion de formato, cover art
con carga diferida y personal bests persistentes. Es el recurso mas complejo del
sistema de contenido.

### Senal

| Senal        | Descripcion                                    |
|--------------|------------------------------------------------|
| `downloaded` | Emitida cuando una cancion online se descarga  |

### Metadatos

| Propiedad    | Tipo     | Descripcion                                          |
|--------------|----------|------------------------------------------------------|
| `id`         | `String` | Identificador unico de la cancion                    |
| `name`       | `String` | Nombre visible de la cancion                         |
| `song`       | `String` | Nombre del tema musical                              |
| `creator`    | `String` | Creador del mapa                                     |
| `difficulty` | `int`    | Nivel de dificultad (-1 a 4, usa `Globals.DIFF_*`)   |
| `rating`     | `int`    | Calificacion por estrellas (0-5)                     |

### Datos de notas y audio

| Propiedad       | Tipo         | Descripcion                                      |
|-----------------|--------------|--------------------------------------------------|
| `rawData`       | `String`     | Datos crudos de notas sin parsear                |
| `notes`         | `Array`      | Array de notas parseadas                         |
| `note_count`    | `int`        | Cantidad total de notas                          |
| `marker_count`  | `int`        | Cantidad de marcadores                           |
| `markers`       | `Dictionary` | Marcadores/eventos del mapa                      |
| `marker_types`  | `Array`      | Tipos de marcadores disponibles                  |
| `custom_data`   | `Dictionary` | Datos custom embebidos en el formato             |
| `last_ms`       | `float`      | Timestamp de la ultima nota en milisegundos      |
| `musicFile`     | `String`     | Ruta al archivo de audio                         |
| `initFile`      | `String`     | Ruta al archivo de inicializacion de datos       |
| `filePath`      | `String`     | Ruta al archivo del mapa en disco                |
| `marker_hash`   | `PoolByteArray` | Hash de los marcadores                        |

### Formato binario SSPM - Tipos de datos

El formato SSPM define tipos de datos para serializacion binaria:

| Constante      | Valor  | Descripcion                  |
|----------------|--------|------------------------------|
| `DT_UNKNOWN`   | `0x00` | Tipo desconocido             |
| `DT_INT_8`     | `0x01` | Entero sin signo 8 bits     |
| `DT_INT_16`    | `0x02` | Entero sin signo 16 bits    |
| `DT_INT_32`    | `0x03` | Entero sin signo 32 bits    |
| `DT_INT_64`    | `0x04` | Entero sin signo 64 bits    |
| `DT_FLOAT_32`  | `0x05` | Flotante 32 bits             |
| `DT_FLOAT_64`  | `0x06` | Flotante 64 bits             |
| `DT_POSITION`  | `0x07` | Posicion (par de coordenadas)|
| `DT_BUFFER`    | `0x08` | Buffer de bytes              |
| `DT_STRING`    | `0x09` | Cadena de texto              |
| `DT_BUFFER_LONG`| `0x0a`| Buffer de bytes largo        |
| `DT_STRING_LONG`| `0x0b`| Cadena de texto larga        |
| `DT_ARRAY`     | `0x0c` | Array de elementos           |

### Formatos de mapa soportados

| Formato      | Valor | Descripcion                                            |
|--------------|-------|--------------------------------------------------------|
| `MAP_TXT`    | 0     | Texto plano: `"x,y,ms\n"` por nota. Formato legacy    |
| `MAP_RAW`    | 1     | Binario crudo empaquetado, sin metadatos               |
| `MAP_VULNUS` | 2     | Formato Vulnus con multiples dificultades y config JSON|
| `MAP_SSPM`   | 3     | SSPM v1: binario con firma `"SS+m"`, cover embebida   |
| `MAP_NET`    | 4     | Referencia a descarga remota, se convierte al descargar|
| `MAP_SSPM2`  | 5     | SSPM v2: version mejorada con soporte de markers       |

### Flags de estado

| Propiedad              | Tipo   | Descripcion                                           |
|------------------------|--------|-------------------------------------------------------|
| `is_broken`            | `bool` | El mapa tiene errores y no se puede reproducir        |
| `is_builtin`           | `bool` | Es una cancion incluida con el juego                  |
| `is_online`            | `bool` | Es una cancion de la base de datos online             |
| `converted`            | `bool` | Fue convertida de otro formato                        |
| `should_reload_on_play`| `bool` | Debe recargar datos al reproducirse                   |
| `sspm_song_stored`     | `bool` | El audio esta embebido en el archivo SSPM             |
| `download_url`         | `String`| URL de descarga para canciones online                 |
| `has_combo`            | `bool` | Indica si tiene datos de combo                        |

### Cover art (carga diferida)

| Propiedad      | Tipo      | Descripcion                                       |
|----------------|-----------|---------------------------------------------------|
| `has_cover`    | `bool`    | Indica si tiene imagen de portada                 |
| `cover`        | `Texture` | Textura de portada (setter getter con lazy-load)  |
| `cover_offset` | `int`     | Offset en bytes dentro del archivo SSPM           |
| `cover_length` | `int`     | Longitud en bytes de la imagen de portada         |

La propiedad `cover` usa un setter/getter (`setget , _get_cover`). El getter
`_get_cover()` carga la imagen solo cuando se accede por primera vez, leyendo
los bytes desde el archivo SSPM en la posicion `cover_offset` con longitud
`cover_length`. Si `has_cover` es `false`, retorna `null` sin intentar carga.

### Personal Bests (PBs)

El sistema de records personales persiste en archivos binarios con formato propio.

**Formato del archivo `.pb`:**

| Campo          | Tipo              | Descripcion                                |
|----------------|-------------------|--------------------------------------------|
| Firma          | `5 bytes`         | `[0x53, 0x53, 0x2B, 0x70, 0x42]` = "SS+pB"|
| Version        | `u16`             | Version del formato (actualmente 3)        |

**Estructura por cada Personal Best:**

| Campo          | Tipo   | Descripcion                          |
|----------------|--------|--------------------------------------|
| `key`          | String | Clave del PB (combinacion de mods)   |
| `has_passed`   | `u8`   | Si se completo la cancion            |
| `pauses`       | `u16`  | Cantidad de pausas utilizadas        |
| `hit_notes`    | `u32`  | Notas acertadas                      |
| `total_notes`  | `u32`  | Total de notas                       |
| `position`     | `u32`  | Posicion alcanzada                   |
| `length`       | `u32`  | Duracion total                       |
| `max_combo`    | `u16`  | Combo maximo alcanzado               |

Los archivos se almacenan en `user://bests/{song_id}.pb`.

### Metodos clave

#### `load_from_sspm(path:String)`

Carga una cancion desde un archivo SSPM (v1 o v2). Lee la firma binaria `"SS+m"`,
determina la version, parsea metadatos (id, nombre, creador, dificultad) y extrae
la referencia al cover art (offset y longitud para carga diferida). Si el formato
es SSPM v2, tambien lee marcadores y datos custom. Retorna `null` en exito o un
String de error si falla.

#### `load_from_cache(cache:Dictionary)`

Restaura los metadatos de una cancion desde un diccionario cacheado previamente
generado por `make_cache()`. No carga datos de notas ni audio; estos se cargan
bajo demanda al reproducir.

#### `make_cache() -> Dictionary`

Serializa los metadatos esenciales de la cancion a un diccionario para persistencia
rapida. Incluye id, nombre, creador, dificultad, tipo, ruta, cover info y conteo
de notas.

#### `load_from_vulnus_map(folder:String, diff_idx:int=0) -> Song`

Carga un mapa en formato Vulnus desde una carpeta. Lee la configuracion JSON,
extrae la dificultad especificada por `diff_idx` y configura la cancion.
Retorna la instancia de Song configurada o `null` si falla.

#### `load_from_db_data(data:Dictionary)`

Crea una cancion desde datos de la API online. Configura `is_online=true`,
establece `download_url` y marca el tipo como `MAP_NET`.

#### `setup_from_file(init_file:String, music_file:String)`

Prepara la cancion para reproduccion desde archivos locales. Asigna las rutas
de datos y audio, y establece el tipo segun la extension del archivo.

#### `read_notes() -> Array`

Parsea las notas desde `rawData` segun el tipo de mapa. Para `MAP_TXT`, separa
por lineas y comas (`x,y,ms`). Para formatos binarios, lee secuencias de bytes.
Retorna un array de arrays `[x, y, ms]`.

#### `stream() -> AudioStream`

Obtiene el `AudioStream` del archivo de musica. Para canciones con audio embebido
en SSPM, extrae los bytes del archivo y los decodifica.

#### `load_pbs()` / `save_pbs()`

`load_pbs()` lee el archivo `user://bests/{id}.pb`, verifica la firma y version,
y carga todos los PBs al diccionario `pb_data`. Solo carga una vez (controlado
por `pbs_loaded`).

`save_pbs()` serializa `pb_data` al archivo binario con la firma y version
correspondientes.

#### `get_pb(pb_str:String) -> Dictionary`

Obtiene el personal best para una combinacion especifica de modificadores.
La clave `pb_str` codifica el estado de los mods activos.

#### `is_pb_better(old:Dictionary, new:Dictionary) -> bool`

Compara dos PBs. Un PB nuevo es mejor si: tiene mayor porcentaje de notas
acertadas, o igual porcentaje pero con menos pausas, o se paso la cancion
cuando antes no se habia pasado.

#### `set_pb_if_better(pb_str:String, pb:Dictionary)`

Compara el PB nuevo con el existente y lo actualiza solo si es mejor.
Llama `save_pbs()` automaticamente si hay actualizacion.

#### `is_valid_id(txt:String) -> bool`

Valida que un texto tenga el formato correcto para ser un ID de cancion.

---

## 3. Note - Entidad visual de nota

**Archivo:** `scripts/content/game/Note.gd`
**Extiende:** `Spatial`
**Nombre de clase:** `Note`

### Proposito

`Note` representa la entidad visual de una nota individual en el espacio 3D.
Es el **sistema legacy** de renderizado de notas; el sistema preferido actualmente
es **MultiMesh**, que agrupa todas las notas en una sola llamada de dibujo para
mejor rendimiento.

### Propiedades

| Propiedad          | Tipo      | Descripcion                                       |
|--------------------|-----------|---------------------------------------------------|
| `id`               | `int`     | Identificador unico de la nota (-1 por defecto)   |
| `notems`           | `float`   | Timestamp de la nota en milisegundos               |
| `state`            | `int`     | Estado actual (usa `Globals.NSTATE_*`)             |
| `col`              | `Color`   | Color asignado a la nota                           |
| `real_position`    | `Vector2` | Posicion real en el grid (antes de modificadores)  |
| `chaos_offset`     | `Vector2` | Offset aleatorio del mod chaos                    |
| `earthquake_offset`| `Vector2` | Offset aleatorio del mod earthquake               |
| `was_visible`      | `bool`    | Si la nota ya fue visible alguna vez               |
| `spawn_effect_t`   | `float`   | Temporizador del efecto de aparicion               |
| `speed_multi`      | `float`   | Multiplicador de velocidad del padre               |
| `grid_pushback`    | `float`   | Distancia de pushback del grid (default 0.1)       |

### Fade in/out

La nota soporta desvanecimiento visual controlado por distancia:

| Propiedad          | Default | Descripcion                                  |
|--------------------|---------|----------------------------------------------|
| `fade_in_enabled`  | `true`  | Activar fade in                              |
| `fade_in_start`    | `8`     | Distancia donde empieza a aparecer           |
| `fade_in_end`      | `6`     | Distancia donde es completamente visible     |
| `fade_out_enabled` | `false` | Activar fade out (usado por mod ghost)       |
| `fade_out_start`   | `3`     | Distancia donde empieza a desaparecer        |
| `fade_out_end`     | `1`     | Distancia donde es completamente invisible   |

### Materiales shader

Cada nota tiene dos materiales shader duplicados para personalizacion independiente:

- `mat_s` (`ShaderMaterial`) - Material solido para superficies opacas
- `mat_t` (`ShaderMaterial`) - Material transparente para superficies con alpha

Ambos exponen el parametro `notecolor` y `fade` para control de color y transparencia.

### Metodos

#### `reposition(ms:float, approachSpeed:float) -> bool`

Metodo principal llamado cada frame. Calcula la posicion Z de la nota segun el tiempo
actual y la velocidad de aproximacion. Aplica modificadores activos:

- **Chaos:** Desplaza la nota con un offset aleatorio que se atenua al acercarse
- **Earthquake:** Aplica vibracion aleatoria proporcional a la distancia
- **Hardrock:** Escala la posicion x/y por 1.5x
- **Visual approach:** Actualiza indicador de aproximacion
- **Note spin:** Rota la nota en los ejes configurados
- **Fade in/out:** Ajusta alpha segun la distancia

Retorna `true` si la nota es visible, `false` si debe ocultarse.

#### `check(cpos:Vector3, prevpos:Vector3=Vector3.ZERO) -> bool`

Verifica si el cursor esta dentro del hitbox de la nota. Si se esta reproduciendo
un replay (version != 1), delega a `Rhythia.replay.should_hit(id)`. En modo normal,
compara la posicion del cursor con los limites del hitbox (configurable via
`Rhythia.note_hitbox_size`).

#### `setup(color:Color)`

Configura la nota con un color. Duplica los materiales shader, aplica el color con
la opacidad configurada (`Rhythia.note_opacity`), y configura los modificadores
activos (chaos, earthquake, ghost, nearsighted). Cada modificador ajusta los
parametros de fade y offset correspondientes.

---

## 4. NoteMesh - Estilo visual de mesh

**Archivo:** `scripts/content/game/NoteMesh.gd`
**Extiende:** `Resource`
**Nombre de clase:** `NoteMesh`

### Proposito

Define un estilo visual de mesh para las notas. Puede ser una forma geometrica
predefinida (cubo, esfera) o un modelo OBJ personalizado cargado desde archivo.

### Propiedades

| Propiedad   | Tipo      | Descripcion                                    |
|-------------|-----------|------------------------------------------------|
| `id`        | `String`  | Identificador unico del mesh                  |
| `name`      | `String`  | Nombre visible                                 |
| `creator`   | `String`  | Creador del mesh                               |
| `path`      | `String`  | Ruta al archivo del mesh (`.obj` o recurso)    |
| `cover`     | `Texture` | Imagen de preview del mesh                     |
| `has_cover` | `bool`    | Si tiene imagen de preview                     |

### Constructor

```gdscript
func _init(idI:String, nameI:String, pathI:String, creatorI:String="Unknown", coverI:String="")
```

Inicializa el mesh con sus propiedades. Si se proporciona una ruta de cover (`coverI`),
intenta cargar la imagen PNG. El creador es `"Unknown"` por defecto.

---

## 5. NoteEffect - Efecto de particulas

**Archivo:** `scripts/content/game/NoteEffect.gd`
**Extiende:** `Resource`
**Nombre de clase:** `NoteEffect`

### Proposito

Define un efecto visual de particulas que se reproduce al acertar o fallar notas.
Los efectos incluyen ondas (ripple), fragmentos (shards) y visualizacion de
puntuacion (score). Cada efecto es una escena `.tscn` independiente.

### Propiedades

| Propiedad | Tipo     | Decorador               | Descripcion                     |
|-----------|----------|-------------------------|---------------------------------|
| `id`      | `String` | `export`                | Identificador unico del efecto  |
| `name`    | `String` | `export`                | Nombre visible                  |
| `creator` | `String` | `export`                | Creador del efecto              |
| `path`    | `String` | `export(FILE, "*.tscn")`| Ruta a la escena del efecto    |

### Constructor

```gdscript
func _init(idI:String, nameI:String, pathI:String, creatorI:String="Unknown")
```

Inicializa el efecto con sus propiedades. La ruta apunta a una escena `.tscn` que
contiene el sistema de particulas y la logica de animacion.

---

## 6. ColorSet - Esquema de colores

**Archivo:** `scripts/content/game/ColorSet.gd`
**Extiende:** `Resource`
**Nombre de clase:** `ColorSet`

### Proposito

Define un esquema de colores que se asigna a las notas segun su posicion u orden
de aparicion. Los colores se ciclan a traves del array, y opcionalmente se pueden
espejar para crear patrones simetricos.

### Propiedades

| Propiedad     | Tipo           | Descripcion                                     |
|---------------|----------------|-------------------------------------------------|
| `id`          | `String`       | Identificador unico del esquema                |
| `name`        | `String`       | Nombre visible                                  |
| `creator`     | `String`       | Creador del esquema                             |
| `real_colors` | `Array`        | Array interno de colores base                   |
| `colors`      | `Array<Color>` | Array de colores procesado (con mirror si aplica)|
| `mirror`      | `bool`         | Si se deben espejar los colores                 |

### Sistema de espejo (mirror)

Cuando `mirror=true`, el getter `_get_colors()` genera un array que va de ida y vuelta
a traves de los colores base. Por ejemplo, con colores `[A, B, C, D]`, el resultado
espejado seria `[A, B, C, D, C, B]` (omite el primero y ultimo en la vuelta). Esto
crea transiciones de color suaves y simetricas.

### Constructor

```gdscript
func _init(colorsI:Array, idI:String, nameI:String, creatorI:String="Unknown")
```

El setter `_set_colors()` guarda en `real_colors` y limpia el cache de `colors`.

---

## 7. BackgroundWorld - Mundo de fondo

**Archivo:** `scripts/content/game/BackgroundWorld.gd`
**Extiende:** `Resource`
**Nombre de clase:** `BackgroundWorld`

### Proposito

Define un mundo 3D de fondo que se muestra durante el gameplay. Cada mundo es una
escena `.tscn` con su propia geometria, iluminacion y efectos.

### Propiedades

| Propiedad   | Tipo      | Descripcion                                  |
|-------------|-----------|----------------------------------------------|
| `id`        | `String`  | Identificador unico del mundo                |
| `name`      | `String`  | Nombre visible                               |
| `creator`   | `String`  | Creador del mundo                            |
| `path`      | `String`  | Ruta a la escena del mundo                   |
| `cover`     | `Texture` | Imagen de preview del mundo                  |
| `has_cover` | `bool`    | Si tiene imagen de preview                   |

### Mundos incluidos

El juego incluye mas de 15 mundos de fondo almacenados en `assets/worlds/`:

| Mundo                | Descripcion                                      |
|----------------------|--------------------------------------------------|
| `baseplate`          | Plano base simple                                |
| `classic`            | Mundo clasico de Sound Space                     |
| `cubic`              | Entorno cubico geometrico                        |
| `custom`             | Mundo personalizado por el usuario               |
| `deep_space`         | Espacio profundo con estrellas                   |
| `event_horizon`      | Horizonte de eventos                             |
| `grid`               | Cuadricula iluminada                             |
| `neon_tunnel`        | Tunel de neon con efectos luminosos              |
| `reality_dismissed`  | Entorno abstracto deformado                      |
| `space`              | Espacio exterior                                 |
| `tri_tunnel`         | Tunel triangular                                 |
| `vaporwave`          | Estetica vaporwave retro                         |
| `void`               | Vacio oscuro minimalista                         |
| *(y mas...)*         | Otros mundos contribuidos por la comunidad       |

### Constructor

```gdscript
func _init(idI:String, nameI:String, pathI:String, creatorI:String="Unknown", coverI:String="")
```

Carga la imagen de cover si se proporciona. Para archivos en `res://`, usa `load()`
directamente; para archivos externos, usa `ImageTexture.load()`.

---

## 8. Replay - Grabacion y reproduccion

**Archivo:** `scripts/content/game/Replay.gd`
**Extiende:** `Resource`
**Nombre de clase:** `Replay`

### Proposito

Gestiona la grabacion y reproduccion de replays completos del gameplay. Un replay
captura todas las posiciones del cursor, resultados de cada nota (hit/miss), pausas,
y otros eventos del juego. Permite reproducir una partida exactamente como sucedio.

### Constantes

| Constante    | Valor                                   | Descripcion                    |
|--------------|-----------------------------------------|--------------------------------|
| `file_sig`   | `[0x53, 0x73, 0x2A, 0x52]` = "Ss*R"   | Firma del archivo de replay   |
| `current_sv` | `4`                                     | Version actual del formato    |

### Senales

| Senal          | Descripcion                                    |
|----------------|------------------------------------------------|
| `progress`     | Progreso de carga (0.0 a 1.0)                 |
| `done_loading` | Replay completamente cargado                   |

### Propiedades principales

| Propiedad               | Tipo         | Descripcion                                    |
|-------------------------|--------------|-------------------------------------------------|
| `song`                  | `Song`       | Cancion asociada al replay                      |
| `cursor_positions`      | `Array`      | Posiciones del cursor (Vector3: x, y, ms)       |
| `past_cursor_positions` | `Array`      | Posiciones ya procesadas                        |
| `triggers`              | `Array`      | Eventos/triggers con timestamp                  |
| `past_triggers`         | `Array`      | Triggers ya procesados                          |
| `note_results`          | `Dictionary` | Resultado por nota: `{nid: bool}` (hit/miss)   |
| `settings`              | `Dictionary` | Configuracion de gameplay del replay            |
| `id`                    | `String`     | Identificador unico del replay                 |
| `sv`                    | `int`        | Version del archivo de replay                   |
| `recording`             | `bool`       | Si esta grabando actualmente                    |
| `loaded`                | `bool`       | Si el replay esta cargado                       |
| `autoplayer`            | `bool`       | Si usa autoplayer en vez de replay real          |
| `end_ms`                | `float`      | Timestamp final del replay                      |
| `dance`                 | `DanceMover` | Mover de cursor dance (para autoplayer)         |

### Formato binario del archivo `.sspre`

El archivo de replay (`.sspre`) tiene la siguiente estructura:

**Cabecera:**

| Offset | Tipo      | Descripcion                                    |
|--------|-----------|------------------------------------------------|
| 0      | `4 bytes` | Firma: `[0x53, 0x73, 0x2A, 0x52]`            |
| 4      | `u16`     | Version del formato (sv)                       |
| 6      | `u64`     | Reservado (siempre 0)                          |
| 14     | `line`    | HWID del dispositivo (sv >= 4)                |
| -      | `line`    | ID del replay (song_id.fecha.hora)             |
| -      | `line`    | String de estado (mods activos, pb_str)        |

**Configuracion de gameplay (sv >= 3):**

| Tipo    | Descripcion        |
|---------|--------------------|
| `float` | approach_rate      |
| `float` | spawn_distance     |
| `float` | fade_length        |
| `float` | parallax           |
| `float` | ui_parallax        |
| `float` | grid_parallax      |
| `float` | fov                |
| `u8`    | cam_unlock (0/1)   |
| `float` | edge_drift         |

**Datos de eventos:**

| Tipo  | Descripcion                                |
|-------|--------------------------------------------|
| `u8`  | Reservado                                  |
| `u32` | end_ms (timestamp final, escrito al cerrar)|
| `u32` | sig_count (cantidad de senales)            |

**Senales (repetidas hasta RS_END):**

| Tipo senal | Tipo  | Datos adicionales    | Descripcion                |
|------------|-------|----------------------|----------------------------|
| `RS_CURSOR`| `u8`  | `u32` ms, 2x `float` x/y | Posicion del cursor    |
| `RS_HIT`   | `u8`  | `u32` nid            | Nota acertada              |
| `RS_MISS`  | `u8`  | `u32` nid            | Nota fallada               |
| `RS_PAUSE` | `u8`  | `u32` ms             | Pausa                      |
| `RS_START_UNPAUSE` | `u8` | `u32` ms      | Inicio de reanudar         |
| `RS_CANCEL_UNPAUSE`| `u8` | `u32` ms      | Cancelar reanudacion       |
| `RS_FINISH_UNPAUSE`| `u8` | `u32` ms      | Reanudacion completada     |
| `RS_SKIP`  | `u8`  | `u32` ms             | Salto                      |
| `RS_GIVEUP`| `u8`  | `u32` ms             | Rendicion                  |
| `RS_END`   | `u8`  | *(ninguno)*          | Fin del replay             |

### Flujo de grabacion

```
start_recording(song)
  |
  +--> Abre archivo user://replays/{id}.sspre
  +--> Escribe cabecera (firma, version, HWID, id, estado, settings)
  +--> Reserva espacio para end_ms y sig_count
  |
  v
[Durante gameplay - cada frame]
  |
  +--> store_cursor_pos(ms, x, y)     -- RS_CURSOR
  +--> note_hit(nid)                   -- RS_HIT
  +--> note_miss(nid)                  -- RS_MISS
  +--> store_sig(ms, sig)              -- Senal generica
  +--> store_pause(ms)                 -- RS_PAUSE
  +--> store_giveup(ms)                -- RS_GIVEUP
  |
  v
end_recording()
  |
  +--> Escribe RS_END
  +--> Seek a endms_offset, escribe last_ms y sig_count reales
  +--> Cierra archivo
```

El ID del replay se genera con formato `{song_id}.{year}-{month}-{day}_{hour}-{minute}-{second}`.

### Flujo de reproduccion

```
read_data(from_path)
  |
  +--> Abre y valida firma/version
  +--> Lee metadatos (id, estado, settings)
  +--> Lee todas las senales secuencialmente
  |     +--> RS_CURSOR -> cursor_positions (invertido al final)
  |     +--> RS_HIT/RS_MISS -> note_results[nid] = true/false
  |     +--> RS_PAUSE/UNPAUSE/SKIP/GIVEUP -> triggers[ms, tipo]
  |
  +--> Invierte cursor_positions (stored LIFO, played FIFO)
  +--> emit_signal("done_loading")
  |
  v
[Durante gameplay]
  |
  +--> get_cursor_position(ms)  -- Interpola posicion del cursor entre puntos
  +--> should_hit(nid)           -- NoteManager consulta si nota debe ser hit
  +--> get_signals(ms)           -- Obtiene triggers pendientes
```

### Modo autoplayer

Si `read_data()` se llama sin ruta de archivo, activa el modo autoplayer. En este
modo se usa un `BouncyDanceMover` para calcular las posiciones del cursor
automaticamente y `should_hit()` siempre retorna `true`.

### Metodos de reproduccion

#### `get_cursor_position(ms:float) -> Vector2`

Interpola la posicion del cursor entre dos puntos guardados usando `smoothstep`.
Busca el par de puntos que envuelve el timestamp actual y calcula la posicion
intermedia con `lerp`. En modo autoplayer, delega al `DanceMover`.

#### `should_hit(nid:int) -> bool`

Consulta si una nota especifica debe ser acertada o fallada. En modo autoplayer
siempre retorna `true`. En modo replay, busca en `note_results[nid]`.

#### `get_signals(ms:float) -> Array`

Retorna y consume todos los triggers cuyo timestamp sea menor o igual al tiempo
actual. Los triggers se procesan en orden FIFO desde el frente del array.

---

## 9. Diagramas de arquitectura

### Diagrama de registros

```
┌──────────────────────────────────────────┐
│              REGISTROS                    │
├──────────────────────────────────────────┤
│                                           │
│  Rhythia                                  │
│    ├── registry_song:Registry             │
│    │     ├── Song (local .sspm)           │
│    │     ├── Song (local .txt)            │
│    │     ├── Song (builtin)               │
│    │     └── Subregistry (DLC pack)       │
│    │           ├── Song                   │
│    │           └── Song                   │
│    │                                      │
│    ├── registry_colorset:Registry         │
│    │     ├── ColorSet (default)           │
│    │     └── ColorSet (custom)            │
│    │                                      │
│    ├── registry_world:Registry            │
│    │     ├── BackgroundWorld (classic)    │
│    │     ├── BackgroundWorld (space)      │
│    │     └── ...15+ mundos               │
│    │                                      │
│    ├── registry_mesh:Registry             │
│    │     ├── NoteMesh (cube)             │
│    │     └── NoteMesh (custom .obj)      │
│    │                                      │
│    └── registry_effect:Registry           │
│          ├── NoteEffect (ripple)         │
│          ├── NoteEffect (shards)         │
│          └── NoteEffect (score)          │
└──────────────────────────────────────────┘
```

Cada registro es una instancia independiente de `Registry` almacenada como propiedad
del singleton `Rhythia`. Los registros se cargan durante la inicializacion del juego
en `Rhythia.do_init()` y estan disponibles globalmente.

### Diagrama de formatos de Song

```
┌─────────────────────────────────────────────┐
│          FORMATOS DE MAPA                    │
├─────────────────────────────────────────────┤
│                                              │
│  MAP_TXT (0)    - Texto plano               │
│  ├── "x,y,ms\n" por cada nota               │
│  └── Formato mas simple y legacy             │
│                                              │
│  MAP_RAW (1)    - Binario crudo             │
│  ├── Datos de nota empaquetados              │
│  └── Sin metadatos                           │
│                                              │
│  MAP_VULNUS (2) - Formato Vulnus            │
│  ├── Carpeta con multiples dificultades      │
│  └── Incluye audio y config JSON             │
│                                              │
│  MAP_SSPM (3)   - SSPM v1                   │
│  ├── Binario con metadatos                   │
│  ├── Firma: "SS+m"                           │
│  ├── Incluye cover art embebida              │
│  └── Formato principal                       │
│                                              │
│  MAP_NET (4)    - Red/Online                │
│  ├── Referencia a descarga remota            │
│  └── Se convierte a SSPM al descargar        │
│                                              │
│  MAP_SSPM2 (5)  - SSPM v2                   │
│  ├── Version mejorada del SSPM               │
│  ├── Soporte de markers/eventos              │
│  └── Formato mas reciente                    │
└─────────────────────────────────────────────┘
```

### Flujo de Personal Bests

```
Gameplay → Game.end() → Rhythia.do_pb_check_and_set()
  → Song.get_pb(mod_key) → Song.is_pb_better(old, new)
  → Si mejor: Song.set_pb_if_better() → Song.save_pbs()
  → Archivo binario: user://bests/{song_id}.pb
```

El flujo de PB se activa al finalizar una partida. `Rhythia.do_pb_check_and_set()`
genera la clave del PB basada en los modificadores activos (`generate_pb_str()`),
obtiene el PB existente y lo compara con el resultado actual. Solo se actualiza
si el nuevo resultado es estrictamente mejor.

### Ciclo de vida del contenido

```
[Inicializacion]
  |
  +--> Rhythia.do_init()
  |      |
  |      +--> Escanear directorio de canciones
  |      |      +--> .sspm → Registry.add_sspm_map()
  |      |      +--> carpeta vulnus → Registry.add_vulnus_map()
  |      |      +--> .txt → Registry.load_registry_file()
  |      |
  |      +--> Cargar cache si existe
  |      |      +--> Registry.add_sspm_cached_map()
  |      |
  |      +--> Cargar ColorSets, BackgroundWorlds, NoteMeshes, NoteEffects
  |
  v
[Menu - Seleccion]
  |
  +--> Usuario navega canciones
  |      +--> Song.cover se carga (lazy-load)
  |      +--> Song.load_pbs() para mostrar records
  |
  v
[Gameplay]
  |
  +--> Song.read_notes() → parsear notas
  +--> Song.stream() → obtener audio
  +--> NoteManager crea notas con ColorSet activo
  +--> BackgroundWorld carga escena de fondo
  +--> NoteMesh define forma visual de notas
  +--> NoteEffect define efectos de hit/miss
  |
  v
[Post-Gameplay]
  |
  +--> Verificar y guardar PBs
  +--> Guardar replay si esta habilitado
  +--> Volver al menu
```

---

## Relacion entre componentes

| Componente        | Depende de                    | Usado por                         |
|-------------------|-------------------------------|-----------------------------------|
| `Registry`        | `Globals`, tipos de contenido | `Rhythia`, menu, content manager  |
| `Song`            | `Globals`, `Rhythia`          | `Registry`, `Game`, `NoteManager` |
| `Note`            | `Globals`, `Rhythia`          | `NoteManager` (sistema legacy)    |
| `NoteMesh`        | *(independiente)*             | `Registry`, `NoteManager`         |
| `NoteEffect`      | *(independiente)*             | `Registry`, `Game`                |
| `ColorSet`        | *(independiente)*             | `Registry`, `NoteManager`         |
| `BackgroundWorld` | *(independiente)*             | `Registry`, escena de gameplay    |
| `Replay`          | `Globals`, `Rhythia`, `Song`  | `Game`, `NoteManager`, `Cursor`   |

---

## Patrones de diseno en el sistema de contenido

### Indices paralelos (Registry)

En lugar de usar objetos con multiples campos para busqueda, el registro mantiene
arrays paralelos donde el indice `i` en cada array corresponde al mismo item.
Esto permite busquedas por cualquier campo sin iterar sobre objetos complejos.

### Carga diferida / Lazy-loading (Song.cover)

El cover art de las canciones se almacena como offset y longitud dentro del archivo
SSPM. Solo se carga a memoria cuando se accede a la propiedad `cover`, evitando
cargar cientos de imagenes al iniciar el juego.

### Cache de serializacion (SSPM cache)

Para evitar parsear archivos SSPM completos en cada inicio, el sistema genera un
cache con los metadatos esenciales. En inicios subsiguientes, se restauran las
canciones desde el cache, que es significativamente mas rapido que leer los archivos
binarios completos.

### Formato binario propio (SSPM, PB, Replay)

El proyecto define tres formatos binarios propios, cada uno con su firma de validacion:

| Formato | Firma    | Extension | Proposito                  |
|---------|----------|-----------|----------------------------|
| SSPM    | `SS+m`   | `.sspm`   | Mapas de canciones         |
| PB      | `SS+pB`  | `.pb`     | Personal bests             |
| Replay  | `Ss*R`   | `.sspre`  | Replays de gameplay        |

---

*Documentacion generada para Sound Space Plus (Rhythia) - Motor Godot 3.x*
