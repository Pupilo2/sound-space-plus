# Sistema de Gameplay

> Documentacion del sistema principal de juego de Sound Space Plus (Rhythia), un juego de ritmo desarrollado en Godot 3.x.

---

## Tabla de contenidos

1. [Vision general](#vision-general)
2. [Scripts del modulo](#scripts-del-modulo)
3. [Diagrama de flujo](#diagrama-de-flujo)
4. [Game.gd (SongPlayerManager)](#gamegd-songplayermanager)
5. [NoteManager.gd](#notemanagergd)
6. [HUD.gd](#hudgd)
7. [Camera.gd y CameraControl.gd](#cameragd-y-cameracontrolgd)
8. [Cursor.gd y CursorTrail.gd](#cursorgd-y-cursortrailgd)
9. [PauseHud.gd](#pausehudgd)
10. [TrueComboHandler.gd](#truecombohandlergd)
11. [SFXManager.gd](#sfxmanagergd)
12. [FlashlightModifier.gd](#flashlightmodifiergd)
13. [Friend.gd](#friendgd)
14. [FaceNote.gd](#facenotegd)
15. [Sistema de puntaje](#sistema-de-puntaje)
16. [Sistema de energia](#sistema-de-energia)
17. [Sistema de combo](#sistema-de-combo)
18. [Modificadores](#modificadores)

---

## Vision general

El sistema de Gameplay es el nucleo de la experiencia interactiva de Rhythia. Se encarga de:

- Cargar y parsear mapas de canciones
- Renderizar notas eficientemente usando MultiMesh
- Detectar colisiones entre el cursor del jugador y las notas
- Calcular puntaje, combo y energia
- Gestionar la interfaz de usuario durante la partida
- Aplicar modificadores de dificultad
- Grabar y reproducir replays
- Controlar la camara, el cursor y los efectos visuales

---

## Scripts del modulo

| Script | Ruta | Extiende | Clase | Proposito |
|--------|------|----------|-------|-----------|
| Game.gd | `scripts/game/Game.gd` | Spatial | SongPlayerManager | Loop principal: puntaje, energia, hits/misses, logica de fin de cancion |
| NoteManager.gd | `scripts/game/NoteManager.gd` | Spatial | NoteManager | Renderizado MultiMesh de notas, deteccion de colisiones, timing |
| HUD.gd | `scripts/game/HUD.gd` | Spatial | - | Interfaz durante el juego: score, combo, energia, timer, accuracy, grado |
| Camera.gd | `scripts/game/Camera.gd` | Camera | - | Camara del juego con parallax y modo de desbloqueo (spin) |
| CameraControl.gd | `scripts/game/CameraControl.gd` | Spatial | - | Control avanzado de camara libre con freelook y movimiento |
| Cursor.gd | `scripts/game/Cursor.gd` | Spatial | - | Cursor del jugador: movimiento por mouse/joystick/absoluto |
| CursorTrail.gd | `scripts/game/CursorTrail.gd` | Spatial | - | Efecto de trail/estela detras del cursor |
| PauseHud.gd | `scripts/game/PauseHud.gd` | Control | - | Barra de progreso de des-pausa |
| TrueComboHandler.gd | `scripts/game/TrueComboHandler.gd` | Label | - | Muestra el combo verdadero (numero consecutivo de hits) con animacion |
| SFXManager.gd | `scripts/game/SFXManager.gd` | Node | - | Autoload: pool de sonidos de hit (hasta 48 nodos de audio) |
| FlashlightModifier.gd | `scripts/game/FlashlightModifier.gd` | Spatial | - | Modificador linterna: oscurece pantalla excepto alrededor del cursor |
| Friend.gd | `scripts/game/Friend.gd` | MeshInstance | - | Avatar de amigo con texturas segun estado del juego |
| FaceNote.gd | `scripts/game/FaceNote.gd` | MeshInstance | - | Notas que rotan para mirar hacia el cursor del jugador |

---

## Diagrama de flujo

```
┌──────────────────────────────────────────────────┐
│              FLUJO DE GAMEPLAY                    │
├──────────────────────────────────────────────────┤
│                                                   │
│  Song seleccionada en menu                        │
│       │                                           │
│       ▼                                           │
│  Game._ready()                                    │
│       │── Obtiene Song de Rhythia                 │
│       │── Carga colorset, velocidad               │
│       │── Configura energia/salud                 │
│       │── Crea mundo de fondo (loaded_world)      │
│       │── Conecta senales de NoteManager          │
│       │                                           │
│       ▼                                           │
│  Game.loadMapFile()                               │
│       │── Song.read_notes() → parsea datos        │
│       │── NoteManager.spawn_notes(notas)          │
│       │── Configura stream de audio               │
│       │── Inicia replay si habilitado             │
│       │                                           │
│       ▼                                           │
│  LOOP PRINCIPAL (cada frame)                      │
│       │                                           │
│       ├── NoteManager._process(delta)             │
│       │   ├── Actualiza ms (tiempo en ms)         │
│       │   ├── Gestiona pausa/skip/replay          │
│       │   ├── Sincroniza audio si desync          │
│       │   └── reposition_notes()                  │
│       │       ├── Actualiza posicion Z (approach) │
│       │       ├── Aplica rotacion/spin de notas   │
│       │       ├── Aplica fade in/out              │
│       │       ├── Aplica modificadores            │
│       │       └── Verifica colisiones             │
│       │                                           │
│       ├── ¿Colision detectada?                    │
│       │   ├── SI → Game.hit(color)                │
│       │   │   ├── +score (get_point_amt)          │
│       │   │   ├── +combo, +combo_level            │
│       │   │   ├── +energia (si no mod_no_regen)   │
│       │   │   ├── Efecto visual de hit            │
│       │   │   └── Popup de score (opcional)       │
│       │   │                                       │
│       │   └── NO (paso hit_window)                │
│       │       → Game.miss(color)                  │
│       │       ├── combo = 0, combo_level -= 1     │
│       │       ├── -1 energia                      │
│       │       ├── Efecto visual de miss           │
│       │       └── ¿energia == 0?                  │
│       │           ├── nofail: marca fallo          │
│       │           └── otro: end(END_FAIL)         │
│       │                                           │
│       └── ¿Cancion terminada?                     │
│           └── (musica dejo de sonar o              │
│                todas las notas completadas)       │
│               → end(END_PASS)                     │
│                                                   │
│  Game.end(tipo)                                   │
│       ├── Guarda stats → Rhythia                  │
│       ├── Guarda replay                           │
│       ├── ¿PASS + queue activa?                   │
│       │   ├── Verifica PB (personal best)         │
│       │   ├── Carga siguiente cancion             │
│       │   └── Reinicia NoteManager                │
│       ├── ¿FAIL + restart_on_death?               │
│       │   └── Recarga escena song.tscn            │
│       └── Otro caso                               │
│           └── Fade a negro → vuelve al menu       │
└──────────────────────────────────────────────────┘
```

---

## Game.gd (SongPlayerManager)

**Ruta:** `scripts/game/Game.gd`
**Extiende:** `Spatial`
**Nombre de clase:** `SongPlayerManager`

### Proposito

Es el controlador principal del gameplay. Gestiona el ciclo de vida completo de una partida: desde la carga del mapa hasta la finalizacion de la cancion, pasando por el registro de hits, misses, calculo de puntaje, gestion de energia y logica de combo.

### Senales

| Senal | Descripcion |
|-------|-------------|
| `hit` | Emitida cuando el jugador golpea una nota exitosamente |
| `miss` | Emitida cuando el jugador falla una nota |

### Variables de estado

| Variable | Tipo | Valor inicial | Descripcion |
|----------|------|---------------|-------------|
| `rawMapData` | `String` | - | Datos crudos del mapa |
| `notes` | `Array` | - | Notas parseadas de la cancion |
| `last_ms` | `float` | `0` | Duracion total de la cancion en milisegundos |
| `colors` | `Array` | - | Colores del colorset seleccionado |
| `speed_multi` | `float` | - | Multiplicador de velocidad actual |
| `score` | `int` | `0` | Puntaje acumulado |
| `combo` | `int` | `0` | Combo actual (hits consecutivos) |
| `combo_level` | `int` | `1` | Nivel de combo (1 a 8) |
| `lvl_progress` | `int` | `0` | Progreso dentro del nivel de combo (0 a 10) |
| `hits` | `float` | `0` | Total de hits registrados |
| `misses` | `float` | `0` | Total de misses registrados |
| `total_notes` | `float` | `0` | Total de notas procesadas (hits + misses) |
| `max_combo` | `int` | `0` | Combo maximo alcanzado en la partida |
| `energy` | `float` | `6` | Energia/vida actual |
| `max_energy` | `float` | `6` | Energia maxima |
| `energy_per_hit` | `float` | `1` | Energia recuperada por cada hit |
| `song_has_failed` | `bool` | `false` | Indica si la cancion ha fallado (nofail) |
| `ending` | `bool` | `false` | Indica si la cancion esta terminando |
| `passed` | `bool` | `false` | Indica si el jugador paso la cancion |
| `giving_up` | `float` | `0` | Progreso de la accion "give up" (0 a 1) |
| `black_fade` | `float` | `1` | Opacidad del fade a negro (transiciones) |

### Metodos clave

#### `_ready()`

Inicializa la partida:

1. Configura el modelo de energia segun `Rhythia.health_model` y modificadores
2. Establece `energy = max_energy`
3. Instancia el mundo de fondo (`Rhythia.loaded_world`)
4. Conecta senales del NoteManager (`timer_update`, `miss`)
5. Llama a `loadMapFile()`
6. Actualiza el estado de Discord/Rich Presence
7. Espera 4 frames idle, luego desactiva el fade negro y activa el NoteManager

#### `loadMapFile()`

Carga y prepara la cancion:

1. Obtiene el `Song` seleccionado de `Rhythia.selected_song`
2. Si la cancion requiere recarga, llama a `setup_from_file()`
3. Parsea las notas con `map.read_notes()`
4. Pasa las notas al NoteManager con `$Spawn.spawn_notes(notes)`
5. Configura el stream de audio en el nodo `Music`

#### `hit(col: Color) -> int`

Registra un hit exitoso:

1. Emite la senal `hit`
2. Incrementa `hits` y `total_notes`
3. Regenera energia (si no tiene `mod_no_regen`)
4. Incrementa `combo`, actualiza `max_combo`
5. Avanza `lvl_progress`; si llega a 10, sube `combo_level`
6. Calcula los puntos con `get_point_amt()`
7. Aplica efectos de FOV si `Rhythia.hit_fov` esta habilitado
8. Suma los puntos al `score`
9. Retorna la cantidad de puntos otorgados

#### `miss(col: Color)`

Registra un miss:

1. Emite la senal `miss`
2. Incrementa `misses` y `total_notes`
3. Reduce `energy` en 1 (clamp a 0)
4. Resetea `combo` a 0 y `lvl_progress` a 0
5. Reduce `combo_level` en 1 (minimo 1)
6. Si `energy == 0`:
   - Con `mod_nofail`: marca `song_has_failed` y reproduce sonido de fallo
   - Sin nofail: llama a `end(Globals.END_FAIL)`

#### `end(end_type: int)`

Finaliza la cancion:

1. Evita ejecucion duplicada con el flag `ending`
2. Si es `END_GIVEUP`, almacena senal en el replay
3. Si no es `END_PASS`, reproduce sonido de fallo
4. Pausa el arbol de escenas
5. Guarda todas las estadisticas en las variables `Rhythia.song_end_*`
6. Cierra la grabacion del replay si estaba activa
7. Logica de transicion:
   - **PASS + queue activa**: verifica personal best, carga siguiente cancion, reinicia NoteManager
   - **FAIL + restart_on_death**: recarga la escena `song.tscn`
   - **Otro caso**: fade a negro y transicion al menu

#### `get_point_amt() -> int`

Calcula los puntos por hit (ver [Sistema de puntaje](#sistema-de-puntaje)).

#### `_process(delta)`

Loop principal por frame:

1. Detecta si la cancion termino para mostrar expresion feliz en el avatar
2. Gestiona la animacion del brazo al pasar la cancion
3. Detecta la accion "give up" (mantener 0.6 segundos)
4. Gestiona pausa/des-pausa durante replays
5. Actualiza el fade negro de transicion

---

## NoteManager.gd

**Ruta:** `scripts/game/NoteManager.gd`
**Extiende:** `Spatial`
**Nombre de clase:** `NoteManager`

### Proposito

Gestiona todo el ciclo de vida de las notas: creacion, posicionamiento, renderizado eficiente mediante MultiMesh, deteccion de colisiones, y aplicacion de modificadores visuales. Tambien maneja el timing de la musica, la sincronizacion de audio, las pausas y la grabacion de replays.

### Senales

| Senal | Descripcion |
|-------|-------------|
| `ms_change` | Emitida cuando cambia el tiempo de reproduccion |
| `timer_update` | Emitida cada frame con el ms actual y si se puede saltar |
| `hit` | Emitida al detectar un hit (propagada a Game) |
| `miss` | Emitida al detectar un miss (propagada a Game) |

### Estructura de datos de una nota

Cada nota es un `Array` con 6 elementos:

| Indice | Tipo | Descripcion |
|--------|------|-------------|
| `[0]` | `Vector2` | Posicion en la grilla (x, y) |
| `[1]` | `float` | Timestamp en milisegundos |
| `[2]` | `int` | Estado: `NSTATE_ACTIVE`, `NSTATE_HIT`, `NSTATE_MISS` |
| `[3]` | `Color` | Color de la nota (del colorset) |
| `[4]` | `Vector2` | Offset para el modificador Chaos |
| `[5]` | `Transform` | Transform actual de la nota |

### Variables de timing

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `ms` | `float` | Tiempo actual de reproduccion en milisegundos |
| `prev_ms` | `float` | Timestamp de la nota anterior procesada |
| `next_ms` | `float` | Timestamp de la proxima nota a procesar |
| `approach_rate` | `float` | Tasa de aproximacion (de `Rhythia.approach_rate`) |
| `hit_window` | `float` | Ventana de hit en ms (de `Rhythia.hitwindow_ms`) |
| `speed_multi` | `float` | Multiplicador de velocidad |
| `notes_loaded` | `bool` | Indica si las notas fueron cargadas |
| `active` | `bool` | Indica si el NoteManager esta procesando |
| `music_started` | `bool` | Indica si la musica comenzo a reproducirse |
| `current_note` | `int` | Indice de la primera nota visible (optimizacion) |
| `rms` | `float` | Tiempo real en ms (no afectado por velocidad) |
| `ms_offset` | `float` | Offset acumulado para colas de canciones |

### Variables de efectos visuales

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `hitEffect` | `Spatial` | Instancia del efecto visual de hit |
| `missEffect` | `Spatial` | Instancia del efecto visual de miss |
| `scoreEffect` | `Spatial` | Instancia del popup de puntaje |
| `fade_in_enabled` | `bool` | Si el fade in de notas esta activo |
| `fade_in_start` | `float` | Distancia donde comienza el fade in (default 8) |
| `fade_in_end` | `float` | Distancia donde termina el fade in (default 6) |
| `fade_out_enabled` | `bool` | Si el fade out de notas esta activo |
| `fade_out_start` | `float` | Distancia donde comienza el fade out (default 3) |
| `fade_out_end` | `float` | Distancia donde termina el fade out (default 1) |

### Calculo de approach (distancia de aproximacion)

La distancia de cada nota respecto al jugador se calcula asi:

```
approachSpeed = approach_rate / speed_multi
current_offset_ms = notems - ms
current_dist = approachSpeed * current_offset_ms / 1000
```

Donde:
- `approach_rate` es la velocidad de aproximacion configurada
- `speed_multi` es el multiplicador de velocidad del juego
- `notems` es el timestamp de la nota
- `ms` es el tiempo actual

### Metodos clave

#### `spawn_notes(note_array: Array)`

Inicializa todas las notas:

1. Ordena el array por timestamp
2. Calcula la escala de las notas basada en `note_size` y `note_hitbox_size`
3. Itera sobre cada nota creando la estructura interna (posicion, color, estado, etc.)
4. Aplica modificadores de posicion: Hardrock (escala 1.35x), MirrorX, MirrorY
5. Inicializa el MultiMesh con un conteo de instancias dinamico
6. Llama a `reposition_notes(true)` diferidamente

#### `reposition_notes(force: bool = false)`

Reposiciona todas las notas visibles cada frame:

1. Si no quedan notas, oculta el MultiMesh
2. Detecta "rewinds" (si el tiempo retrocedio)
3. Para cada nota desde `current_note`:
   - Llama a `note_reposition(i)` para actualizar su posicion visual
   - Si la nota ya no es visible, establece el conteo visible del MultiMesh
   - Si la nota esta en la ventana de hit, verifica colision
4. Incrementa dinamicamente `instance_count` si se necesitan mas instancias

#### `note_reposition(i: int) -> bool`

Reposiciona una nota individual:

1. Calcula `current_dist` (distancia de approach)
2. Si la nota esta dentro del rango visible y activa:
   - Establece `origin.z = -current_dist`
   - Aplica spin de nota (rotacion en X, Y, Z)
   - Calcula alpha con fade in/out
   - Actualiza el transform y color en el MultiMesh
   - Aplica modificadores (Chaos, Earthquake)
   - Retorna `true` (visible)
3. Si no: oculta la instancia y retorna `false`

#### `note_check_collision(i: int) -> bool`

Verifica si el cursor colisiona con una nota:

- Si esta reproduciendo un replay (sv != 1), usa `replay.should_hit(i)`
- En juego normal: verifica si la posicion del cursor esta dentro del hitbox cuadrado de la nota (`note_hitbox_size / 2`)

#### `_process(delta)`

Loop principal del NoteManager:

1. Calcula delta real con `OS.get_ticks_usec()` para precision
2. Actualiza la posicion de la camara segun el modo (half_lock, spin, VR)
3. Gestiona el sistema de pausa/skip/des-pausa
4. Avanza `ms` segun `delta * 1000 * speed_multi`
5. Inicia la musica cuando `ms + music_offset >= start_offset`
6. Corrige desincronizacion de audio si excede 100ms
7. Llama a `reposition_notes()`
8. Graba la posicion del cursor en el replay

### Deteccion de hits y misses (por frame)

Dentro de `reposition_notes()`, para cada nota cuyo timestamp ya paso:

```
SI ms >= notems Y colision con cursor Y estado == ACTIVE:
    → HIT
    - Registra en replay
    - Cambia estado a NSTATE_HIT
    - Reproduce sonido de hit (via SFXManager)
    - Muestra efecto visual de hit
    - Llama a Game.hit(color)
    - Muestra popup de score

SI ms > notems + hit_window Y estado == ACTIVE:
    → MISS
    - Registra en replay
    - Cambia estado a NSTATE_MISS
    - Reproduce sonido de miss
    - Muestra efecto visual de miss
    - Emite senal miss → Game.miss(color)
```

### Sistema de pausa

El NoteManager gestiona las pausas del juego:

1. **Pausar**: Solo disponible si `ms > 1000 * speed_multi` y `ms < last_ms`, sin cooldown
2. **Des-pausa**: Toma 0.75 segundos manteniendo la tecla de pausa
3. **Cancelar des-pausa**: Soltar la tecla durante la des-pausa
4. **Skip**: Si hay mas de 5 segundos de espacio vacio, se puede saltar
5. Al pausar: `combo_level` se resetea a 1

---

## HUD.gd

**Ruta:** `scripts/game/HUD.gd`
**Extiende:** `Spatial`

### Proposito

Gestiona toda la interfaz visual durante la partida. Muestra y actualiza los siguientes elementos:

- **Score**: Puntaje total formateado con separadores de miles
- **Combo**: Anillo de progreso del nivel de combo (1x a 8x)
- **True Combo**: Numero de hits consecutivos
- **Accuracy**: Porcentaje con 3 decimales y barra de progreso
- **Energy**: Barra de vida/energia
- **Timer**: Barra de progreso y texto con tiempo actual/total
- **Notas**: Contador de hits/total
- **Misses**: Contador de misses con flash visual al fallar
- **Pausas**: Contador de pausas usadas
- **Grado**: Letra de calificacion (SS, S, A, B, C, D, F) con colores personalizables
- **Modificadores**: Iconos y texto de los mods activos

### Grados de calificacion

| Grado | Accuracy | Color |
|-------|----------|-------|
| SS | 100% | Rainbow (configurable saturacion/brillo) |
| S | >= 98% | Configurable con efecto shine |
| A | >= 95% | Configurable |
| B | >= 90% | Configurable |
| C | >= 85% | Configurable |
| D | >= 80% | Configurable |
| F | < 80% | Configurable |

### Caracteristicas adicionales

- Todos los colores son personalizables desde la configuracion de Rhythia
- Soporte para HUD rainbow (todos los elementos cambian de color)
- Modo HUD simple: solo muestra misses y pausas
- Modo HUD lejano: escala 3.7x con offset de z=-10
- Expansion del HUD con Hardrock (escala de grilla 1.35x, reposicionamiento de paneles)
- Opcion de adjuntar la barra de HP y el timer a la grilla
- Flash rojo en el contador de misses al fallar

---

## Camera.gd y CameraControl.gd

### Camera.gd

**Ruta:** `scripts/game/Camera.gd`
**Extiende:** `Camera`

#### Proposito

Camara principal del juego. Gestiona dos modos de control:

**Modo HALF_LOCK (por defecto):**
- La camara sigue al cursor con parallax suave
- El offset se calcula como `centeroff * parallax * 0.1 * 0.25`
- La posicion Z de la camara es fija en 3.75

**Modo FULL_LOCK (cam_unlock):**
- El jugador controla la camara libremente con el mouse
- Yaw y pitch calculados desde el movimiento relativo del mouse
- Limitado a pitch entre -89 y 89 grados
- Usa un RayCast para determinar donde apunta el cursor en la grilla
- Soporta modo absoluto con `AbsCamera`

#### Efectos adicionales

- **Hit FOV**: Al golpear una nota, el FOV cambia (aditivo, exponencial o fijo)
- **FOV Decay**: El FOV retorna suavemente al valor base con `Rhythia.hit_fov_decay`
- **Parallax de UI**: Los paneles del HUD se mueven en sentido opuesto al cursor
- **Parallax de grilla**: La grilla se mueve en sentido opuesto al cursor

### CameraControl.gd

**Ruta:** `scripts/game/CameraControl.gd`
**Extiende:** `Spatial`

#### Proposito

Control avanzado de camara libre basado en el plugin de Maujoe (MIT License). Proporciona:

- **Freelook**: Rotacion con mouse, input actions, o ambos
- **Movimiento**: WASD con aceleracion y desaceleracion configurable
- **Pivot**: Rotacion alrededor de un punto pivote con distancia configurable
- **Colisiones**: Deteccion de obstaculos con raycast
- **Smoothness**: Suavizado de rotacion configurable (0.001 a 0.999)
- **Limites**: Limites de yaw y pitch configurables

---

## Cursor.gd y CursorTrail.gd

### Cursor.gd

**Ruta:** `scripts/game/Cursor.gd`
**Extiende:** `Spatial`

#### Proposito

Gestiona el cursor del jugador, el elemento central de interaccion.

#### Modos de movimiento

| Modo | Constante | Descripcion |
|------|-----------|-------------|
| Mouse | `C_MOUSE` | Movimiento relativo o absoluto del mouse |
| Joystick | `C_JOYSTICK` | Movimiento con joystick analogico |

El modo se puede cambiar automaticamente segun el ultimo input recibido (solo antes de que empiece la musica, controlado por `can_switch_move_modes`).

#### Movimiento del cursor

- `move_cursor(mdel: Vector2)`: Movimiento relativo. Aplica sensibilidad (`Rhythia.sensitivity`) y escala de render. Clampea la posicion dentro de los limites de la grilla.
- `move_cursor_abs(mdel: Vector2)`: Movimiento absoluto. Posiciona directamente el cursor.
- `get_absolute_position()`: Proyecta la posicion del mouse a coordenadas 3D usando `AbsCamera`.

#### Limites de la grilla

- Grilla base: de `(-0.5, -0.5)` a `(2.5, 2.5)` (con edge clamp de 0.13125)
- Con Hardrock: los limites se expanden (`edgec - 0.6`)
- `rpos`: Posicion "real" del cursor (puede exceder los limites visibles para drift cursor)

#### Caracteristicas visuales

- **Spin**: Rotacion constante configurable con `Rhythia.cursor_spin`
- **Face velocity**: El cursor rota en la direccion del movimiento
- **Color**: Normal, Rainbow, color de nota, o color personalizado
- **Imagen personalizada**: Se puede cargar desde `user://cursor`
- **Inversion de mouse**: Soportado para todos los modos

#### Replays

En modo replay, la posicion del cursor se obtiene directamente de `Rhythia.replay.get_cursor_position()`.

### CursorTrail.gd

**Ruta:** `scripts/game/CursorTrail.gd`
**Extiende:** `Spatial`

#### Proposito

Genera un efecto de trail/estela detras del cursor.

#### Modos de trail

**Smart Trail (modo inteligente):**
- Genera segmentos interpolados entre la posicion actual y la anterior
- La cantidad de segmentos depende de la distancia recorrida y `Rhythia.trail_detail`
- Maximo 120 segmentos por frame
- Usa un sistema de cache: los segmentos completados se reciclan
- Cada segmento tiene un timer que al llegar a 0 lo devuelve al cache

**Dumb Trail (modo simple):**
- Cada segmento sigue al cursor con un offset temporal fijo
- Se reposiciona ciclicamente cuando su timer llega a 1

#### Opciones visuales

- `trail_mode_opacity`: Los segmentos se desvanecen con el tiempo
- `trail_mode_scale`: Los segmentos se encogen con el tiempo
- `trail_time`: Duracion de vida de cada segmento
- Soporta imagen personalizada (`user://trail` o `user://cursor`)

---

## PauseHud.gd

**Ruta:** `scripts/game/PauseHud.gd`
**Extiende:** `Control`

### Proposito

Control simple que muestra la barra de progreso de des-pausa. Cuando el jugador mantiene la tecla de pausa para reanudar, esta barra se llena progresivamente (de 0 a 1 en 0.75 segundos). El ancho visual de la barra es `280 * percent` pixeles.

---

## TrueComboHandler.gd

**Ruta:** `scripts/game/TrueComboHandler.gd`
**Extiende:** `Label`

### Proposito

Muestra el "true combo" (numero consecutivo de hits) con una animacion de deslizamiento. El label se desplaza hacia arriba cuando cambia el combo y vuelve suavemente a su posicion base (y=150) usando interpolacion en `_physics_process`. Solo es visible si `Rhythia.display_true_combo` esta habilitado.

---

## SFXManager.gd

**Ruta:** `scripts/game/SFXManager.gd`
**Extiende:** `Node`

### Proposito

Autoload que gestiona la reproduccion de efectos de sonido de hit. Implementa un pool de hasta 48 nodos de audio para evitar crear/destruir nodos constantemente.

### Funcionamiento

1. `setup()`: Crea el pool de nodos de audio bajo `Song/Game/Spawn/HitSounds`
   - Si `Rhythia.sfx_2d`: usa `AudioStreamPlayer` (2D)
   - Si no: usa `AudioStreamPlayer3D` con atenuacion deshabilitada
   - Todos los nodos usan el bus "HitSound" y `PAUSE_MODE_PROCESS`
2. `play_hitsfx(transform)`: Busca el primer nodo que no este reproduciendo y lo activa
   - En modo 3D, posiciona el nodo en el transform de la nota

---

## FlashlightModifier.gd

**Ruta:** `scripts/game/FlashlightModifier.gd`
**Extiende:** `Spatial`

### Proposito

Implementa el modificador "Flashlight" que oscurece toda la pantalla excepto un area circular alrededor del cursor. El tamano del area visible cambia dinamicamente segun el combo del jugador.

### Escala del area visible

La escala del sprite (`pixel_size`) varia segun el modo de camara y el combo:

| Combo | cam_unlock ON | cam_unlock OFF |
|-------|---------------|----------------|
| >= 100 | 0.050 | 0.025 |
| >= 50 | 0.055 | 0.030 |
| < 50 | 0.060 | 0.040 |

Los valores se interpolan suavemente con `lerp` usando `lspd = 0.025`:
- La posicion se actualiza con `lspd * 40` (movimiento rapido)
- La escala y opacidad se actualizan con `lspd / 2` (transicion suave)

---

## Friend.gd

**Ruta:** `scripts/game/Friend.gd`
**Extiende:** `MeshInstance`

### Proposito

Muestra un avatar de "amigo" con texturas que cambian segun el estado actual del juego. Las texturas se cargan desde `user://friend/` (archivos nombrados segun el estado).

### Estados (en orden de prioridad)

| Estado | Condicion |
|--------|-----------|
| `done` | La cancion termino (ms > last_ms) |
| `fail` | El jugador fallo |
| `givingup` | El jugador esta manteniendo "give up" |
| `unpausing` | El jugador esta des-pausando |
| `paused` | El juego esta pausado |
| `fullcombo` | 0 misses hasta el momento |
| `1hp` | Energia <= 1 |
| `halfhp` | Energia <= max_energy / 2 |
| `losthp` | Energia != max_energy |
| `normal` | Estado por defecto |

### Posiciones disponibles

| Posicion | Constante |
|----------|-----------|
| Inferior derecha | `FRIEND_LOWER_RIGHT` (por defecto) |
| Inferior izquierda | `FRIEND_LOWER_LEFT` |
| Superior izquierda | `FRIEND_UPPER_LEFT` |
| Superior derecha | `FRIEND_UPPER_RIGHT` |
| Llenar grilla | `FRIEND_FILL_GRID` (3x3, alpha 0.1) |
| Detras de grilla | `FRIEND_BEHIND_GRID` (1x1, alpha 0.1) |

---

## FaceNote.gd

**Ruta:** `scripts/game/FaceNote.gd`
**Extiende:** `MeshInstance`

### Proposito

Permite que ciertos elementos visuales (como las notas del avatar) roten para mirar hacia la posicion del cursor del jugador. Usa `look_at()` para orientar el MeshInstance hacia el cursor, con multiplicadores configurables:

- `look_multi`: Multiplica la posicion del objetivo (controla la intensidad del efecto)
- `speed_multi`: Multiplica la velocidad de interpolacion hacia el cursor

Solo se activa cuando el nodo `Spawn/Cursor` existe y `enabled` es `true`.

---

## Sistema de puntaje

El puntaje se calcula en `Game.get_point_amt()` con la siguiente formula:

```
puntos = floor((50 * spd * min(hbo, hwi) * mod) + 0.5) * combo_level
```

### Componentes

#### Factor de velocidad (`spd`)

```gdscript
spd = clamp(((speed_multi - 1) * 1.5) + 1, 0, 1.9)
```

- A velocidad 1.0x: `spd = 1.0`
- A velocidad 0.5x: `spd = 0.25`
- A velocidad 1.5x: `spd = 1.75`
- Maximo: 1.9

#### Factor de hitbox (`hbo`)

```gdscript
hitbox_diff = note_hitbox_size - 1.140
hbo = clamp(linstep(1.140, 0, hitbox_diff), 0, 1)
```

- Hitbox por defecto (1.140): `hbo = 1.0`
- Hitbox mayor: `hbo` disminuye
- Hitbox de 0: `hbo = 1.0`

#### Factor de hit window (`hwi`)

```gdscript
hitwin_diff = note_hitbox_size - 55
hwi = clamp(linstep(55, 0, hitwin_diff), 0, 1)
```

Penaliza hitboxes mas grandes que el valor por defecto.

#### Multiplicador de combo (`combo_level`)

El resultado final se multiplica por el nivel de combo actual (1 a 8).

### Ejemplo de calculo

Con velocidad 1.0x, hitbox default, combo nivel 4:
```
puntos = floor((50 * 1.0 * 1.0 * 1) + 0.5) * 4 = 200 puntos por hit
```

Con velocidad 1.5x, hitbox default, combo nivel 8:
```
puntos = floor((50 * 1.75 * 1.0 * 1) + 0.5) * 8 = 700 puntos por hit
```

---

## Sistema de energia

La energia funciona como la "vida" del jugador. Cuando llega a 0, la cancion falla (a menos que se use nofail).

### Modelos de energia

Se configura en `Game._ready()` segun `Rhythia.health_model`:

| Modelo | Constante | max_energy | Con Extra Energy | energy_per_hit |
|--------|-----------|------------|------------------|----------------|
| SoundSpace | `HP_SOUNDSPACE` | 5 | 8 | 0.5 |
| Old | `HP_OLD` | 6 | 10 | 1.0 |
| Sudden Death | `mod_sudden_death` | 1 | - | - |

### Reglas de energia

- **Hit**: `energy = clamp(energy + energy_per_hit, 0, max_energy)` (si no tiene `mod_no_regen`)
- **Miss**: `energy = clamp(energy - 1, 0, max_energy)`
- **Energia = 0 con nofail**: Marca `song_has_failed = true`, reproduce sonido de fallo, pero la cancion continua
- **Energia = 0 sin nofail**: `end(END_FAIL)` inmediato
- **Sudden Death**: `max_energy = 1`, por lo tanto 1 miss = game over

### Modificadores relacionados

| Modificador | Efecto |
|-------------|--------|
| `mod_extra_energy` | Aumenta max_energy (SoundSpace: 5->8, Old: 6->10) |
| `mod_no_regen` | Los hits no regeneran energia |
| `mod_sudden_death` | max_energy = 1 |
| `mod_nofail` | El juego no puede terminar por falta de energia |

---

## Sistema de combo

El combo representa la racha de hits consecutivos del jugador e influye directamente en el multiplicador de puntaje.

### Niveles de combo

El sistema tiene 8 niveles. Cada nivel requiere 10 hits consecutivos para avanzar al siguiente:

| Nivel | Multiplicador | Hits necesarios para llegar |
|-------|---------------|-----------------------------|
| 1 | 1x | (inicial) |
| 2 | 2x | 10 hits |
| 3 | 3x | 20 hits |
| 4 | 4x | 30 hits |
| 5 | 5x | 40 hits |
| 6 | 6x | 50 hits |
| 7 | 7x | 60 hits |
| 8 | 8x | 70 hits (maximo) |

### Comportamiento al hacer hit

```gdscript
combo += 1
if combo_level != 8:
    lvl_progress += 1
if combo_level != 8 and lvl_progress == 10:
    lvl_progress = 0
    combo_level += 1
    if combo_level == 8: lvl_progress = 10  # marca como completo
```

### Comportamiento al hacer miss

```gdscript
combo = 0
lvl_progress = 0
if combo_level != 1:
    combo_level -= 1  # baja un nivel (no resetea a 1)
```

### Nota importante sobre miss

Un miss **no** resetea el `combo_level` a 1 directamente. Solo lo reduce en 1. Esto significa que un jugador en nivel 8 que falla una nota baja a nivel 7, no a nivel 1.

### Comportamiento al pausar

Al pausar el juego, el `combo_level` se resetea a 1 y `lvl_progress` a 0.

---

## Modificadores

Los modificadores alteran la experiencia de juego de diversas maneras. Se activan desde la configuracion antes de comenzar una cancion.

### Modificadores de dificultad

#### Chaos

- **Variable:** `Rhythia.mod_chaos`
- **Efecto:** Las notas se desplazan de su posicion original con un offset aleatorio creciente
- **Calculo:**
  ```gdscript
  v = ease(max((current_offset_ms - 250) / 400, 0), 1.5)
  origin.x = real_position.x + (chaos_offset.x * v)
  origin.y = real_position.y + (chaos_offset.y * v)
  ```
- El offset se genera al crear la nota con un vector normalizado aleatorio multiplicado por 2
- Las notas comienzan a desviarse 250ms antes de llegar al jugador

#### Earthquake

- **Variable:** `Rhythia.mod_earthquake`
- **Efecto:** Las notas tienen un jitter aleatorio basado en su distancia
- **Calculo:**
  ```gdscript
  rcoord = Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
  origin.x = real_position.x + (rcoord.x * (current_dist * 0.1))
  origin.y = real_position.y + (rcoord.y * (current_dist * 0.1))
  ```
- El efecto es mas pronunciado para notas mas lejanas

#### Ghost

- **Variable:** `Rhythia.mod_ghost`
- **Efecto:** Las notas se desvanecen antes de llegar al jugador
- **Configuracion:**
  ```gdscript
  fade_out_start = (18.0 / 50) * approach_rate
  fade_out_end = (6.0 / 50.0) * approach_rate
  ```
- Tambien existe `half_ghost` con valores menos agresivos:
  ```gdscript
  fade_out_start = (12.0 / 50) * approach_rate
  fade_out_end = (3.0 / 50.0) * approach_rate
  fade_out_base = 0.8  # no desaparece completamente
  ```

#### Nearsighted

- **Variable:** `Rhythia.mod_nearsighted`
- **Efecto:** Las notas aparecen (fade in) mucho mas tarde de lo normal
- **Configuracion:**
  ```gdscript
  fade_in_start = (30.0 / 50.0) * approach_rate
  fade_in_end = (5.0 / 50.0) * approach_rate
  ```

#### Hard Rock

- **Variable:** `Rhythia.mod_hardrock`
- **Efectos multiples:**
  1. Escala las posiciones de las notas por 1.35x desde el centro de la grilla:
     ```gdscript
     note[0] = ((note[0] - Vector2(1, -1)) * 1.35) + Vector2(1, -1)
     ```
  2. Reduce la hit window al 80%:
     ```gdscript
     hit_window = hit_window * 0.8
     ```
  3. Expande los limites del cursor (edge clamp reducido)
  4. Opcionalmente expande el HUD y la grilla visual (1.35x)

#### Flashlight

- **Variable:** `Rhythia.mod_flashlight`
- **Efecto:** Oscurece toda la pantalla excepto alrededor del cursor
- **Detalles:** Implementado por `FlashlightModifier.gd` (ver seccion dedicada)

### Modificadores de espejo

#### Mirror X

- **Variable:** `Rhythia.mod_mirror_x`
- **Efecto:** Invierte las posiciones de las notas horizontalmente
  ```gdscript
  note[0].x = 2 - note[0].x
  ```

#### Mirror Y

- **Variable:** `Rhythia.mod_mirror_y`
- **Efecto:** Invierte las posiciones de las notas verticalmente
  ```gdscript
  note[0].y = (-note[0].y) - 2
  ```

### Modificadores de salud

| Modificador | Variable | Efecto |
|-------------|----------|--------|
| Nofail | `mod_nofail` | No puede fallar por energia = 0 |
| Sudden Death | `mod_sudden_death` | max_energy = 1, un miss = fallo |
| Extra Energy | `mod_extra_energy` | Aumenta la energia maxima |
| No Regen | `mod_no_regen` | Los hits no regeneran energia |

### Modificadores de velocidad

Se controlan con `Rhythia.mod_speed_level` y varian el `speed_multi`:

| Nivel | Constante | Descripcion |
|-------|-----------|-------------|
| --- | `SPEED_MMM` | Velocidad muy lenta |
| -- | `SPEED_MM` | Velocidad lenta |
| - | `SPEED_M` | Velocidad ligeramente lenta |
| Normal | `SPEED_NORMAL` | Velocidad 1.0x |
| + | `SPEED_P` | Velocidad ligeramente rapida |
| ++ | `SPEED_PP` | Velocidad rapida |
| +++ | `SPEED_PPP` | Velocidad muy rapida |
| ++++ | `SPEED_PPPP` | Velocidad extrema |
| Custom | `SPEED_CUSTOM` | Velocidad personalizada |

- Si `Rhythia.speed_hitwindow` esta activo: `hit_window *= speed_multi`
- Si no: la hit window permanece igual (se muestra icono de advertencia "Window")
- Si `Rhythia.retain_song_pitch` esta activo: se aplica un `AudioEffectPitchShift` inverso para mantener el tono original

### Modificadores visuales

| Modificador | Variable | Efecto |
|-------------|----------|--------|
| Invert Mouse | `invert_mouse` | Invierte la direccion del mouse |
| Visual Mode | `visual_mode` | Todas las notas se registran como hit automaticamente |
