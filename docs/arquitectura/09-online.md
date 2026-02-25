# 09 - Sistema Online

> Documentacion de arquitectura para **Sound Space Plus (Rhythia)** - Motor: Godot 3.x

---

## Indice

1. [Vision general](#vision-general)
2. [Online.gd (Autoload)](#onlinegd-autoload)
   - [Senales](#senales)
   - [Gestion HTTP](#gestion-http)
   - [Configuracion](#configuracion)
   - [Metodos clave](#metodos-clave)
3. [Flujo de descarga completo](#flujo-de-descarga-completo)
4. [MapDB API Format](#mapdb-api-format)
5. [Sistema de cache](#sistema-de-cache)
6. [Manejo de errores HTTP](#manejo-de-errores-http)
7. [Configuracion de red en project.godot](#configuracion-de-red-en-projectgodot)
8. [Verificacion de versiones y actualizacion](#verificacion-de-versiones-y-actualizacion)
9. [Utilidades internas](#utilidades-internas)
10. [Diagrama de secuencia de comunicacion con API](#diagrama-de-secuencia-de-comunicacion-con-api)

---

## Vision general

El sistema online de Sound Space Plus permite a los jugadores descargar mapas desde una base de datos remota (MapDB) alojada en `cdn.rhythia.net`. El nodo **Autoload** `Online` (`scripts/Online.gd`) encapsula toda la logica de red: pruebas de conectividad, obtencion del catalogo de mapas, descarga individual de archivos `.sspm`, cache condicional mediante `If-Modified-Since`, verificacion de versiones del juego y actualizacion automatica.

El flujo general es:

1. Al cargar el menu, `load_db_maps()` descarga el indice de mapas online y los registra en `map_registry`.
2. Cuando el jugador selecciona un mapa online, `Rhythia.select_song()` delega a `Online.download_map()`, que descarga el archivo, lo guarda localmente y lo convierte al formato SSPM2 si es necesario.
3. La UI (`DownloadScreen.gd`) muestra el progreso y permite cancelar la descarga.

---

## Online.gd (Autoload)

- **Extiende**: `Node`
- **Archivo**: `scripts/Online.gd`
- **Proposito**: Integracion con MapDB API, descarga de mapas, prueba de conectividad, verificacion de versiones y auto-actualizacion.
- **pause_mode**: `PAUSE_MODE_PROCESS` (se ejecuta incluso con el arbol pausado)

### Senales

| Senal | Parametros | Descripcion |
|-------|-----------|-------------|
| `db_maps_done` | ninguno | Emitida al terminar la carga del catalogo de mapas (exito o fallo) |
| `map_downloaded` | `{id:String, success:bool, error?:String}` | Emitida al completar o fallar una descarga individual |
| `_httpreq_finished` | ninguno | Senal interna generica de finalizacion HTTP |
| `_mapdl_req` | `{result, response_code, headers, body}` | Senal interna: respuesta de descarga de mapa |
| `_netmaps_req` | `{result, response_code, headers, body}` | Senal interna: respuesta de catalogo de mapas |
| `_connection_test` | `bool` | Senal interna: resultado de prueba de conectividad |
| `error_done` | ninguno | Emitida al cerrar un dialogo de error de la base de datos |
| `latest_version` | `String` | Emitida con el tag de la ultima version disponible |
| `update_finished` | ninguno | Emitida al terminar el proceso de actualizacion |
| `_update_req` | `[result, response_code]` | Senal interna: respuesta de descarga de actualizacion |

### Gestion HTTP

El sistema utiliza multiples instancias de `HTTPRequest`, cada una configurada para un proposito especifico:

| Variable | Tipo | use_threads | timeout | Proposito |
|----------|------|-------------|---------|-----------|
| `mapdl_hr` | `HTTPRequest` | `false` | `0` (sin limite) | Descarga de archivos de mapa individuales |
| `netmaps_hr` | `HTTPRequest` | `true` | `80s` | Obtencion del indice/catalogo de mapas |
| `ctest_hr` | `HTTPRequest` | `true` | `5s` | Prueba de conectividad (ping) |
| `version_hr` | `HTTPRequest` | `true` | `5s` | Consulta de ultima version en GitHub |
| `update_hr` | `HTTPRequest` | `true` | `0` (sin limite) | Descarga de paquete de actualizacion |

**Nota sobre `mapdl_hr`**: Usa `use_threads = false` para poder leer `get_downloaded_bytes()` desde `_process()` y reportar progreso de descarga en tiempo real.

#### Variables de progreso de descarga

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `mapdl_bs` | `float` | Tamano total del cuerpo de la respuesta (body size) |
| `mapdl_bd` | `float` | Bytes descargados hasta el momento |

Estas variables se actualizan en cada `_process()`:

```gdscript
func _process(_d):
    mapdl_bs = mapdl_hr.get_body_size()
    mapdl_bd = mapdl_hr.get_downloaded_bytes()
```

### Configuracion

| Variable | Tipo | Valor por defecto | Descripcion |
|----------|------|-------------------|-------------|
| `mapdb_api` | `String` | `""` (se carga desde `project.godot`) | URL base del indice de MapDB |
| `map_registry` | `Registry` | asignado externamente | Registro donde se agregan los mapas online importados |

En `_ready()`, `mapdb_api` se inicializa desde:

```gdscript
mapdb_api = ProjectSettings.get_setting("application/networking/mapdb_api")
```

### Metodos clave

#### `test_connection()`

Realiza una solicitud HTTP al `test_url` configurado en `project.godot` para verificar que hay conectividad a internet. Emite `_connection_test` con `true` o `false`.

```gdscript
func test_connection():
    var res = ctest_hr.request(ProjectSettings.get_setting("application/networking/test_url"))
    if res != OK: emit_signal("_connection_test", false)
```

#### `load_db_maps()`

Obtiene la lista completa de mapas del API. Implementa cache condicional con `If-Modified-Since`:

1. Verifica que el networking este habilitado.
2. Valida que `mapdb_api` sea una URL valida.
3. Ejecuta `test_connection()` y aborta si falla.
4. Envia request con header `If-Modified-Since` basado en la ultima fecha guardada.
5. Si respuesta es `200`: guarda cache en `user://.mapdb_cache.json` y actualiza `user://.mapdb_updated.txt`.
6. Si respuesta es `304`: lee desde cache local.
7. Registra cada mapa nuevo en `map_registry` via `Song.load_from_db_data()`.
8. Emite `db_maps_done` al finalizar.

#### `download_map(map:Song) -> String`

Punto de entrada para descargar un mapa individual. Genera un UUID v4 como identificador de la descarga y delega a `_mapdl_handler()` de forma diferida.

```gdscript
func download_map(map:Song):
    var id = v4()
    call_deferred("_mapdl_handler", id, map)
    return id
```

**Retorna**: `String` (UUID v4 que identifica esta descarga).

#### `_mapdl_handler(id:String, map:Song)`

Logica interna de descarga. Flujo completo:

1. Valida que el networking este habilitado.
2. Valida que `mapdb_api` sea una URL valida.
3. Ejecuta prueba de conectividad.
4. Elimina archivo temporal previo (`user://mapdl.sspm.part`) si existe.
5. Configura `download_file` en el `HTTPRequest` y ejecuta la solicitud a `map.download_url`.
6. Espera respuesta via `yield(self, "_mapdl_req")`.
7. Si exitoso (HTTP 200):
   - Renombra el archivo de `user://mapdl.sspm.part` a `user://maps/{id}.sspm`.
   - Carga el mapa con `map.load_from_sspm()`.
   - Si no es formato SSPM2 y no se mantiene presionado `skip_convert` (Ctrl+M), convierte automaticamente.
   - Recarga el mapa convertido.
   - Emite `map_downloaded` con `success=true`.
8. Si falla: emite `map_downloaded` con `success=false` y el codigo de error.

#### `mapdl_error(id:String, error:String, map:Song)`

Funcion de utilidad para manejar errores de descarga. Imprime log y emite `map_downloaded` con `success=false`.

```gdscript
func mapdl_error(id:String, error:String, map:Song):
    print("[MapDB Download] Map %s errored with code %s" % [map.id, error])
    emit_signal("map_downloaded", {id=id, success=false, error=error})
```

#### `cancel()`

Cancela la descarga activa y emite la senal `_mapdl_req` con `result=-1` para que `_mapdl_handler` lo interprete como cancelacion.

```gdscript
func cancel():
    mapdl_hr.cancel_request()
    emit_signal("_mapdl_req", {result=-1})
```

#### `show_db_error(body:String, title:String)`

Muestra un dialogo de error modal usando `Globals.confirm_prompt`. Reproduce sonido de alerta, espera a que el usuario confirme con "OK", cierra el dialogo y emite `error_done`.

#### `check_latest_version()`

Consulta la API de GitHub (`/repos/{repo}/releases/latest`) para obtener la version mas reciente. Solo funciona en Windows y Linux. Si el networking esta deshabilitado, emite la version actual del proyecto.

#### `attempt_update()`

Descarga el paquete de actualizacion (`.zip`) del ultimo release de GitHub, extrae el `.pck` y reemplaza el archivo local. Respalda el `.pck` anterior con extension `.old`.

---

## Flujo de descarga completo

El flujo desde la seleccion del usuario hasta la carga final del mapa involucra tres componentes: `Rhythia`, `Online` y `DownloadScreen`.

```
Jugador selecciona mapa online
         |
         v
Rhythia.select_song(song)
         |
         ├── song.is_online == true
         |
         v
Rhythia emite "download_start"
         |
         ├── DownloadScreen: se hace visible, toma foco en boton Cancel
         |
         v
get_tree().paused = true
         |
         v
Online.download_map(map) → genera UUID v4 → retorna id
         |
         v
call_deferred("_mapdl_handler", id, map)
         |
         v
┌─────────────────────────────────────────────┐
│           _mapdl_handler(id, map)           │
├─────────────────────────────────────────────┤
│ 1. Validar networking habilitado            │
│ 2. Validar mapdb_api URL                    │
│ 3. test_connection()                        │
│    └── yield(self, "_connection_test")      │
│ 4. Eliminar user://mapdl.sspm.part previo   │
│ 5. mapdl_hr.download_file = ...part         │
│ 6. mapdl_hr.request(map.download_url)       │
│    └── yield(self, "_mapdl_req")            │
│ 7. Si HTTP 200:                             │
│    ├── Renombrar a user://maps/{id}.sspm    │
│    ├── map.load_from_sspm(...)              │
│    ├── Convertir a SSPM2 si necesario       │
│    ├── map.load_from_sspm(...) otra vez     │
│    └── emit "map_downloaded" (success)      │
│ 8. Si error:                                │
│    └── emit "map_downloaded" (error)        │
└─────────────────────────────────────────────┘
         |
         v
Rhythia recibe "map_downloaded"
         |
         ├── Filtra por id (ignora descargas con id diferente)
         |
         v
get_tree().paused = false
         |
         ├── Si success:
         │     ├── emit "download_done"
         │     ├── selected_song = song
         │     └── emit "selected_song_changed"
         │
         ├── Si error == "010-100":
         │     └── emit "download_done" (silencioso)
         │
         └── Si otro error:
               ├── Mostrar dialogo de error
               ├── Esperar confirmacion del usuario
               └── emit "download_done"
         |
         v
DownloadScreen: se oculta
```

**Progreso en tiempo real**: Mientras la descarga esta activa, `DownloadScreen._process()` lee `Online.mapdl_hr.get_downloaded_bytes()` y `Online.mapdl_bs` para calcular y mostrar el porcentaje.

**Cancelacion**: El boton "Cancel" de `DownloadScreen` esta conectado directamente a `Online.cancel()`, que cancela el request HTTP y emite `_mapdl_req` con `result=-1`.

---

## MapDB API Format

### Endpoint del indice

```
GET https://cdn.rhythia.net/index.json
```

### Estructura de respuesta

El indice es un diccionario JSON donde cada clave es el ID del mapa:

```json
{
  "id_del_mapa": {
    "id": "string",
    "name": "string",
    "song": "string",
    "author": ["string"],
    "difficulty": int,
    "difficulty_name": "string",
    "download": "url",
    "audio": "url",
    "cover": null | "url",
    "stars": int,
    "broken": bool,
    "tags": ["string"],
    "content_warnings": [],
    "version": int,
    "length_ms": int,
    "note_count": int,
    "has_cover": bool,
    "note_data_offset": int,
    "note_data_length": int,
    "music_format": "string",
    "music_offset": int,
    "music_length": int
  },
  ...
}
```

### Descripcion de campos

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `id` | `string` | Identificador unico del mapa |
| `name` | `string` | Nombre del mapa (nombre de la dificultad/creacion) |
| `song` | `string` | Nombre de la cancion |
| `author` | `string[]` | Lista de autores/creadores del mapa |
| `difficulty` | `int` | Nivel de dificultad numerico |
| `difficulty_name` | `string` | Nombre descriptivo de la dificultad |
| `download` | `string` | URL de descarga del archivo SSPM |
| `audio` | `string` | URL del archivo de audio |
| `cover` | `null\|string` | URL de la imagen de portada (puede ser null) |
| `stars` | `int` | Clasificacion por estrellas |
| `broken` | `bool` | Indica si el mapa esta marcado como roto/defectuoso |
| `tags` | `string[]` | Etiquetas del mapa (e.g. `"ss_archive"`) |
| `content_warnings` | `string[]` | Advertencias de contenido |
| `version` | `int` | Version del formato del mapa |
| `length_ms` | `int` | Duracion de la cancion en milisegundos |
| `note_count` | `int` | Numero total de notas |
| `has_cover` | `bool` | Indica si el mapa tiene imagen de portada |
| `note_data_offset` | `int` | Offset de los datos de notas dentro del archivo SSPM |
| `note_data_length` | `int` | Longitud de los datos de notas en bytes |
| `music_format` | `string` | Formato del audio (e.g. `"mp3"`) |
| `music_offset` | `int` | Offset del audio dentro del archivo SSPM |
| `music_length` | `int` | Longitud del audio en bytes |

### Headers de cache condicional

La solicitud incluye el header `If-Modified-Since` para evitar descargas innecesarias:

```
If-Modified-Since: Mon, 13 Jan 1970 00:22:53 GMT
```

- Si el servidor responde `200`: los datos han cambiado, se actualiza la cache.
- Si el servidor responde `304 Not Modified`: se usan los datos en cache local.

---

## Sistema de cache

El sistema implementa cache condicional para el indice de mapas usando dos archivos locales:

| Archivo | Proposito |
|---------|-----------|
| `user://.mapdb_cache.json` | Copia local del indice JSON completo |
| `user://.mapdb_updated.txt` | Marca de tiempo ISO de la ultima actualizacion exitosa |

### Flujo de cache

```
load_db_maps()
     |
     v
¿Existen .mapdb_cache.json Y .mapdb_updated.txt?
     |                              |
     Si                             No
     |                              |
     v                              v
Leer fecha de .mapdb_updated.txt    Usar fecha epoch (1373 seg)
     |                              |
     └──────────┬───────────────────┘
                |
                v
    Enviar request con If-Modified-Since
                |
        ┌───────┴───────┐
        |               |
    HTTP 200        HTTP 304
        |               |
        v               v
  Guardar body      Leer desde
  en cache local    .mapdb_cache.json
        |               |
  Guardar fecha         |
  en .mapdb_updated     |
        |               |
        └───────┬───────┘
                |
                v
    Parsear JSON y registrar mapas
    nuevos en map_registry
```

**Nota**: Si la cache local tiene JSON malformado en un escenario `304`, ambos archivos de cache se eliminan, forzando una descarga completa en la proxima ejecucion.

---

## Manejo de errores HTTP

### Tabla de codigos de error de descarga de mapas

Los errores se reportan via la senal `map_downloaded` con `success=false` y un string `error`.

| Codigo/Mensaje | Constante de Godot | Descripcion |
|----------------|---------------------|-------------|
| `"Networking is disabled"` | N/A | El networking esta deshabilitado en `project.godot` |
| `"MapDB API Invalid"` | N/A | La URL de `mapdb_api` esta vacia o no es valida |
| `"Failed to connect"` | N/A | La prueba de conectividad (`test_connection()`) fallo |
| `"Invalid Parameter"` | `ERR_INVALID_PARAMETER` | Parametro invalido en la solicitud HTTP |
| `"Can't Connect"` | `ERR_CANT_CONNECT` / `RESULT_CANT_CONNECT` | No se puede conectar al servidor |
| `"Can't Resolve"` | `RESULT_CANT_RESOLVE` | No se puede resolver el nombre de dominio (DNS) |
| `"Connection Error"` | `RESULT_CONNECTION_ERROR` | Error generico de conexion |
| `"SSL Handshake Error"` | `RESULT_SSL_HANDSHAKE_ERROR` | Fallo en el handshake SSL/TLS |
| `"Timeout"` | `RESULT_TIMEOUT` | La solicitud excedio el tiempo limite |
| `"Redirect Limit Reached"` | `RESULT_REDIRECT_LIMIT_REACHED` | Se alcanzo el limite de redirecciones |
| `"Download File Open Error"` | `RESULT_DOWNLOAD_FILE_CANT_OPEN` | No se puede abrir el archivo de destino |
| `"Download File Write Error"` | `RESULT_DOWNLOAD_FILE_WRITE_ERROR` | Error al escribir el archivo de destino |
| `"Unknown Error (%s)"` | Otros codigos `ERR_*` | Error desconocido durante `request()` |
| `"Unknown Error"` | Otros codigos `RESULT_*` | Error desconocido en la respuesta |
| `"Cancelled"` | `result == -1` | Descarga cancelada por el usuario |
| `"HTTP-%s"` | N/A | Codigo HTTP no-200 sin cuerpo JSON parseable |
| Texto del campo `resp.error` | N/A | Mensaje de error del servidor (si la respuesta es JSON) |

### Tabla de codigos de error del catalogo de mapas

Errores mostrados via `show_db_error()` durante `load_db_maps()`:

| Condicion | Mensaje de error | Titulo |
|-----------|------------------|--------|
| `mapdb_api` vacia o localhost en release | "Map database is improperly configured." | "Map Database Error" |
| `mapdb_api` URL invalida | "Map database download failed.\nMapDB URL Invalid" | "Map Database Error" |
| Fallo de conexion | Notificacion: "Online maps will not be loaded..." | "No Connection" |
| `RESULT_CANT_RESOLVE` | "Map database download failed.\nError: Can't Resolve" | "Map Database Error" |
| `RESULT_CANT_CONNECT` | "Map database download failed.\nError: Can't Connect" | "Map Database Error" |
| `RESULT_CONNECTION_ERROR` | "Map database download failed.\nError: Connection Error" | "Map Database Error" |
| `RESULT_SSL_HANDSHAKE_ERROR` | "Map database download failed.\nError: SSL Handshake Error" | "Map Database Error" |
| `RESULT_TIMEOUT` | "Map database download failed.\nError: Timeout" | "Map Database Error" |
| `RESULT_REDIRECT_LIMIT_REACHED` | "Map database download failed.\nError: Redirect Limit Reached" | "Map Database Error" |
| JSON malformado (HTTP 200) | "Map database download failed.\nError: Malformed JSON" | "Map Database Error" |
| Otro codigo HTTP | "Map database download failed.\nError code: HTTP-%s" | "Map Database Error" |
| Error desconocido | "Map database download failed.\nError code: HTTP-%s" | "Map Database Error" |

### Codigo especial "010-100"

En `Rhythia.select_song()`, si el error retornado es `"010-100"`, se emite `download_done` silenciosamente sin mostrar ningun dialogo de error al usuario. Este codigo actua como un fallo controlado o esperado.

---

## Configuracion de red en project.godot

Las siguientes configuraciones del proyecto controlan el comportamiento del sistema online:

| Configuracion | Valor por defecto | Descripcion |
|---------------|-------------------|-------------|
| `application/networking/enabled` | `true` | Habilita o deshabilita todo el sistema de red |
| `application/networking/mapdb_api` | `"https://cdn.rhythia.net/index.json"` | URL del indice de la base de datos de mapas |
| `application/networking/test_url` | `"https://google.com"` | URL utilizada para verificar conectividad a internet |
| `application/networking/github_repo` | `"David20122/sound-space-plus"` | Repositorio de GitHub para verificacion de versiones |

**Nota sobre localhost**: En `load_db_maps()`, si `mapdb_api` comienza con `"http://localhost"` y el juego **no** esta en modo debug, se trata como configuracion invalida. Esto permite a los desarrolladores usar un servidor local durante el desarrollo.

---

## Verificacion de versiones y actualizacion

### check_latest_version()

- Solo funciona en Windows (`OS.has_feature("Windows")`) y Linux (`OS.has_feature("X11")`).
- Consulta `https://api.github.com/repos/{github_repo}/releases/latest`.
- Emite `latest_version` con el `tag_name` del release.
- Si el networking esta deshabilitado o la plataforma no es soportada, emite la version actual del proyecto.

### attempt_update()

Flujo de actualizacion automatica:

1. Busca el asset correcto del release (`windows.zip` o `linux.zip`).
2. Descarga el archivo ZIP al directorio del ejecutable.
3. Carga el ZIP como resource pack con `ProjectSettings.load_resource_pack()`.
4. Extrae `SoundSpacePlus.pck` del resource pack.
5. Respalda el `.pck` actual como `.pck.old`.
6. Escribe el nuevo `.pck`.
7. Emite `update_finished`.

---

## Utilidades internas

### Generacion de UUID v4

`Online` incluye una implementacion estatica de UUID v4 para identificar descargas individuales:

```gdscript
static func v4() -> String:
    var b = uuidbin()
    return '%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x' % [
        b[0], b[1], b[2], b[3],  # low
        b[4], b[5],              # mid
        b[6], b[7],              # hi (version 4)
        b[8], b[9],              # clock (variant)
        b[10], b[11], b[12], b[13], b[14], b[15]
    ]
```

- `uuidbin()`: Genera 16 bytes aleatorios con los bits de version (byte 6) y variante (byte 8) ajustados segun RFC 4122.
- `getRandomInt()`: Retorna un entero aleatorio entre 0-255. Llama `randomize()` cada vez para minimizar colisiones.

### Constantes de formato de fecha

Para el header `If-Modified-Since`, se usan arreglos de nombres de dias y meses en ingles:

```gdscript
const weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
```

---

## Diagrama de secuencia de comunicacion con API

### Carga del catalogo de mapas

```
  Rhythia/init       Online           cdn.rhythia.net       google.com         Disco local
      |                 |                    |                    |                  |
      |  load_db_maps() |                    |                    |                  |
      |---------------->|                    |                    |                  |
      |                 |                    |                    |                  |
      |                 |--- test_connection() ------------------>|                  |
      |                 |                    |        GET /       |                  |
      |                 |<--- _connection_test(true) -------------|                  |
      |                 |                    |                    |                  |
      |                 |--- Leer .mapdb_updated.txt -------------------------------->|
      |                 |<--- fecha de ultima actualizacion -------------------------|
      |                 |                    |                    |                  |
      |                 | GET /index.json    |                    |                  |
      |                 | If-Modified-Since  |                    |                  |
      |                 |------------------->|                    |                  |
      |                 |                    |                    |                  |
      |        ┌────────┤  200 + JSON body   |                    |                  |
      |        │        |<-------------------|                    |                  |
      |        │        |                    |                    |                  |
      |        │        |--- Guardar .mapdb_cache.json --------------------------->|
      |        │        |--- Guardar .mapdb_updated.txt --------------------------->|
      |        │        |                    |                    |                  |
      |        │   O bien:                   |                    |                  |
      |        │        |                    |                    |                  |
      |        │        |  304 Not Modified  |                    |                  |
      |        │        |<-------------------|                    |                  |
      |        │        |                    |                    |                  |
      |        │        |--- Leer .mapdb_cache.json -------------------------------->|
      |        │        |<--- JSON cacheado -----------------------------------------|
      |        └────────┤                    |                    |                  |
      |                 |                    |                    |                  |
      |                 | Por cada mapa nuevo:                   |                  |
      |                 |   Song.load_from_db_data()             |                  |
      |                 |   map_registry.add_item(song)          |                  |
      |                 |                    |                    |                  |
      | db_maps_done    |                    |                    |                  |
      |<----------------|                    |                    |                  |
```

### Descarga individual de mapa

```
  Jugador       UI/MapList       Rhythia          Online          Servidor          Disco
     |               |               |               |               |               |
     | click mapa    |               |               |               |               |
     |-------------->|               |               |               |               |
     |               | select_song() |               |               |               |
     |               |-------------->|               |               |               |
     |               |               |               |               |               |
     |               |  download_start               |               |               |
     |               |<--------------|               |               |               |
     |               |               |               |               |               |
     |          DownloadScreen       | download_map()|               |               |
     |          se muestra           |-------------->|               |               |
     |               |               |               |               |               |
     |               |               |          test_connection()    |               |
     |               |               |               |-- GET ------->| (google.com)  |
     |               |               |               |<-- OK --------|               |
     |               |               |               |               |               |
     |               |               |               | Eliminar .part              -->|
     |               |               |               |               |               |
     |               |               |               | GET download_url              |
     |               |               |               |-------------->| (map server)  |
     |               |               |               |               |               |
     |               |  _process():  |               |               |               |
     |               |  lee progreso |               |               |               |
     |               |  (% descarga) |               |               |               |
     |               |               |               |               |               |
     |               |               |               |<-- 200 + body |               |
     |               |               |               |               |               |
     |               |               |               | Renombrar .part --> maps/{id} >|
     |               |               |               | load_from_sspm()            -->|
     |               |               |               | convert_to_sspm() (si necesario)
     |               |               |               | load_from_sspm() (recarga)  -->|
     |               |               |               |               |               |
     |               |               | map_downloaded |               |               |
     |               |               |<--------------|               |               |
     |               |               |               |               |               |
     |               | download_done |               |               |               |
     |               |<--------------|               |               |               |
     |               |               |               |               |               |
     |               | selected_song_changed          |               |               |
     |               |<--------------|               |               |               |
```

### Cancelacion de descarga

```
  Jugador      DownloadScreen      Online          HTTPRequest
     |               |               |               |
     | click Cancel  |               |               |
     |-------------->|               |               |
     |               | cancel()      |               |
     |               |-------------->|               |
     |               |               | cancel_request()
     |               |               |-------------->|
     |               |               |               |
     |               |               | emit _mapdl_req({result=-1})
     |               |               |-----.         |
     |               |               |     |         |
     |               |               |<----'         |
     |               |               |               |
     |               |               | mapdl_error("Cancelled")
     |               |               |-----.         |
     |               |               |     |         |
     |               |               |<----'         |
     |               |               |               |
     |               |               | emit map_downloaded(success=false)
```

---

## Archivos relacionados

| Archivo | Proposito |
|---------|-----------|
| `scripts/Online.gd` | Autoload principal del sistema online |
| `scripts/Rhythia.gd` | Orquesta la descarga desde `select_song()` |
| `scripts/ui/menu/DownloadScreen.gd` | UI de progreso de descarga con boton de cancelar |
| `scripts/ui/menu/buttons/v2MapList.gd` | Lista de mapas v2, recarga al completar descarga |
| `scripts/ui/menu/buttons/v3MapList.gd` | Lista de mapas v3, actualiza nubes al completar descarga |
| `project.godot` | Configuracion de networking (URLs, habilitacion) |
