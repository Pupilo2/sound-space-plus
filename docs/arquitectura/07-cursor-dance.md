# 07 - Sistema de Cursor Dance

> Documentacion de arquitectura para **Sound Space Plus (Rhythia)** - Motor: Godot 3.x

---

## Indice

1. [Vision general](#vision-general)
2. [Tabla de scripts](#tabla-de-scripts)
3. [Dance.gd (Autoload)](#dancegd-autoload)
   - [Funciones de easing disponibles](#funciones-de-easing-disponibles)
4. [DanceMover.gd (Clase base)](#dancemovergd-clase-base)
5. [Movers disponibles](#movers-disponibles)
   - [Simple.gd (SimpleDanceMover)](#simpleGD-simpledancemover)
   - [Bouncy.gd (BouncyDanceMover)](#bouncygd-bouncydancemover)
   - [Directional.gd (DirectionalDanceMover)](#directionalgd-directionaldancemover)
   - [Momentum.gd (MomentumDanceMover)](#momentumgd-momentumdancemover)
6. [Cursor.gd (Visualizacion)](#cursorgd-visualizacion)
7. [Main.gd (Controlador de grilla)](#maingd-controlador-de-grilla)
8. [dancetest.gd (Escena de prueba)](#dancetestgd-escena-de-prueba)
9. [Stop.gd (Boton de salida)](#stopgd-boton-de-salida)
10. [Jerarquia de clases](#jerarquia-de-clases)
11. [Flujo de ejecucion de un mover](#flujo-de-ejecucion-de-un-mover)
12. [Comparacion de estilos de movimiento](#comparacion-de-estilos-de-movimiento)
13. [Integracion con el juego](#integracion-con-el-juego)

---

## Vision general

El sistema de **Cursor Dance** permite que el cursor se mueva automaticamente entre notas con diferentes estilos de animacion. Su proposito principal es proporcionar la funcionalidad de **autoplay** (modo automatico), donde el cursor recorre todas las notas de una cancion sin intervencion del jugador, y tambien sirve como herramienta de visualizacion/prueba para los mapas.

El sistema se compone de:

- **`Dance`** - Un **Autoload** global (`Node`) que actua como biblioteca de funciones de easing (interpolacion).
- **`DanceMover`** - Una clase base (`Resource`) que define la interfaz comun para todos los estilos de movimiento.
- **Movers concretos** - Cuatro implementaciones (`Simple`, `Bouncy`, `Directional`, `Momentum`) que calculan la posicion del cursor en cada instante.
- **Escena de prueba** - `dancetest.tscn` con su controlador `dancetest.gd` para previsualizar el comportamiento del cursor dance.
- **Grilla visual** - `Main.gd` que dibuja la grilla de juego y las notas dentro de la escena de prueba.
- **Cursor visual** - `Cursor.gd` que renderiza el cursor en la grilla.

El sistema trabaja con el tiempo en **milisegundos (ms)** y las posiciones de notas como **Vector3** donde `x` e `y` son las coordenadas en la grilla (rango 0-2) y `z` es el timestamp en milisegundos.

---

## Tabla de scripts

| Archivo | Ruta | Clase base | class_name | Proposito |
|---------|------|------------|------------|-----------|
| `Dance.gd` | `scripts/cursordance/Dance.gd` | `Node` | *(Autoload)* | Biblioteca global de funciones de easing |
| `DanceMover.gd` | `scripts/cursordance/DanceMover.gd` | `Resource` | `DanceMover` | Clase base abstracta para movers |
| `Simple.gd` | `scripts/cursordance/Simple.gd` | `DanceMover` | `SimpleDanceMover` | Movimiento lineal con easing InBack |
| `Bouncy.gd` | `scripts/cursordance/Bouncy.gd` | `DanceMover` | `BouncyDanceMover` | Movimiento con curvas Bezier suaves |
| `Directional.gd` | `scripts/cursordance/Directional.gd` | `DanceMover` | `DirectionalDanceMover` | Movimiento Bezier con sesgo direccional |
| `Momentum.gd` | `scripts/cursordance/Momentum.gd` | `DanceMover` | `MomentumDanceMover` | Movimiento con inercia cubica Bezier |
| `Cursor.gd` | `scripts/cursordance/Cursor.gd` | `Node2D` | - | Representacion visual del cursor |
| `Main.gd` | `scripts/cursordance/Main.gd` | `Panel` | - | Grilla visual y renderizado de notas |
| `dancetest.gd` | `scripts/cursordance/dancetest.gd` | `Control` | - | Controlador de la escena de prueba |
| `Stop.gd` | `scripts/cursordance/Stop.gd` | `Button` | - | Boton para cerrar la aplicacion |

---

## Dance.gd (Autoload)

- **Extiende**: `Node`
- **Archivo**: `scripts/cursordance/Dance.gd`
- **Autoload**: Registrado como `Dance` en `project.godot` (linea: `Dance="*res://scripts/cursordance/Dance.gd"`)
- **Proposito**: Biblioteca global de funciones de easing (interpolacion) accesible desde cualquier script del proyecto.

`Dance.gd` **no gestiona movers ni orquesta movimiento**. Es exclusivamente un contenedor de funciones matematicas de easing que reciben un parametro `t` (progreso normalizado de `0.0` a `1.0`) y devuelven un `float` transformado segun la curva correspondiente.

Al ser un Autoload, cualquier script puede llamar `Dance.NombreFuncion(t)` sin necesidad de instanciarlo. Se usa tanto dentro del sistema de Cursor Dance como fuera de el (por ejemplo, `WarningBar.gd` en la UI del menu usa `Dance.InOutSine()`).

### Funciones de easing disponibles

Todas las funciones tienen la firma `func NombreFuncion(t: float) -> float` donde `t` esta en el rango `[0.0, 1.0]`.

| Familia | In | Out | InOut |
|---------|-----|------|-------|
| **Linear** | `Linear(t)` | - | - |
| **Quad** (cuadratica) | `InQuad(t)` | `OutQuad(t)` | `InOutQuad(t)` |
| **Cubic** (cubica) | `InCubic(t)` | `OutCubic(t)` | `InOutCubic(t)` |
| **Quart** (cuarta potencia) | `InQuart(t)` | `OutQuart(t)` | `InOutQuart(t)` |
| **Quint** (quinta potencia) | `InQuint(t)` | `OutQuint(t)` | `InOutQuint(t)` |
| **Sine** (sinusoidal) | `InSine(t)` | `OutSine(t)` | `InOutSine(t)` |
| **Expo** (exponencial) | `InExpo(t)` | `OutExpo(t)` | `InOutExpo(t)` |
| **Circ** (circular) | `InCirc(t)` | `OutCirc(t)` | `InOutCirc(t)` |
| **Back** (retroceso) | `InBack(t)` | `OutBack(t)` | `InOutBack(t)` |
| **Bounce** (rebote) | `InBounce(t)` | `OutBounce(t)` | `InOutBounce(t)` |
| **Square** (escalonada) | `InSquare(t)` | `OutSquare(t)` | `InOutSquare(t)` |

En total: **31 funciones de easing**.

**Significado de las variantes:**

- **In** - La curva comienza lenta y acelera hacia el final.
- **Out** - La curva comienza rapida y desacelera hacia el final.
- **InOut** - La curva comienza lenta, acelera en el medio y desacelera al final.

---

## DanceMover.gd (Clase base)

- **Extiende**: `Resource`
- **class_name**: `DanceMover`
- **Archivo**: `scripts/cursordance/DanceMover.gd`
- **Proposito**: Clase base abstracta que define la interfaz para todos los estilos de movimiento del cursor.

### Codigo completo

```gdscript
extends Resource
class_name DanceMover

func update(ms:float) -> Vector2:
    return call("_update", ms)
```

### Interfaz

| Metodo | Parametros | Retorno | Descripcion |
|--------|------------|---------|-------------|
| `update(ms)` | `ms: float` - tiempo actual en milisegundos | `Vector2` | Metodo publico que delega a `_update()` via `call()` |
| `_update(ms)` | `ms: float` | `Vector2` | **Metodo virtual** - debe ser implementado por cada subclase |

El metodo `update()` usa `call("_update", ms)` para invocar dinamicamente la implementacion concreta de `_update()` en la subclase correspondiente. Este patron permite polimorfismo en GDScript sobre Resources.

### Contrato para subclases

Cada mover concreto **debe** implementar:

```gdscript
func _update(ms: float) -> Vector2:
    # Calcular y retornar la posicion del cursor en el instante ms
    # Las coordenadas estan en el espacio de grilla (0-2 en cada eje)
```

### Variables compartidas

Todos los movers concretos comparten un conjunto comun de variables (definidas individualmente en cada uno, no heredadas):

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `notes` | `PoolVector3Array` | Array de notas del mapa (x, y, timestamp_ms) |
| `noteNum` | `int` | Indice de la nota actual (inicializado en `1`) |
| `Start` | `Vector3` | Nota actual (origen del movimiento) |
| `End` | `Vector3` | Siguiente nota (destino del movimiento) |
| `StartPos` | `Vector2` | Posicion 2D de la nota actual |
| `EndPos` | `Vector2` | Posicion 2D de la siguiente nota |
| `StartTime` | `float` | Timestamp de la nota actual |
| `EndTime` | `float` | Timestamp de la siguiente nota |
| `Duration` | `float` | Duracion entre las dos notas (`EndTime - StartTime`) |
| `t` | variante | Progreso normalizado `[0, 1]` entre las dos notas |
| `p1`, `p2` | `Vector2` | Puntos de control (usados en movers con Bezier) |
| `last` | `Vector2` | Ultima posicion conocida |
| `jmult` | `float` | Multiplicador de salto (valor: `1`) |
| `nmult` | `float` | Multiplicador de nota (valor: `1`) |
| `offsetMult` | `float` | Multiplicador de offset angular (valor: `1`) |
| `skipstacks` | `bool` | Si se saltan notas apiladas (valor: `true`) |

---

## Movers disponibles

### Simple.gd (SimpleDanceMover)

- **Extiende**: `DanceMover`
- **class_name**: `SimpleDanceMover`
- **Archivo**: `scripts/cursordance/Simple.gd`
- **Proposito**: El mover mas basico. Interpola linealmente entre notas consecutivas con una funcion de easing aplicada.

#### Inicializacion

```gdscript
func _init(song: Song):
    for n in song.read_notes():
        notes.append(Vector3(n[0], n[1], n[2]))
```

Lee todas las notas de la cancion y las almacena como `Vector3(x, y, ms)`. **No aplica filtrado de stacks** ni modificadores de espejo.

#### Algoritmo de movimiento

1. **Busqueda de nota actual**: Itera sobre `notes` para encontrar el par de notas entre las que se encuentra el tiempo actual `ms`.
2. **Calculo de progreso**: `t = clamp((ms - Start.z) / (End.z - Start.z), 0, 1)`
3. **Interpolacion**: `lerp(StartPos, EndPos, Dance.InBack(t))`

El uso de `Dance.InBack(t)` produce un leve retroceso al inicio del movimiento antes de avanzar hacia el destino, dando una sensacion de "impulso".

#### Metodos auxiliares

| Metodo | Descripcion |
|--------|-------------|
| `same(o1, o2)` | Compara igualdad de dos `Vector2` |
| `same3(o1, o2)` | Compara igualdad de dos `Vector3` (solo componentes x, y) |
| `v2(v)` | Convierte `Vector3` a `Vector2` (descarta `.z`) |
| `T(time)` | Calcula progreso normalizado relativo a `StartTime` y `Duration` |

#### Caracteristicas

- **Trayectoria**: Recta entre notas.
- **Easing**: `InBack` - retrocede ligeramente antes de avanzar.
- **Complejidad**: Baja. No usa curvas Bezier.
- **Filtrado de stacks**: No.
- **Soporte de mirror**: No.

---

### Bouncy.gd (BouncyDanceMover)

- **Extiende**: `DanceMover`
- **class_name**: `BouncyDanceMover`
- **Archivo**: `scripts/cursordance/Bouncy.gd`
- **Proposito**: Mover con curvas Bezier cuadraticas que genera trayectorias suaves y curvas entre notas. Es el mover **usado por defecto en el autoplay** del sistema de replays.

#### Inicializacion

```gdscript
func _init(song: Song):
    for n in song.read_notes():
        var note = Vector3(n[0], n[1], n[2])
        # Fusion de stacks: notas separadas por menos de 10ms se promedian
        if notes.size() != 0:
            if (note.z - notes[notes.size()-1].z) < 10:
                var new = (note + notes[notes.size()-1]) / 2
                notes[notes.size()-1] = Vector3(new.x, new.y, notes[notes.size()-1].z)
            else:
                if Rhythia.mod_mirror_x: note.x = 2 - note.x
                if Rhythia.mod_mirror_y: note.y = 2 - note.y
                notes.append(note)
        else:
            if Rhythia.mod_mirror_x: note.x = 2 - note.x
            if Rhythia.mod_mirror_y: note.y = 2 - note.y
            notes.append(note)
```

**Diferencias clave respecto a Simple:**

- Fusiona notas que estan a menos de **10ms** de distancia (stacks) promediando sus posiciones.
- Aplica los modificadores de espejo (`Rhythia.mod_mirror_x`, `Rhythia.mod_mirror_y`).

#### Funcion Bezier

```gdscript
func bezier(t, p0, p1, p2, p3) -> Vector2:
    var res = (pow(1-t,2) * p0) + (2 * (1-t) * t * p1) + (pow(t,2) * p2)
    var final = lerp(
        lerp(p0, p2, t),
        res,
        clamp(smoothstep(25, 300,
            (Duration / Globals.speed_multi[Rhythia.mod_speed_level]) * StartPos.distance_to(EndPos)
        ), 0, 1)
    )
    return Vector2(clamp(final.x, -0.5, 2.5), clamp(final.y, -0.5, 2.5))
```

La curva Bezier se mezcla (blend) con una interpolacion lineal segun un factor que depende de:

- **Duration**: Tiempo entre notas (ajustado por velocidad del mod).
- **Distancia**: Distancia espacial entre las notas.

Cuando el producto `(Duration / speed) * distancia` es pequeno (< 25), se usa mas la linea recta. Cuando es grande (> 300), se usa mas la curva. Esto hace que notas cercanas se conecten con lineas rectas y notas lejanas con curvas pronunciadas.

Las coordenadas del resultado se restringen al rango `[-0.5, 2.5]` para evitar que el cursor salga demasiado del area de juego.

#### Algoritmo de movimiento

1. **Busqueda de nota actual**: Igual que en Simple.
2. **Calculo de puntos de control**:
   - `p0` = posicion de la nota actual
   - `p1` = punto de control basado en la direccion desde la nota anterior (`dirR`)
   - `p2` = punto de control basado en la direccion hacia la nota siguiente a la destino
   - `p3` = posicion de la nota destino
3. **Mezcla con momentum**: Los puntos `p1` y `p2` se interpolan con un factor `m1`/`m2` calculado como `0.75 * distancia_entre_notas / 1000`.
4. **Resultado**: `bezier(Dance.Linear(t), p0, p1, p3, p2)` - interpolacion con progreso lineal en la curva.
5. **Prebuffereo de la curva**: Se precalculan 11 puntos de la curva usando `Dance.OutExpo` para visualizacion debug en `bez[]`.

#### Metodos auxiliares adicionales

| Metodo | Descripcion |
|--------|-------------|
| `np(note)` | Obtiene posicion `Vector2` de una nota por indice (con clamp) |
| `ti(note)` | Obtiene timestamp de una nota por indice (con clamp) |
| `n(note)` | Obtiene `Vector3` completo de una nota por indice (con clamp) |
| `dir(p0, p1)` | Calcula direccion inversa: `p1 - (p1 - p0)` = `p0` |
| `dirR(p0, p1)` | Calcula direccion reflejada: `p1 + (p1 - p0)` |

#### Caracteristicas

- **Trayectoria**: Curva Bezier cuadratica con blend adaptativo.
- **Easing**: Progreso lineal sobre la curva, `OutExpo` para el prebuffereo visual.
- **Complejidad**: Media-alta. Curvas Bezier con smoothstep adaptativo.
- **Filtrado de stacks**: Si (< 10ms se fusionan).
- **Soporte de mirror**: Si (`Rhythia.mod_mirror_x/y`).
- **Clamping**: Coordenadas restringidas a `[-0.5, 2.5]`.
- **Smoothstep**: Rango `[25, 300]` para el factor de mezcla curva/lineal.

---

### Directional.gd (DirectionalDanceMover)

- **Extiende**: `DanceMover`
- **class_name**: `DirectionalDanceMover`
- **Archivo**: `scripts/cursordance/Directional.gd`
- **Proposito**: Similar a Bouncy pero con un sesgo direccional diferente. Genera curvas mas agresivas y con un factor de suavizado distinto.

#### Diferencias respecto a Bouncy

Directional comparte la misma estructura y logica que Bouncy con las siguientes diferencias:

| Aspecto | Bouncy | Directional |
|---------|--------|-------------|
| Factor momentum (`m1`/`m2`) | `0.75 * distancia / 1000` | `0.6 * distancia / 1000` |
| Smoothstep rango minimo | `25` | `15` |
| Smoothstep rango maximo | `300` | `165` |
| Prebuffereo visual (`bez[]`) | `Dance.OutExpo` | `Dance.OutBack` |
| Soporte mirror | Si | No |

**Efecto de las diferencias:**

- El factor de momentum mas bajo (`0.6` vs `0.75`) produce puntos de control mas cercanos a las notas, resultando en curvas menos pronunciadas.
- El rango de smoothstep mas ajustado (`[15, 165]` vs `[25, 300]`) hace que la transicion de lineal a curva ocurra antes y a distancias/tiempos mas cortos. Esto genera curvas mas frecuentes.
- `Dance.OutBack` para el prebuffereo produce una ligera sobreexposicion (overshoot) en la visualizacion debug.

#### Caracteristicas

- **Trayectoria**: Curva Bezier cuadratica con blend adaptativo mas agresivo.
- **Easing**: Progreso lineal sobre la curva, `OutBack` para prebuffereo visual.
- **Complejidad**: Media-alta.
- **Filtrado de stacks**: Si (< 10ms).
- **Soporte de mirror**: No.
- **Clamping**: Coordenadas restringidas a `[-0.5, 2.5]`.
- **Smoothstep**: Rango `[15, 165]`.

---

### Momentum.gd (MomentumDanceMover)

- **Extiende**: `DanceMover`
- **class_name**: `MomentumDanceMover`
- **Archivo**: `scripts/cursordance/Momentum.gd`
- **Proposito**: Mover basado en curvas Bezier cubicas verdaderas con calculo de angulos y direcciones. Simula inercia/momento fisico en el movimiento del cursor.

#### Funciones matematicas exclusivas

```gdscript
func AngleRV(v1, v2) -> float:
    return atan2(v1.y - v2.y, v1.x - v2.x)

func V2FromRad(rad, radius) -> Vector2:
    return Vector2(cos(rad) * radius, sin(rad) * radius)

func AngleBetween(centre, v1, v2) -> float:
    var a = centre.distance_to(v1)
    var b = centre.distance_to(v2)
    var c = v1.distance_to(v2)
    return acos((a*a + b*b - c*c) / (2*a*b))
```

| Funcion | Descripcion |
|---------|-------------|
| `AngleRV(v1, v2)` | Angulo en radianes de `v2` a `v1` |
| `V2FromRad(rad, radius)` | Convierte coordenadas polares a cartesianas |
| `AngleBetween(centre, v1, v2)` | Angulo entre dos puntos respecto a un centro (ley de cosenos) |

#### Metodo onObjChange

Se ejecuta en cada frame para calcular los puntos de control de la curva Bezier cubica:

1. Calcula la distancia entre `StartPos` y `EndPos`.
2. Determina el angulo de salida (`a1`) basandose en la posicion anterior (`last`).
3. Determina el angulo de entrada (`a2`) basandose en la siguiente nota.
4. Genera `p1` y `p2` como puntos de control usando `V2FromRad()` con los angulos y la distancia escalada por `jmult`/`nmult`.
5. Aplica un offset angular (`offset = PI * offsetMult`) si los angulos estan demasiado alineados.

#### Algoritmo de movimiento (Bezier cubica)

La interpolacion es una **curva Bezier cubica manual** calculada componente a componente:

```gdscript
r = 1 - t
return Vector2(
    r*r*r * StartX + r*r*t * p1.x * 3 + r*t*t * p2.x * 3 + t*t*t * EndX,
    r*r*r * StartY + r*r*t * p1.y * 3 + r*t*t * p2.y * 3 + t*t*t * EndY
)
```

Esta es la formula clasica de Bezier cubica: `B(t) = (1-t)^3*P0 + 3*(1-t)^2*t*P1 + 3*(1-t)*t^2*P2 + t^3*P3`.

**Nota**: El mover usa `StartX`/`StartY`/`EndX`/`EndY` en lugar de `StartPos`/`EndPos` en el calculo final, pero estas variables **no se actualizan** en el metodo `_update()`. Esto significa que la posicion inicial y final de la curva cubica pueden no coincidir con las notas reales si `StartX/Y` y `EndX/Y` no se asignan externamente. Este comportamiento puede producir trayectorias inesperadas.

#### Navegacion de notas

A diferencia de los otros movers, Momentum usa `notes.size() - 2` como limite del rango, y busca notas cuyo *siguiente* (`notes[i+1]`) tenga un timestamp mayor que `ms`, asignando `notes[i]` como Start y `notes[i+1]` como End.

#### Funcion nextAngle

```gdscript
func nextAngle() -> float:
    for i in range(noteNum, notes.size() - 2):
        var o = notes[i]
        if (!same3(o, notes[i + 1])):
            return v2(o).angle_to_point(v2(notes[i + 1]))
    return (StartPos.angle_to_point(last) + PI)
```

Busca el angulo hacia la siguiente nota que no sea identica en posicion a la actual. Si no encuentra ninguna, usa el angulo inverso desde la ultima posicion conocida.

#### Caracteristicas

- **Trayectoria**: Curva Bezier cubica verdadera (4 puntos de control).
- **Easing**: No usa funciones de Dance. El progreso `t` se aplica directamente a la formula cubica.
- **Complejidad**: Alta. Calculos trigonometricos y de angulos.
- **Filtrado de stacks**: No (pero `nextAngle()` salta notas con la misma posicion).
- **Soporte de mirror**: No.
- **Clamping**: No. Las coordenadas pueden salir del area de juego.
- **Inercia**: Los puntos de control dependen de la posicion anterior (`last`), creando continuidad de direccion.

---

## Cursor.gd (Visualizacion)

- **Extiende**: `Node2D`
- **Archivo**: `scripts/cursordance/Cursor.gd`
- **Proposito**: Representacion visual del cursor en la escena de prueba del cursor dance.

### Comportamiento

```gdscript
func _ready():
    var img = Globals.imageLoader.load_if_exists("user://cursor")
    if img: $TextureRect.texture = img

func _draw():
    if position.length() > 500:
        draw_line(-position, Vector2(0,0), Color(1,0,0), 2, true)

func _process(delta):
    update()
```

| Aspecto | Descripcion |
|---------|-------------|
| **Textura** | Carga una imagen personalizada del usuario desde `user://cursor` si existe |
| **Linea de aviso** | Si el cursor esta a mas de 500 unidades del origen, dibuja una linea roja de vuelta al centro |
| **Actualizacion** | Llama a `update()` cada frame para redibujar |
| **Nodo hijo** | Contiene un `TextureRect` para mostrar la imagen del cursor |
| **Font exportada** | Tiene una variable `font` exportada (tipo `Font`), no utilizada en el codigo actual |

---

## Main.gd (Controlador de grilla)

- **Extiende**: `Panel`
- **Archivo**: `scripts/cursordance/Main.gd`
- **Proposito**: Dibuja la grilla de juego 2x2, renderiza las notas que se aproximan y reproduce sonidos de hit. Funciona como la visualizacion del campo de juego dentro de la escena de prueba.

### Variables principales

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `notes` | `PoolVector3Array` | Notas del mapa cargadas |
| `noten` | `int` | Indice de la nota actual para renderizado |
| `colors` | `Array` | Colores del colorset seleccionado por el jugador |
| `active` | `bool` | Si la grilla esta activa (dibujando y procesando) |
| `flash_time` | `float` | Tiempo restante de un efecto de flash en el borde |

### Metodo setup

```gdscript
func setup(song: Song):
    $Hit.stream = Rhythia.hit_snd
    for n in song.read_notes():
        notes.append(Vector3(n[0], n[1], n[2]))
```

Carga el sonido de hit y todas las notas del mapa.

### Renderizado (_draw)

El metodo `_draw()` dibuja:

1. **Grilla**: Lineas grises que dividen el area de 300x300 pixeles en una grilla 3x3.
2. **Borde**: Rectangulo de borde con un efecto flash (color rojo que se desvanece).
3. **Notas visibles**: Para cada nota dentro del rango temporal visible (`approach_rate`):
   - Rectangulo de aproximacion que se encoge segun la distancia temporal.
   - Rectangulo de borde coloreado segun el colorset.
   - Rectangulo relleno con transparencia.
   - La opacidad y tamano se calculan usando `Dance.InQuint(m)` donde `m` es el progreso de aproximacion.

### Nota temporal (nt)

```gdscript
var nt = 1000.0 * Globals.speed_multi[Rhythia.mod_speed_level]
```

El rango temporal visible se ajusta segun el nivel de velocidad del juego.

### Sonido de hit

Cuando una nota "llega" (offset <= 0), reproduce `$Hit` y avanza el indice `noten`.

---

## dancetest.gd (Escena de prueba)

- **Extiende**: `Control`
- **Archivo**: `scripts/cursordance/dancetest.gd`
- **Proposito**: Controlador principal de la escena de prueba `dancetest.tscn`. Permite reproducir una cancion y ver como el cursor dance se mueve entre las notas.

### Variables principales

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| `song` | `Song` | Cancion seleccionada (`Rhythia.selected_song`) |
| `dance` | `DanceMover` | Mover activo (por defecto `DirectionalDanceMover`) |
| `ms` | `float` | Tiempo actual de reproduccion en milisegundos (inicia en `-1000`) |
| `active` | `bool` | Si la reproduccion esta en curso |

### Flujo de vida

1. **`_ready()`**: Configura el stream de audio, la barra de tiempo, inicializa `Main`, crea un `DirectionalDanceMover` con la cancion, y espera a que el usuario pulse Start.
2. **`_process(delta)`**: Si esta activo, avanza `ms` segun delta y velocidad, actualiza el cursor, sincroniza el audio, y actualiza la barra de tiempo.
3. **`update_cursor()`**: Llama a `dance.update(ms)` y posiciona el cursor en la grilla. Tambien actualiza un label de debug con todas las variables internas del mover.

### Sincronizacion de audio

La escena implementa correccion de desincronizacion:

```gdscript
if abs(playback_pos - (ms + Rhythia.music_offset)) > 85:
    $Main/Music.play((ms + Rhythia.music_offset) / 1000.0)
```

Si el audio se desvia mas de 85ms del tiempo interno, se reposiciona automaticamente y opcionalmente muestra una alerta.

### Controles

- **Start/Stop**: Inician o detienen la reproduccion.
- **Seek**: Permite saltar a un tiempo especifico en milisegundos.
- **Barra de tiempo**: Slider para navegar por la cancion (solo editable cuando esta pausado).

---

## Stop.gd (Boton de salida)

- **Extiende**: `Button`
- **Archivo**: `scripts/cursordance/Stop.gd`
- **Proposito**: Boton simple que cierra la aplicacion con `get_tree().quit()`.

---

## Jerarquia de clases

```
Resource
  |
  +-- DanceMover                        (clase base abstracta)
        |
        +-- SimpleDanceMover            (movimiento lineal + InBack)
        |
        +-- BouncyDanceMover            (Bezier cuadratica adaptativa)
        |
        +-- DirectionalDanceMover       (Bezier cuadratica direccional)
        |
        +-- MomentumDanceMover          (Bezier cubica con inercia)


Node (Autoload)
  |
  +-- Dance                             (biblioteca de funciones de easing)


Node2D
  |
  +-- Cursor                            (visual del cursor en la grilla)


Panel
  |
  +-- Main                              (grilla + renderizado de notas)


Control
  |
  +-- dancetest                         (controlador de escena de prueba)
```

---

## Flujo de ejecucion de un mover

```
                      +---------------------------+
                      |   Seleccion del mapa       |
                      |   (Song seleccionada)       |
                      +-------------+-------------+
                                    |
                                    v
                      +---------------------------+
                      |  Instanciar DanceMover     |
                      |  MoverConcreto.new(song)   |
                      +-------------+-------------+
                                    |
                                    v
                      +---------------------------+
                      |  _init(song):              |
                      |  - Leer notas del mapa     |
                      |  - Filtrar stacks (si apl.)|
                      |  - Aplicar mirror (si apl.)|
                      |  - Almacenar en notes[]    |
                      +-------------+-------------+
                                    |
                                    v
         +-------------- Bucle de juego (cada frame) ----------------+
         |                          |                                 |
         |                          v                                 |
         |            +---------------------------+                   |
         |            |  dance.update(ms)          |                  |
         |            |  -> call("_update", ms)    |                  |
         |            +-------------+-------------+                   |
         |                          |                                 |
         |                          v                                 |
         |            +---------------------------+                   |
         |            |  Buscar nota actual:       |                  |
         |            |  Iterar notes[] hasta      |                  |
         |            |  encontrar notes[i].z > ms |                  |
         |            |  Start = notes[i-1]        |                  |
         |            |  End = notes[i]            |                  |
         |            +-------------+-------------+                   |
         |                          |                                 |
         |                          v                                 |
         |            +---------------------------+                   |
         |            |  Calcular t (progreso):    |                  |
         |            |  t = (ms - Start.z)        |                  |
         |            |      / (End.z - Start.z)   |                  |
         |            |  t = clamp(t, 0, 1)        |                  |
         |            +-------------+-------------+                   |
         |                          |                                 |
         |                          v                                 |
         |            +---------------------------+                   |
         |            |  Interpolar posicion:      |                  |
         |            |  [depende del mover]       |                  |
         |            |  Simple:  lerp + InBack    |                  |
         |            |  Bouncy:  Bezier cuadrat.  |                  |
         |            |  Direct.: Bezier cuadrat.  |                  |
         |            |  Moment.: Bezier cubica    |                  |
         |            +-------------+-------------+                   |
         |                          |                                 |
         |                          v                                 |
         |            +---------------------------+                   |
         |            |  Retornar Vector2          |                  |
         |            |  (posicion del cursor)     |                  |
         |            +---------------------------+                   |
         |                                                            |
         +------------------------------------------------------------+
```

---

## Comparacion de estilos de movimiento

### Tabla comparativa

| Caracteristica | Simple | Bouncy | Directional | Momentum |
|----------------|--------|--------|-------------|----------|
| **Tipo de curva** | Lineal (lerp) | Bezier cuadratica | Bezier cuadratica | Bezier cubica |
| **Easing** | `InBack` | `Linear` (sobre curva) | `Linear` (sobre curva) | Directo (sin easing) |
| **Puntos de control** | 0 | 2 | 2 | 2 (cubica = 4 total) |
| **Filtrado de stacks** | No | Si (< 10ms) | Si (< 10ms) | No |
| **Soporte mirror** | No | Si | No | No |
| **Factor momentum** | N/A | 0.75 | 0.6 | Via angulos |
| **Smoothstep rango** | N/A | [25, 300] | [15, 165] | N/A |
| **Clamping** | No | [-0.5, 2.5] | [-0.5, 2.5] | No |
| **Prebuf. easing** | N/A | `OutExpo` | `OutBack` | N/A |
| **Complejidad** | Baja | Media | Media | Alta |

### Comportamiento visual

```
Simple (lineal + InBack):
  A -------> B
  El cursor retrocede ligeramente y luego avanza en linea recta.
  Sensacion: mecanica, precisa, con un leve "tic" de impulso.

Bouncy (Bezier cuadratica adaptativa):
  A ---.___.--- B
  El cursor describe una curva suave. La curvatura se adapta
  a la distancia y tiempo entre notas.
  Sensacion: fluida, organica, elegante.

Directional (Bezier cuadratica direccional):
  A ---.___--- B
  Similar a Bouncy pero con curvas mas frecuentes y menos
  pronunciadas. Responde mas rapido a cambios de direccion.
  Sensacion: agil, responsiva, dinamica.

Momentum (Bezier cubica con inercia):
  A ---...___...--- B
  El cursor mantiene su direccion anterior al salir de una nota
  y ajusta su trayectoria para llegar a la siguiente. La curva
  es continua (sin quiebres bruscos entre segmentos).
  Sensacion: fisica, inercial, natural.
```

### Cuando se usa cada uno

| Mover | Contexto de uso |
|-------|----------------|
| `BouncyDanceMover` | **Autoplay en replays** - Usado por `Replay.gd` cuando `autoplayer = true` |
| `DirectionalDanceMover` | **Escena de prueba** - Usado por defecto en `dancetest.gd` |
| `SimpleDanceMover` | Disponible pero no referenciado directamente en ningun flujo activo |
| `MomentumDanceMover` | Disponible pero no referenciado directamente en ningun flujo activo |

---

## Integracion con el juego

### Replay y autoplay

El punto principal de integracion es a traves de **`Replay.gd`** (`scripts/content/game/Replay.gd`):

```gdscript
# En Replay.gd
var dance: DanceMover

# Cuando es autoplayer (sin replay grabado):
dance = BouncyDanceMover.new(song)

# Para obtener la posicion del cursor:
func get_cursor_position(ms: float):
    if autoplayer:
        return Vector2(1, -1) * dance.update(ms)
```

Cuando el sistema de replays opera en modo **autoplayer** (sin un replay grabado previamente), crea un `BouncyDanceMover` y lo usa para generar las posiciones del cursor frame a frame. El factor `Vector2(1, -1)` invierte el eje Y para adaptarse al sistema de coordenadas del juego 3D.

### Dance como utilidad global

Al ser un Autoload, `Dance` se usa como biblioteca de easing en todo el proyecto, no solo en el sistema de cursor dance:

| Archivo | Uso |
|---------|-----|
| `scripts/cursordance/Main.gd` | `Dance.InQuint()` para la opacidad y tamano de las notas que se aproximan |
| `scripts/cursordance/Simple.gd` | `Dance.InBack()` para la interpolacion del movimiento |
| `scripts/cursordance/Bouncy.gd` | `Dance.Linear()`, `Dance.OutExpo()` para curvas y prebuffereo |
| `scripts/cursordance/Directional.gd` | `Dance.Linear()`, `Dance.OutBack()` para curvas y prebuffereo |
| `scripts/ui/menu/WarningBar.gd` | `Dance.InOutSine()` para la animacion de entrada/salida de la barra de aviso |

### Acceso desde el menu

La escena de prueba del cursor dance es accesible desde la barra lateral del menu:

```gdscript
# En Sidebar.gd
Rhythia.menu_target = "res://scripts/cursordance/dancetest.tscn"
```

### Clases globales registradas en project.godot

Todos los movers estan registrados como clases globales en el proyecto, lo que permite instanciarlos desde cualquier script usando `NombreDanceMover.new(song)`:

| Clase | Base | Archivo |
|-------|------|---------|
| `DanceMover` | `Resource` | `scripts/cursordance/DanceMover.gd` |
| `SimpleDanceMover` | `DanceMover` | `scripts/cursordance/Simple.gd` |
| `BouncyDanceMover` | `DanceMover` | `scripts/cursordance/Bouncy.gd` |
| `DirectionalDanceMover` | `DanceMover` | `scripts/cursordance/Directional.gd` |
| `MomentumDanceMover` | `DanceMover` | `scripts/cursordance/Momentum.gd` |

### Diagrama de integracion

```
+------------------+          +------------------+
|    Sidebar.gd    |          |    Replay.gd     |
| (menu lateral)   |          | (autoplay mode)  |
+--------+---------+          +--------+---------+
         |                             |
         | navega a                    | crea
         v                             v
+------------------+          +------------------+
| dancetest.tscn   |          | BouncyDanceMover |
| (escena prueba)  |          |   .new(song)     |
+--------+---------+          +--------+---------+
         |                             |
         | crea                        | .update(ms)
         v                             v
+------------------+          +------------------+
| Directional      |          | Vector2 posicion |
| DanceMover       |          | del cursor       |
|   .new(song)     |          +------------------+
+--------+---------+
         |
         | .update(ms)              +------------------+
         v                          |    Dance.gd      |
+------------------+                | (Autoload)       |
| Vector2 posicion +<-- easing --- >| Funciones de     |
| del cursor       |                | interpolacion    |
+------------------+                +------------------+
```
