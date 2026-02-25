# Arquitectura de Sound Space Plus (Rhythia)

## Descripcion del proyecto

**Sound Space Plus** (tambien conocido como **Rhythia**) es un juego de ritmo de codigo abierto
construido con **Godot 3.x** y **GDScript**. Inspirado en titulos como *osu!* y *Sound Space*,
el proyecto fue creado por **Edward "BTMC" Ling** y cuenta con una comunidad activa de
colaboradores.

El jugador debe hacer clic en notas que aparecen en un espacio 3D al ritmo de la musica,
acumulando puntos por precision y manteniendo una barra de energia que determina la
supervivencia durante la partida.

---

## Informacion tecnica

| Propiedad              | Valor                                |
|------------------------|--------------------------------------|
| Motor                  | Godot 3.x                           |
| Lenguaje               | GDScript                             |
| Resolucion de ventana  | 1280 x 720 px                        |
| Tasa de fisica         | 120 FPS                              |
| Version                | oct31-2024                           |
| Plataformas            | Windows, Linux, macOS, Android, VR   |
| Licencia               | Codigo abierto                       |

---

## Diagrama de arquitectura general

```
+======================================================================+
|                     SOUND SPACE PLUS (RHYTHIA)                       |
+======================================================================+

  +------------------+      +------------------+     +-----------------+
  |     Globals      |      |     Rhythia      |     |     Online      |
  | (constantes,     |      | (estado central, |     | (red, API,      |
  |  enums,          |<---->|  configuracion,  |<--->|  descargas de   |
  |  utilidades,     |      |  registros)      |     |  mapas)         |
  |  UI managers)    |      +--------+---------+     +--------+--------+
  +--------+---------+               |                        |
           |                         |                        v
           |    +--------------------+----+          +-----------------+
           |    |                         |          |    Registry     |
           |    v                         v          | (canciones,     |
           | +-----------+     +----------------+    |  colorsets,     |
           | | init.gd   |     |   Autoloads    |    |  mundos,        |
           | | (arranque)|     | RQueue, Dance, |    |  meshes,        |
           | +-----+-----+    | SFXManager,    |    |  efectos)       |
           |       |           | Discord        |    +-----------------+
           |       v           +----------------+
           | +-----------+
           | |  Intro    |
           | | (splash)  |
           | +-----+-----+
           |       |
           |       v
  +--------+------------------+
  |          MENU             |
  | (menu2.tscn)              |
  |                           |
  |  +----------+ +--------+  |      +-------------------+
  |  | Settings | | Queue  |  |      |   Content Manager |
  |  | (~30 pag)| | (cola) |  |      |   (cmgr)          |
  |  +----------+ +--------+  |      +-------------------+
  |  +----------+ +--------+  |
  |  | Avatars  | | Online |  |
  |  +----------+ +--------+  |
  +-------------+-------------+
                |
                v
  +==============================+
  |           GAME               |
  |     (scenes/song.tscn)       |
  |                              |
  |  +--------+   +-----------+  |     +------------------+
  |  | Game.gd|<->|NoteManager|  |<--->| Song / Note data |
  |  +--------+   +-----------+  |     +------------------+
  |  +--------+   +-----------+  |
  |  | HUD.gd |   | Camera.gd|  |     +------------------+
  |  +--------+   +-----------+  |     | Cursor / Dance   |
  |  +--------+   +-----------+  |<--->| (Simple, Bouncy, |
  |  |SFXMgr  |   | Cursor.gd|  |     |  Directional,    |
  |  +--------+   +-----------+  |     |  Momentum)       |
  +==============================+     +------------------+

  +-------------------+    +-------------------+    +------------------+
  |   Sistema VR      |    |  Sistema Avatar   |    |     Addons       |
  |   (opcional,      |    |  (editor,         |    | (Discord SDK,    |
  |    OpenVR)        |    |   accesorios)     |    |  OpenVR,         |
  |   vr/             |    |   scripts/avatar/ |    |  Native Dialogs) |
  +-------------------+    +-------------------+    +------------------+
```

**Flujo de datos principal:**

```
Globals (constantes/utilidades) ──> utilizado por TODOS los sistemas
Rhythia (estado) ──> hub central de comunicacion
init.gd ──> arranque ──> Intro ──> Menu ──> Game
Game.gd <──> NoteManager <──> Song/Note data
Online ──> descargas ──> Registry
UI/Menu ──> Settings, Queue, Content Manager
```

---

## Mapa de directorios

### `scripts/` - 178 archivos GDScript organizados por sistema

| Directorio                     | Descripcion                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `scripts/game/`               | Mecanicas del juego: `Game.gd`, `NoteManager.gd`, `HUD.gd`, `Camera.gd`, `Cursor.gd`, `SFXManager.gd`, etc. |
| `scripts/content/`            | Sistema de contenido: `Registry.gd`, `Song.gd`, `Note.gd`, etc.            |
| `scripts/content/game/`       | Modelos de datos: Song, Note, ColorSet, BackgroundWorld, Replay, NoteMesh, NoteEffect |
| `scripts/content/resources/`  | Cargadores: `AudioLoader.gd`, `ImageLoader.gd`, `ObjParse.gd`, `ResourceQueue.gd`, `gdunzip.gd` |
| `scripts/ui/`                 | Interfaz de usuario general                                                 |
| `scripts/ui/menu/`            | Menu principal y botones de navegacion                                      |
| `scripts/ui/settings/`        | ~30 paginas de configuracion del juego                                      |
| `scripts/ui/cmgr/`            | Gestor de contenido (Content Manager)                                       |
| `scripts/ui/avatarEditor/`    | Editor de avatar                                                            |
| `scripts/cursordance/`        | Sistema de cursor dance: `Dance.gd`, `DanceMover.gd`, Simple, Bouncy, Directional, Momentum |
| `scripts/avatar/`             | Sistema de avatar                                                           |
| `scripts/loaders/`            | Scripts de carga de escenas                                                 |

### `scenes/` - Escenas de Godot (.tscn)

| Directorio / Archivo      | Descripcion                            |
|----------------------------|----------------------------------------|
| `scenes/init.tscn`        | Punto de entrada principal del juego   |
| `scenes/Intro.tscn`       | Secuencia de introduccion (splash)     |
| `scenes/menu/`            | Menus del juego                        |
| `scenes/song.tscn`        | Escena principal de gameplay           |
| `scenes/loaders/`         | Pantallas de carga                     |
| `scenes/errors/`          | Pantallas de error                     |

### `assets/` - ~130 MB de recursos

| Directorio               | Descripcion                          | Tamano aprox. |
|--------------------------|--------------------------------------|---------------|
| `assets/images/`         | Texturas de interfaz                 | 38 MB         |
| `assets/worlds/`         | 15+ mundos de fondo                  | 61 MB         |
| `assets/sfx/`            | Efectos de sonido                    | 7.9 MB        |
| `assets/songs/`          | Canciones incluidas                  | 14 MB         |
| `assets/font/`           | Fuentes tipograficas                 | 18 MB         |
| `assets/notefx/`         | Efectos de particulas para notas     | -             |
| `assets/meshes/`         | Modelos 3D                           | -             |
| `assets/shaders/`        | Shaders personalizados               | -             |
| `assets/blocks/`         | Graficos de notas                    | -             |
| `assets/accessories/`    | Accesorios de avatar                 | -             |

### Otros directorios

| Directorio       | Descripcion                                              |
|------------------|----------------------------------------------------------|
| `prefabs/`       | Plantillas de escenas reutilizables                      |
| `addons/`        | Plugins externos (Discord SDK, OpenVR, Native Dialogs)   |
| `vr/`            | Codigo especifico de realidad virtual                    |
| `localization/`  | Traducciones (en, ja, fr, es)                            |

---

## Autoloads (Singletons globales)

Los autoloads se configuran en `project.godot` y estan disponibles globalmente en todo
el arbol de escenas.

| Singleton      | Archivo                              | Responsabilidad                                                |
|----------------|--------------------------------------|----------------------------------------------------------------|
| `Globals`      | `scripts/Globals.gd`                | Constantes, enums, utilidades, managers de UI                  |
| `Rhythia`      | `scripts/Rhythia.gd`                | Estado central del juego, configuracion, registros de contenido|
| `Online`       | `scripts/Online.gd`                 | Funcionalidad de red, API, descarga de mapas                   |
| `RQueue`       | *(ResourceQueue)*                    | Cola de recursos asincronicos                                  |
| `Discord`      | *(addon)*                            | Integracion Discord Rich Presence                              |
| `Dance`        | `scripts/cursordance/Dance.gd`      | Sistema de cursor dance y animaciones                          |
| `SFXManager`   | `scripts/game/SFXManager.gd`        | Gestor de efectos de sonido                                    |

### Relacion entre singletons

```
Globals ────────────> utilizado por todos los scripts
    |
    v
Rhythia ────> estado central, configuracion, registros
    |
    +--------> Online ────> descargas, API
    |
    +--------> Dance ─────> cursor dance
    |
    +--------> SFXManager -> efectos de sonido
    |
    +--------> RQueue ────> carga asincronica
    |
    +--------> Discord ───> Rich Presence
```

---

## Flujo de inicializacion

El proceso de arranque del juego sigue una secuencia determinista:

```
project.godot
  |
  v
scenes/init.tscn  (punto de entrada principal)
  |
  +---> Globals._ready()
  |       |
  |       +---> Inicia thread: Rhythia.do_init()
  |               |
  |               +---> Carga registros (canciones, colorsets, mundos, meshes, efectos)
  |               +---> Carga mods y DLC
  |               +---> Carga configuracion del usuario (settings)
  |               +---> Senaliza finalizacion
  |
  +---> init.gd muestra barra de progreso
  |       |
  |       +---> Precarga escena de menu via RQueue
  |
  v
(Opcional) scenes/Intro.tscn  -  Splash / secuencia de introduccion
  |
  v
scenes/loaders/menuload.tscn  -  Pantalla de carga del menu
  |
  v
scenes/menu/menu2.tscn  -  Menu principal
  |
  +---> Usuario selecciona cancion
  |
  v
scenes/loaders/songload.tscn  -  Pantalla de carga de la cancion
  |
  v
scenes/song.tscn  -  Escena de gameplay
  |
  +---> Al terminar la partida: vuelta al menu
  |
  v
scenes/menu/menu2.tscn
```

---

## Caracteristicas principales

### Gameplay

- Juego de ritmo con deteccion de notas en espacio 3D
- 9 niveles de velocidad configurables
- Sistema de puntuacion con precision y combos
- Barra de energia que determina supervivencia
- Records personales (PB) persistentes
- Sistema de replays completo
- Cola de canciones (queue) para sesiones continuas

### Contenido

- Sistema de contenido con multiples formatos de mapas:
  - **TXT** - formato de texto plano
  - **RAW** - formato binario sin comprimir
  - **SSPM v1/v2** - formato binario propio (Sound Space Plus Map)
  - **Vulnus** - formato de la comunidad
  - **NET** - formato de red
- 15+ mundos de fondo intercambiables
- Sistema de avatar personalizable con editor integrado
- Accesorios y personalizacion visual

### Modificadores de gameplay

| Modificador     | Efecto                                      |
|-----------------|---------------------------------------------|
| `chaos`         | Notas con movimiento aleatorio              |
| `earthquake`    | Vibracion de pantalla                       |
| `ghost`         | Notas parcialmente invisibles               |
| `nearsighted`   | Notas visibles solo de cerca                |
| `hardrock`      | Mayor dificultad general                    |
| `nofail`        | No se puede perder la partida               |
| `sudden death`  | Un fallo termina la partida inmediatamente  |

### Sistemas adicionales

- **Soporte VR completo** via OpenVR
- **Integracion Discord** Rich Presence
- **Multi-idioma**: ingles (en), japones (ja), frances (fr), espanol (es)
- **Sistema de cursor dance** con multiples animaciones (Simple, Bouncy, Directional, Momentum)
- **Soporte Android** para dispositivos moviles

---

## Indice de documentos

La documentacion de arquitectura se divide en los siguientes documentos especializados:

| #  | Documento                                                  | Descripcion                                          |
|----|------------------------------------------------------------|------------------------------------------------------|
| 01 | [globals-y-estado.md](./globals-y-estado.md)               | Estado global, constantes, inicializacion            |
| 02 | [gameplay.md](./gameplay.md)                               | Loop de juego, notas, puntaje, energia               |
| 03 | [contenido.md](./contenido.md)                             | Registros, canciones, formatos, replays              |
| 04 | [recursos.md](./recursos.md)                               | Carga de audio, imagenes, modelos, ZIP               |
| 05 | [ui-menus.md](./ui-menus.md)                               | Interfaz, menus, navegacion                          |
| 06 | [settings.md](./settings.md)                               | Sistema de configuracion                             |
| 07 | [cursor-dance.md](./cursor-dance.md)                       | Animaciones de cursor                                |
| 08 | [avatar.md](./avatar.md)                                   | Sistema de avatar                                    |
| 09 | [online.md](./online.md)                                   | Sistema online, API, descargas                       |
| 10 | [vr.md](./vr.md)                                           | Soporte de realidad virtual                          |
| 11 | [addons.md](./addons.md)                                   | Plugins externos                                     |
| 12 | [localizacion-y-assets.md](./localizacion-y-assets.md)     | Localizacion y recursos                              |
| 13 | [escenas-y-loaders.md](./escenas-y-loaders.md)             | Escenas y cargadores                                 |

---

## Patrones de diseno utilizados

### Comunicacion basada en senales (Signal-based)

Godot utiliza un sistema de senales para la comunicacion entre nodos. En Rhythia, las
senales se emplean extensivamente para desacoplar sistemas. Por ejemplo, `NoteManager`
emite senales cuando se procesa una nota, y `HUD` las recibe para actualizar la interfaz.

### Patron Registry para contenido

El sistema `Registry` actua como un catalogo centralizado para todo el contenido del juego:
canciones, colorsets, mundos, meshes y efectos. Los registros se cargan al inicio y se
consultan desde cualquier sistema que necesite acceder a contenido.

### Carga lazy (diferida)

Las portadas de canciones (covers) y los records personales (PBs) se cargan bajo demanda,
evitando consumir memoria innecesariamente al inicio. Solo se cargan cuando el usuario
navega a una cancion especifica.

### Cola de recursos asincronicos

`RQueue` (ResourceQueue) gestiona la carga asincronica de recursos pesados (escenas, audio,
texturas), mostrando barras de progreso durante las transiciones y evitando bloqueos del
hilo principal.

### Serializacion binaria (SSPM) y JSON

Los mapas de canciones se almacenan en formato binario SSPM (v1/v2) para eficiencia, mientras
que la configuracion del usuario y otros datos de estado se persisten en formato JSON.

### MultiMesh para rendering eficiente

Las notas en pantalla se renderizan usando MultiMesh de Godot, permitiendo dibujar cientos
de notas simultaneamente con un costo de GPU minimo al agruparlas en una sola llamada de
dibujo (draw call).

### Senales diferidas (call_deferred)

Se usa `call_deferred()` para operaciones que deben ejecutarse al final del frame, evitando
conflictos con el arbol de escenas durante la ejecucion de `_process()` o `_physics_process()`.

---

## Convenciones del proyecto

- Los scripts se nombran en **PascalCase** para clases principales y **snake_case** para
  utilidades.
- Las escenas (`.tscn`) siguen la misma convencion que sus scripts asociados.
- Los autoloads se acceden directamente por nombre (por ejemplo, `Rhythia.current_song`).
- La configuracion del usuario se almacena en el directorio `user://` de Godot.
- Los registros de contenido son diccionarios indexados por identificador unico.

---

*Documentacion generada para Sound Space Plus (Rhythia) - Motor Godot 3.x - Version oct31-2024*
