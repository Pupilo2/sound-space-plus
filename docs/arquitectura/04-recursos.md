# Sistema de Carga de Recursos

Este documento describe el sistema de carga de recursos de Sound Space Plus (Rhythia), incluyendo los cargadores de audio, imagenes, modelos 3D, archivos ZIP y la cola asincronica de recursos.

---

## Tabla de Scripts

| Script | Ruta | Clase | Proposito |
|--------|------|-------|-----------|
| AudioLoader.gd | `scripts/content/resources/AudioLoader.gd` | `AudioLoader` | Carga de archivos de audio (MP3, OGG, WAV) desde archivos o buffers en memoria |
| ImageLoader.gd | `scripts/content/resources/ImageLoader.gd` | `ImageLoader` | Carga de imagenes (PNG, JPG, BMP, WebP) y generacion de texturas |
| ObjParse.gd | `scripts/content/resources/ObjParse.gd` | `ObjParse` | Parseo de archivos .OBJ (modelos 3D) con soporte de materiales MTL |
| ResourceQueue.gd | `scripts/content/resources/ResourceQueue.gd` | _(Autoload: RQueue)_ | Cola asincronica con hilo para precarga de escenas en segundo plano |
| gdunzip.gd | `scripts/content/resources/gdunzip.gd` | _(Script instanciable)_ | Descompresion de archivos ZIP en memoria usando DEFLATE |

---

## Vision general

Rhythia necesita cargar recursos externos en tiempo de ejecucion: canciones con audio embebido en archivos `.sspm`, imagenes de portada, modelos 3D personalizados para las notas y escenas completas del motor. El sistema de carga se divide en cuatro capas:

1. **Cargadores especializados** (`AudioLoader`, `ImageLoader`, `ObjParse`): detectan el formato por firmas binarias (magic bytes) y construyen objetos nativos de Godot.
2. **Cola asincronica** (`ResourceQueue` / `RQueue`): usa `ResourceLoader.load_interactive()` en un hilo separado para precargar escenas `.tscn` sin bloquear el hilo principal.
3. **Descompresion** (`gdunzip`): lee archivos ZIP y extrae su contenido como `PoolByteArray`, permitiendo alimentar los cargadores especializados.
4. **Instancias globales**: `Globals.audioLoader` y `Globals.imageLoader` son instancias unicas creadas en `Globals.gd` que todo el proyecto utiliza para cargar audio e imagenes.

### Diagrama de flujo de carga de recursos

```
                        +------------------+
                        |  Solicitud de    |
                        |    recurso       |
                        +--------+---------+
                                 |
              +------------------+------------------+
              |                  |                  |
              v                  v                  v
     +--------+------+  +-------+-------+  +-------+--------+
     |  Escena .tscn |  | Audio/Imagen  |  | Archivo .ZIP   |
     |  (Godot)      |  | (externo)     |  | (packs/mods)   |
     +--------+------+  +-------+-------+  +-------+--------+
              |                  |                  |
              v                  |                  v
     +--------+------+          |          +-------+--------+
     | ResourceQueue |          |          |   gdunzip      |
     | (RQueue)      |          |          | uncompress()   |
     | - Hilo bg     |          |          +-------+--------+
     | - Mutex/Sem   |          |                  |
     +--------+------+          |          PoolByteArray
              |                  |                  |
              v          +------+------+           |
     PackedScene         |             |           |
     (lista para uso)    v             v           v
                  +------+----+ +------+----+ +----+-------+
                  |AudioLoader| |ImageLoader| |AudioLoader |
                  |load_file()| |load_file()| |load_buffer()|
                  +------+----+ |load_if_   | |ImageLoader |
                         |      |  exists() | |load_buffer()|
                         v      +------+----+ +----+-------+
                  AudioStream          |           |
                  (OGG/MP3/WAV)        v           v
                                   Texture    AudioStream
                                (ImageTexture) / Texture
```

```
  Carga de modelos 3D (.OBJ):

     +------------------+
     | Ruta del .OBJ    |
     | (user:// o res://)|
     +--------+---------+
              |
              v
     +--------+---------+
     | ObjParse.load_obj|
     | - Lee archivo    |
     | - Busca .MTL     |
     +--------+---------+
              |
     +--------+---------+
     | _create_obj()    |
     | - Parsea v/vn/vt |
     | - Triangula caras|
     | - SurfaceTool    |
     +--------+---------+
              |
              v
         ArrayMesh
     (listo para MultiMesh)
```

---

## AudioLoader.gd

### Descripcion

`AudioLoader` carga archivos de audio desde el sistema de archivos o desde buffers en memoria (`PoolByteArray`). Detecta automaticamente el formato del archivo mediante firmas binarias (magic bytes), sin depender de la extension del archivo.

### Clase y herencia

```gdscript
extends Node
class_name AudioLoader
```

### Instancia global

Se crea una unica instancia en `Globals.gd`:

```gdscript
var audioLoader:AudioLoader = AudioLoader.new()
```

### Formatos soportados

| Formato | Magic Bytes | Tipo de AudioStream | Notas |
|---------|-------------|---------------------|-------|
| OGG Vorbis | `4F 67 67 53` | `AudioStreamOGGVorbis` | Formato principal usado en mapas SSPM |
| MP3 | `FF FB`, `FF F3`, `FF FA`, `FF F2` o `49 44 33` (ID3) | `AudioStreamMP3` | Soporta todas las variantes de cabecera MP3 |
| WAV | `52 49 46 46` ... `57 41 56 45` | `AudioStreamSample` | Soporta 8, 16, 24 y 32 bits; convierte 24/32 a 16 bits |

### Metodos publicos

#### `get_format(bytes: PoolByteArray) -> String`

Detecta el formato del audio leyendo los primeros bytes del buffer. Retorna `"ogg"`, `"mp3"`, `"wav"` o `"unknown"`.

#### `load_buffer(bytes: PoolByteArray, loop: bool = false) -> AudioStream`

Carga audio desde un buffer en memoria. Este es el metodo principal usado por `Song.stream()` cuando el audio esta embebido dentro de un archivo `.sspm`.

- Detecta el formato con `get_format()`.
- Crea el `AudioStream` correspondiente y asigna los bytes.
- Para WAV de 24/32 bits, convierte a 16 bits internamente.
- Si el formato no se reconoce, retorna `Globals.error_sound`.

#### `load_file(filepath: String, loop: bool = false) -> AudioStream`

Abre un archivo desde disco usando `Globals.p()` para resolver la ruta, lee todos los bytes y los pasa a `load_buffer()`.

#### `convert_to_16bit(data: PoolByteArray, from: int) -> PoolByteArray`

Convierte datos WAV de 24 o 32 bits a 16 bits:
- **24 bits**: toma los 2 bytes mas significativos de cada muestra de 3 bytes.
- **32 bits**: interpreta cada muestra de 4 bytes como float y la escala a int16.

> **Nota de rendimiento**: la conversion es lenta en GDScript. Segun los comentarios del autor, la conversion de 32 bits es aproximadamente 3 veces mas lenta que la de 24 bits.

### Ejemplos de uso

**Desde `Song.stream()` -- carga de audio embebido en SSPM:**

```gdscript
func stream() -> AudioStream:
    if sspm_song_stored || !musicFile.begins_with("res://"):
        var buf = get_music_buffer()
        if buf:
            var s = Globals.audioLoader.load_buffer(buf)
            if s is AudioStreamOGGVorbis or s is AudioStreamMP3:
                s.loop = false
            if s: return s
            else: return Globals.error_sound
```

**Desde `Rhythia.gd` -- carga de audio personalizado:**

```gdscript
var stream = Globals.audioLoader.load_file(path)
```

**Desde `AddSong.gd` -- importacion de canciones:**

```gdscript
var stream = Globals.audioLoader.load_file(files[0])
```

---

## ImageLoader.gd

### Descripcion

`ImageLoader` carga imagenes desde archivos o buffers y las convierte en `ImageTexture` listas para usar en la UI o en materiales 3D. Al igual que `AudioLoader`, detecta el formato por firmas binarias.

### Clase y herencia

```gdscript
extends Node
class_name ImageLoader
```

### Instancia global

```gdscript
var imageLoader:ImageLoader = ImageLoader.new()
```

### Formatos soportados

| Formato | Magic Bytes | Metodo de Image |
|---------|-------------|-----------------|
| PNG | `89 50 4E 47 0D 0A 1A 0A` | `load_png_from_buffer()` |
| JPG/JPEG | `FF D8 FF` | `load_jpg_from_buffer()` |
| BMP | `42 4D` | `load_bmp_from_buffer()` |
| WebP | `52 49 46 46` ... `57 45 42 50` | `load_webp_from_buffer()` |

### Texturas de error

```gdscript
var error_texture:Texture = load("res://assets/images/error.jpg")     # Error de lectura
var invalid_texture:Texture = load("res://assets/images/error2.jpg")  # Formato no reconocido
```

### Metodos publicos

#### `get_format(bytes: PoolByteArray) -> String`

Detecta el formato de la imagen por magic bytes. Retorna `"png"`, `"jpg"`, `"bmp"`, `"webp"` o `"unknown"`.

#### `load_buffer(bytes: PoolByteArray) -> Texture`

Carga una imagen desde un buffer en memoria:
1. Detecta el formato con `get_format()`.
2. Crea un `Image` y lo carga con el metodo correspondiente.
3. Genera un `ImageTexture` a partir del `Image`.
4. Si el formato no se reconoce, retorna `invalid_texture`.

#### `load_file(filepath: String) -> Texture`

Abre un archivo de imagen desde disco y lo pasa a `load_buffer()`. Si el archivo no se puede abrir, retorna `error_texture`.

#### `load_if_exists(path: String) -> Texture | null`

Busca un archivo de imagen probando multiples extensiones en orden:
1. `.png`
2. `.jpg`
3. `.jpeg`
4. `.webp`
5. `.bmp`

Si encuentra alguno, lo carga con `load_file()`. Si no existe ninguno, retorna `null`. Este metodo implementa **lazy loading**: no necesita conocer la extension exacta del archivo.

### Ejemplos de uso

**Carga de portada embebida en SSPM (`Song._get_cover()`):**

```gdscript
var cbuf:PoolByteArray = file.get_buffer(cover_length)
cover = Globals.imageLoader.load_buffer(cbuf) as ImageTexture
```

**Carga de portada desde carpeta de mapa Vulnus:**

```gdscript
var c = Globals.imageLoader.load_if_exists(folder_path + "/cover.png")
if c:
    cover = c
    has_cover = true
```

**Carga de textura personalizada de cursor:**

```gdscript
var img = Globals.imageLoader.load_if_exists("user://cursor")
```

**Carga de textura personalizada de notas (`NoteManager.gd`):**

```gdscript
var img = Globals.imageLoader.load_if_exists("user://note")
if img:
    note_solid_mat.set_shader_param("image", img)
    note_solid_mat.set_shader_param("use_image", true)
```

**Carga de imagen desde el registro de contenido (`Registry.gd`):**

```gdscript
return Globals.imageLoader.load_file(file)
```

---

## ObjParse.gd

### Descripcion

`ObjParse` es un parser estatico de archivos Wavefront OBJ que genera `ArrayMesh` de Godot. Soporta materiales MTL con texturas y colores difusos. Se usa principalmente para cargar modelos 3D personalizados de notas.

### Clase

```gdscript
class_name ObjParse
```

Todos los metodos son `static`, por lo que no necesita instanciacion.

### Formatos soportados

| Elemento OBJ | Sintaxis | Descripcion |
|---------------|----------|-------------|
| Vertices | `v x y z` | Posiciones 3D |
| Normales | `vn x y z` | Normales de vertice |
| UVs | `vt u v` | Coordenadas de textura (v se invierte: `1 - v`) |
| Caras triangulares | `f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3` | Triangulos directos |
| Caras poligonales | `f v1/vt1/vn1 ... vN/vtN/vnN` | Se triangulan automaticamente (fan) |
| Grupos de material | `usemtl nombre` | Asigna material a las caras siguientes |

| Elemento MTL | Sintaxis | Descripcion |
|--------------|----------|-------------|
| Nuevo material | `newmtl nombre` | Define un `SpatialMaterial` |
| Color difuso | `Kd r g b` | Asigna `albedo_color` |
| Textura difusa | `map_Kd archivo` | Carga imagen como `albedo_texture` |
| Textura especular | `map_Ks archivo` | Carga imagen de textura |
| Textura ambiente | `map_Ka archivo` | Carga imagen de textura |

### Metodos publicos

#### `load_obj(obj_path: String, mtl_path: String = "") -> Mesh`

Metodo principal. Carga un archivo `.obj` y opcionalmente su `.mtl` asociado:
1. Si no se proporciona `mtl_path`, busca automaticamente un archivo `.mtl` con el mismo nombre base.
2. Lee ambos archivos como texto.
3. Carga las texturas referenciadas en el MTL.
4. Construye el `ArrayMesh` con `SurfaceTool`.

#### `load_obj_from_buffer(obj_data: String, materials: Dictionary) -> Mesh`

Carga desde datos ya en memoria. Util cuando el OBJ se extrae de un archivo ZIP.

#### `load_mtl_from_buffer(mtl_data: String, textures: Dictionary) -> Dictionary`

Crea los materiales desde datos MTL en memoria, con texturas proporcionadas como diccionario `{nombre_textura: PoolByteArray}`.

#### `get_data(path: String) -> String`

Lee un archivo completo como texto.

#### `search_mtl_path(obj_path: String) -> String`

Busca automaticamente el archivo MTL correspondiente a un OBJ, probando:
1. `nombre_base.mtl` (reemplazando la extension)
2. `nombre_completo.obj.mtl` (agregando extension)

### Flujo interno de `_create_obj()`

1. **Parseo linea por linea**: separa vertices (`v`), normales (`vn`), UVs (`vt`) y caras (`f`).
2. **Triangulacion**: las caras con mas de 3 vertices se descomponen en triangulos usando fan triangulation desde el primer vertice.
3. **Agrupacion por material**: cada grupo `usemtl` genera una superficie separada.
4. **Ensamblaje**: usa `SurfaceTool` para crear cada superficie con vertices, normales y UVs, y la agrega al `ArrayMesh` con `st.commit(mesh)`.

### Ejemplo de uso

**Desde `NoteManager.gd` -- carga de mesh personalizado de notas:**

```gdscript
var mesh:Mesh
if "user://" in Rhythia.selected_mesh.path:
    var m = ObjParse.load_obj(Rhythia.selected_mesh.path)
    if m != null:
        mesh = m
    else:
        mesh = load("res://assets/blocks/rounded.obj")
else:
    mesh = load(Rhythia.selected_mesh.path)
```

Si el modelo personalizado del usuario no se puede cargar, se usa el mesh por defecto (`rounded.obj`).

---

## ResourceQueue.gd

### Descripcion

`ResourceQueue` es una cola asincronica que carga recursos de Godot (escenas `.tscn`, scripts, etc.) en un hilo separado usando `ResourceLoader.load_interactive()`. Esta registrado como **Autoload** con el nombre `RQueue` en `project.godot`.

### Configuracion como Autoload

En `project.godot`:

```ini
RQueue="*res://scripts/content/resources/ResourceQueue.gd"
```

El asterisco `*` indica que es un autoload singleton.

### Arquitectura de hilos

```
  Hilo Principal                    Hilo de Carga
  +--------------+                  +---------------+
  | queue_resource() ----Mutex---> | thread_func()  |
  |              | ---Semaphore--> | thread_process()|
  | _process():  |                  |   res.poll()   |
  |  is_ready()  | <---Mutex---    |                |
  |  get_resource() <--Mutex---    |                |
  +--------------+                  +---------------+
```

- **Mutex**: protege el acceso concurrente a `queue` y `pending`.
- **Semaphore**: despierta al hilo de carga cuando se agrega un recurso a la cola.
- **`time_max`**: limite de tiempo en milisegundos (100ms) para polling, aunque actualmente se usa `res.poll()` sin limite explicito por iteracion.

### Variables internas

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `thread` | `Thread` | Hilo de carga en segundo plano |
| `mutex` | `Mutex` | Proteccion de acceso concurrente |
| `semaphore` | `Semaphore` | Sincronizacion entre hilos |
| `queue` | `Array` | Cola de `ResourceInteractiveLoader` pendientes |
| `pending` | `Dictionary` | Mapa de ruta a recurso (loader o recurso final) |
| `exit_thread` | `bool` | Senal de terminacion para el hilo |

### Metodos publicos

#### `queue_resource(path: String, p_in_front: bool = false) -> int`

Agrega un recurso a la cola de carga:
1. Si ya esta en `pending`, retorna `OK` (evita duplicados).
2. Si esta en cache de `ResourceLoader`, lo carga directamente.
3. Si no, crea un `ResourceInteractiveLoader` y lo agrega a la cola.
4. `p_in_front = true` lo pone al inicio de la cola (prioridad).

#### `cancel_resource(path: String)`

Cancela la carga de un recurso, eliminandolo de `queue` y `pending`.

#### `get_progress(path: String) -> float`

Retorna el progreso de carga (0.0 a 1.0). Retorna -1 si la ruta no esta en la cola.

#### `is_ready(path: String) -> bool`

Verifica si un recurso ya termino de cargarse. Retorna `true` cuando `pending[path]` ya no es un `ResourceInteractiveLoader` (es decir, ya se resolvio al recurso final).

#### `get_resource(path: String) -> Resource`

Obtiene el recurso cargado. Si aun no esta listo, espera de forma no bloqueante usando `VisualServer.sync()` y `OS.delay_usec(16000)` (aproximadamente 1 frame de 60 FPS).

#### `start()`

Inicializa el mutex, semaforo e hilo de carga. Se llama automaticamente en `_ready()`.

### Flujo de precarga de escenas

El patron tipico de uso es:

```gdscript
# 1. Encolar el recurso
var res = RQueue.queue_resource(target)

# 2. En _process(), verificar si esta listo
func _process(delta):
    if RQueue.is_ready(target):
        result = RQueue.get_resource(target)
        # 3. Cambiar de escena
        get_tree().change_scene_to(result)
```

### Ejemplos de uso

**Desde `init.gd` -- precarga del menu principal al iniciar el juego:**

```gdscript
func stage(text:String, done:bool = false):
    $Label2.text = text
    if done:
        $Label2.text = "Loading menu"
        var res = RQueue.queue_resource(target)
        if res != OK:
            Rhythia.errorstr = "queue_resource returned %s" % res
            get_tree().change_scene("res://scenes/errors/menuload.tscn")
```

**Desde `menuload.gd` -- precarga al volver al menu desde el juego:**

```gdscript
var res = RQueue.queue_resource(target)
# ...
func _process(delta):
    if !leaving:
        if RQueue.is_ready(target):
            result = RQueue.get_resource(target)
            leaving = true
```

**Desde `songload.gd` -- precarga de la escena de juego y el mundo:**

```gdscript
var res = RQueue.queue_resource(target)
var res2 = RQueue.queue_resource(target2)
# ...
if RQueue.is_ready(target) and RQueue.is_ready(target2):
    result = RQueue.get_resource(target)
    result2 = RQueue.get_resource(target2)
```

---

## gdunzip.gd

### Descripcion

`gdunzip` es un descompresor de archivos ZIP implementado completamente en GDScript. Utiliza una implementacion interna de DEFLATE (clase `Tinf`, port de la biblioteca "tiny inflate" de Jorgen Ibsen) para descomprimir archivos.

### Uso

Es un script instanciable (no tiene `class_name`):

```gdscript
var gdunzip = load("res://scripts/content/resources/gdunzip.gd").new()
```

### Estructura interna

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `path` | `String` | Ruta del ZIP cargado |
| `buffer` | `PoolByteArray` | Contenido completo del ZIP en memoria |
| `buffer_size` | `int` | Tamano del buffer |
| `files` | `Dictionary` | Metadatos de cada archivo en el ZIP |
| `pos` | `int` | Posicion actual de lectura en el buffer |
| `tinf` | `Tinf` | Instancia del descompresor DEFLATE |

### Estructura de metadatos por archivo

Cada entrada en `files` es un diccionario con:

```gdscript
{
    "compression_method": int,     # -1 = sin comprimir, File.COMPRESSION_DEFLATE
    "file_name": String,           # Ruta completa dentro del ZIP
    "file_header_offset": int,     # Offset del header en el buffer
    "compressed_size": int,        # Tamano comprimido en bytes
    "uncompressed_size": int       # Tamano original en bytes
}
```

### Metodos publicos

#### `load(path: String) -> bool`

Carga un archivo ZIP en memoria:
1. Verifica que el archivo existe.
2. Lee todo el contenido en `buffer`.
3. Valida la firma ZIP (`50 4B 03 04`).
4. Parsea el directorio central para llenar `files`.

#### `uncompress(file_name: String) -> PoolByteArray | false`

Descomprime un archivo especifico del ZIP:
- Si no esta comprimido (`compression_method == -1`), retorna los bytes directamente.
- Si usa DEFLATE, pasa los datos por `tinf.tinf_uncompress()`.
- Retorna `false` si el archivo no existe en el ZIP.

#### `get_compressed(file_name: String) -> PoolByteArray | false`

Retorna los bytes comprimidos sin descomprimir. Util para transferir datos sin procesarlos.

### Clase interna: Tinf

`Tinf` es un port a GDScript de la biblioteca "tiny inflate" que implementa la descompresion DEFLATE. Soporta:

- Bloques sin comprimir
- Bloques con arboles Huffman fijos
- Bloques con arboles Huffman dinamicos

### Ejemplo de uso

```gdscript
var gdunzip = load("res://scripts/content/resources/gdunzip.gd").new()
var loaded = gdunzip.load("user://packs/mi_pack.zip")
if loaded:
    for f in gdunzip.files:
        print(gdunzip.files[f]["file_name"])
    var datos = gdunzip.uncompress("contenido/mapa.txt")
    if datos:
        var texto = datos.get_string_from_utf8()
```

---

## Relacion entre sistemas

### Flujo completo: cargar una cancion y jugar

```
1. Usuario selecciona cancion en el menu
         |
         v
2. songload.gd encola escena de juego y mundo con RQueue
   RQueue.queue_resource("res://scenes/game.tscn")
   RQueue.queue_resource(world_path)
         |
         v
3. Mientras se carga la escena en background (hilo de RQueue)...
         |
         v
4. Al estar listas, se cambia de escena:
   get_tree().change_scene_to(result)
         |
         v
5. NoteManager.gd carga mesh personalizado:
   ObjParse.load_obj(Rhythia.selected_mesh.path) -> ArrayMesh
         |
6. NoteManager.gd carga textura personalizada:
   Globals.imageLoader.load_if_exists("user://note") -> Texture
         |
         v
7. Game.gd solicita audio de la cancion:
   Song.stream() -> Globals.audioLoader.load_buffer(buf) -> AudioStream
         |
         v
8. El juego comienza con todos los recursos cargados
```

### Resumen de formatos soportados por cargador

| Cargador | Formatos | Entrada | Salida |
|----------|----------|---------|--------|
| AudioLoader | OGG, MP3, WAV (8/16/24/32 bit) | `PoolByteArray` o ruta de archivo | `AudioStreamOGGVorbis`, `AudioStreamMP3`, `AudioStreamSample` |
| ImageLoader | PNG, JPG, BMP, WebP | `PoolByteArray` o ruta de archivo | `ImageTexture` |
| ObjParse | OBJ + MTL (con texturas) | Ruta de archivo o texto en memoria | `ArrayMesh` con `SpatialMaterial` |
| ResourceQueue | Cualquier recurso de Godot (.tscn, .tres, etc.) | Ruta `res://` | `Resource` (tipicamente `PackedScene`) |
| gdunzip | ZIP (DEFLATE y sin comprimir) | Ruta de archivo | `PoolByteArray` por cada archivo interno |
