# 08 - Sistema de Avatar

> Documentacion de arquitectura para **Sound Space Plus (Rhythia)** - Motor: Godot 3.x

---

## Indice

1. [Vision general](#vision-general)
2. [Tabla de scripts](#tabla-de-scripts)
3. [Diagrama de componentes del avatar](#diagrama-de-componentes-del-avatar)
4. [Avatar.tscn (Avatar normal)](#avatartscn-avatar-normal)
   - [Estructura del nodo Avatar](#estructura-del-nodo-avatar)
   - [Cabeza (Head)](#cabeza-head)
   - [Torso](#torso)
   - [Brazos (ArmL / ArmR)](#brazos-arml--armr)
   - [Shaders de color](#shaders-de-color)
   - [Animaciones](#animaciones)
5. [ARVRAvatar.tscn (Avatar VR)](#arvravatartscn-avatar-vr)
   - [Estructura VR](#estructura-vr)
   - [Diferencias entre avatar normal y VR](#diferencias-entre-avatar-normal-y-vr)
6. [AvatarPointer.gd (Seguimiento del cursor)](#avatarpointergd-seguimiento-del-cursor)
7. [shirt_animations.gd (Animaciones de camisa)](#shirt_animationsgd-animaciones-de-camisa)
8. [Editor de Avatar](#editor-de-avatar)
   - [AvatarEditor.gd (Controlador principal)](#avatareditorgd-controlador-principal)
   - [AvatarEditorBack.gd (Navegacion)](#avatareditobackgd-navegacion)
   - [AddAccessory.gd (Agregar accesorios)](#addaccessorygd-agregar-accesorios)
   - [AccessoryList.gd (Lista de accesorios)](#accessorylistgd-lista-de-accesorios)
   - [Flujo de personalizacion](#flujo-de-personalizacion)
9. [Friend.gd (Avatar de amigo)](#friendgd-avatar-de-amigo)
   - [Sistema de estados](#sistema-de-estados)
   - [Posiciones disponibles](#posiciones-disponibles)
10. [Integracion con el sistema de juego](#integracion-con-el-sistema-de-juego)

---

## Vision general

El sistema de **Avatar** de Sound Space Plus (Rhythia) proporciona una representacion visual personalizable del jugador durante la partida. El avatar es un personaje 3D estilizado compuesto por formas geometricas simples (cubos redondeados) que se posiciona en la escena de juego y reacciona al movimiento del cursor.

El sistema se compone de:

- **`Avatar.tscn`** - Escena principal del avatar con todos sus componentes visuales (cabeza, torso, brazos, ojos, accesorios, camisas).
- **`ARVRAvatar.tscn`** - Variante del avatar adaptada para realidad virtual con controladores ARVR.
- **`AvatarPointer.gd`** - Script que hace que el brazo izquierdo del avatar siga la posicion del cursor en la grilla de juego.
- **`shirt_animations.gd`** - Script que reproduce las animaciones de la camisa del avatar.
- **Editor de Avatar** - Conjunto de scripts (`AvatarEditor.gd`, `AvatarEditorBack.gd`, `AddAccessory.gd`, `AccessoryList.gd`) que permiten al jugador personalizar su avatar.
- **`Friend.gd`** - Script que gestiona la imagen del "amigo" del jugador, un sprite reactivo al estado de la partida.

El avatar usa un estilo visual **low-poly unshaded** (sin iluminacion), con colores solidos controlados por shaders personalizados que permiten cambiar el color de cada parte del cuerpo de forma independiente.

---

## Tabla de scripts

| Archivo | Ruta | Clase base | Proposito |
|---------|------|------------|-----------|
| `AvatarPointer.gd` | `scripts/avatar/AvatarPointer.gd` | `Spatial` | Hace que el brazo izquierdo apunte hacia el cursor |
| `shirt_animations.gd` | `scripts/avatar/shirt_animations.gd` | `Spatial` | Reproduce la animacion Idle de la camisa |
| `AvatarEditor.gd` | `scripts/ui/avatarEditor/AvatarEditor.gd` | `Control` | Controlador principal del editor de avatar |
| `AvatarEditorBack.gd` | `scripts/ui/avatarEditor/AvatarEditorBack.gd` | `Button` | Boton para volver al menu desde el editor |
| `AddAccessory.gd` | `scripts/ui/avatarEditor/AddAccessory.gd` | `Button` | Agrega accesorios o camisas al avatar |
| `AccessoryList.gd` | `scripts/ui/avatarEditor/AccessoryList.gd` | `ItemList` | Lista de accesorios activos, permite removerlos |
| `Friend.gd` | `scripts/game/Friend.gd` | `MeshInstance` | Imagen reactiva del amigo del jugador en partida |

| Escena | Ruta | Proposito |
|--------|------|-----------|
| `Avatar.tscn` | `prefabs/Avatar.tscn` | Prefab del avatar completo del jugador |
| `ARVRAvatar.tscn` | `prefabs/ARVRAvatar.tscn` | Prefab del avatar para modo VR |
| `AvatarEditor.tscn` | `scenes/menu/AvatarEditor.tscn` | Escena del editor de personalizacion |
| `tempshirts.tscn` | `scenes/test/tempshirts.tscn` | Escena con las camisas disponibles |
| `tempaccessories.tscn` | `scenes/test/tempaccessories.tscn` | Escena con los accesorios disponibles |

---

## Diagrama de componentes del avatar

```
Avatar (Spatial)
|
+-- Head (MeshInstance) ..................... Cabeza del avatar
|   |   transform: escala 0.225, rotacion leve en X
|   |   mesh: LowCube.obj
|   |   material: ShaderMaterial (notecolor)
|   |
|   +-- EyeR (MeshInstance) ............... Ojo derecho
|   |   transform: escala (0.1, 0.4, 0.01), pos (0.35, 0.25, -1)
|   |   material: negro solido
|   |
|   +-- EyeL (MeshInstance) ............... Ojo izquierdo
|   |   transform: escala (0.1, 0.4, 0.01), pos (-0.35, 0.25, -1)
|   |   material: negro solido
|   |
|   +-- HappyR (MeshInstance) ............. Ojo feliz derecho (oculto por defecto)
|   |   mesh: Happy.obj
|   |
|   +-- HappyL (MeshInstance) ............. Ojo feliz izquierdo (oculto por defecto)
|   |   mesh: Happy.obj
|   |
|   +-- Blinking (AnimationPlayer) ........ Animacion de parpadeo
|   |   anims: Blink, RESET
|   |
|   +-- Outline (MeshInstance) ............ Contorno negro de la cabeza
|   |
|   +-- Accessories (instancia) ........... Accesorios de cabeza
|       source: tempaccessories.tscn
|       +-- CubellaHair > Ears ............ Orejas
|       +-- Headset ....................... Auriculares
|
+-- Torso (MeshInstance) ................... Torso del avatar
|   |   transform: escala (0.15, 0.25, 0.15), pos (0, -0.775, 2)
|   |   mesh: LowCube.obj
|   |
|   +-- Outline (MeshInstance) ............ Contorno (oculto)
|   |
|   +-- Shirts (instancia) ................ Camisas del torso
|       source: tempshirts.tscn
|       script: shirt_animations.gd
|       +-- CubellaBikini > Top ........... Parte superior
|       +-- CubellaBikini > Strap ......... Tirante
|
+-- ArmL (Spatial) ......................... Brazo izquierdo (puntero)
|   |   transform: pos (-0.5, -0.5, 2)
|   |   script: AvatarPointer.gd
|   |
|   +-- Pointer (MeshInstance) ............ Cubo del puntero
|   |   transform: escala 0.1, pos (0, 0.008, -0.496)
|   |
|   +-- Outline (MeshInstance) ............ Contorno del puntero
|   |
|   +-- Trail (Particles) ................ Estela de particulas
|       amount: 100, lifetime: 0.25s
|
+-- ArmR (Spatial) ......................... Brazo derecho (estatico)
|   |
|   +-- Mesh (MeshInstance) ............... Cubo del brazo derecho
|       transform: escala 0.1, rotacion leve en Z, pos (0.5, -0.75, 2)
|
+-- Animations (AnimationPlayer) ........... Animaciones del cuerpo
    anims: Idle, RESET
```

---

## Avatar.tscn (Avatar normal)

- **Archivo**: `prefabs/Avatar.tscn`
- **Nodo raiz**: `Avatar` (tipo `Spatial`)
- **Dependencias**: 25 recursos (8 externos, 17 sub-recursos)

### Estructura del nodo Avatar

El avatar es una escena `Spatial` compuesta por nodos `MeshInstance` que usan el mesh `LowCube.obj` (un cubo con bordes redondeados) como geometria base. Cada parte del cuerpo tiene un tamano y posicion diferente, logrados mediante la propiedad `transform` de cada nodo.

**Recursos externos referenciados:**

| ID | Recurso | Tipo | Uso |
|----|---------|------|-----|
| 1 | `assets/animations/Blink.tres` | `Animation` | Animacion de parpadeo de los ojos |
| 2 | `assets/animations/Idle.tres` | `Animation` | Animacion de reposo del cuerpo |
| 3 | `scenes/test/tempshirts.tscn` | `PackedScene` | Camisas disponibles |
| 4 | `scenes/test/tempaccessories.tscn` | `PackedScene` | Accesorios disponibles |
| 5 | `assets/meshes/Happy.obj` | `ArrayMesh` | Mesh de ojos felices (forma curva) |
| 6 | `assets/meshes/LowCube.obj` | `ArrayMesh` | Mesh base de cubo redondeado |
| 7 | `scripts/avatar/AvatarPointer.gd` | `Script` | Script del brazo puntero |
| 8 | `scripts/avatar/shirt_animations.gd` | `Script` | Script de animaciones de camisa |

### Cabeza (Head)

La cabeza es el componente mas complejo del avatar. Contiene:

- **Mesh principal**: `LowCube.obj` escalado a `0.225` en cada eje, con una leve rotacion en el eje X (`-5 grados` en la animacion RESET) que le da una inclinacion natural.
- **Ojos normales** (`EyeR`, `EyeL`): Rectangulos negros muy delgados (`escala Z = 0.01`) posicionados en la cara frontal de la cabeza. Los ojos tienen una escala vertical (`Y = 0.4`) mayor que la horizontal (`X = 0.1`), creando pupilas alargadas verticalmente.
- **Ojos felices** (`HappyR`, `HappyL`): Meshes alternativos usando `Happy.obj` (forma curva de sonrisa). Estan **ocultos por defecto** (`visible = false`) y se activan en determinados estados del juego.
- **Parpadeo** (`Blinking`): `AnimationPlayer` con la animacion `Blink` que escala los ojos periodicamente para simular el parpadeo.
- **Contorno** (`Outline`): Mesh ligeramente mas grande que la cabeza con material negro solido, creando un efecto de borde/outline tipo cel-shading.
- **Accesorios** (`Accessories`): Instancia de `tempaccessories.tscn` que contiene los accesorios disponibles (ej. `CubellaHair` con orejas, `Headset` con auriculares). Los accesorios se activan/desactivan cambiando su propiedad `visible`.

### Torso

El torso es un cubo mas ancho que alto:

- **Escala**: `(0.15, 0.25, 0.15)` - mas alto que ancho.
- **Posicion**: `(0, -0.775, 2)` - debajo de la cabeza, desplazado en Z (profundidad).
- **Contorno**: Presente pero **oculto por defecto**.
- **Camisas** (`Shirts`): Instancia de `tempshirts.tscn` con el script `shirt_animations.gd` asignado. Las camisas son meshes decorativos que se superponen al torso.

### Brazos (ArmL / ArmR)

El avatar tiene dos brazos con funciones diferentes:

**Brazo izquierdo (ArmL)** - El brazo "puntero":
- Es un nodo `Spatial` con el script `AvatarPointer.gd` que le permite seguir la posicion del cursor.
- Contiene un `MeshInstance` (`Pointer`) con escala `0.1` que representa el cubo del brazo.
- Incluye un sistema de particulas (`Trail`) para dejar una estela visual.
- Tiene contorno negro como la cabeza.

**Brazo derecho (ArmR)** - El brazo estatico:
- Es un nodo `Spatial` sin script.
- Contiene un `MeshInstance` (`Mesh`) posicionado a la derecha del torso con una leve rotacion en Z (`7.5 grados` en la animacion RESET), dandole una postura natural.
- Tambien tiene contorno negro.

### Shaders de color

El avatar utiliza **shaders personalizados** para controlar el color de cada componente. Hay dos variantes del mismo shader:

**Shader principal (cabeza, torso, brazos):**

```glsl
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_disabled, unshaded;
uniform vec4 notecolor : hint_color = vec4(1,1,1,1);
uniform float alpha_multi = 1;
uniform float fade = 1;
uniform bool use_image = false;
uniform sampler2D image;

void fragment() {
    vec4 img = vec4(1.0);
    if (use_image) {
        img = texture(image, UV);
    }
    ALBEDO = notecolor.rgb * img.rgb;
    ALPHA = notecolor.a * img.a * alpha_multi * fade;
}
```

| Parametro | Tipo | Valor por defecto | Proposito |
|-----------|------|-------------------|-----------|
| `notecolor` | `Color` | Blanco `(1,1,1,1)` u otro segun la parte | Color base del componente |
| `alpha_multi` | `float` | `1.0` | Multiplicador de opacidad |
| `fade` | `float` | `1.0` | Factor de desvanecimiento |
| `use_image` | `bool` | `false` | Si se usa una textura personalizada |
| `image` | `sampler2D` | *(vacio)* | Textura personalizada opcional |

**Materiales asignados:**

| Material | render_priority | notecolor | Uso |
|----------|-----------------|-----------|-----|
| SubResource 58 | `112` | Blanco `(1,1,1,1)` | Partes principales (cabeza, torso, brazos) |
| SubResource 59 | `110` | Negro `(0,0,0,1)` | Ojos |
| SubResource 67 | `111` | Negro `(0,0,0,1)` | Contornos (SpatialMaterial, no shader) |

El modo `unshaded` y `specular_disabled` garantiza que el avatar tenga un aspecto plano y consistente independientemente de la iluminacion de la escena. Los valores de `render_priority` aseguran que las capas se dibujen en el orden correcto (contornos detras, ojos encima).

### Animaciones

El avatar tiene dos `AnimationPlayer`:

**1. Blinking (cabeza)** - Parpadeo de los ojos:
- Animacion `Blink`: Modifica la escala y posicion de `EyeL` y `EyeR` para simular el cierre y apertura de los parpados.
- Animacion `RESET`: Estado base de los ojos (`escala (0.1, 0.4, 0.01)`, posiciones simetricas).

**2. Animations (cuerpo)** - Animacion corporal:
- Animacion `Idle`: Animacion de reposo que mueve sutilmente el torso, la cabeza y los brazos.
- Animacion `RESET`: Estado base del cuerpo con las posiciones iniciales de cada componente:

| Componente | Posicion | Rotacion |
|------------|----------|----------|
| `Torso` | `(0, -0.775, 2)` | `(0, 0, 0)` |
| `ArmR/Mesh` | `(0.5, -0.75, 2)` | `(0, 0, 7.5)` |
| `Head` | `(0, -0.125, 1.975)` | `(-5, 0, 0)` |
| `ArmL` | `(-0.5, -0.5, 2)` | `(0, 0, 0)` |

---

## ARVRAvatar.tscn (Avatar VR)

- **Archivo**: `prefabs/ARVRAvatar.tscn`
- **Nodo raiz**: `ARVRAvatar` (tipo `Spatial`)
- **Dependencias**: 12 recursos (1 externo, 11 sub-recursos)

### Estructura VR

```
ARVRAvatar (Spatial)
|
+-- vorigin (ARVROrigin) .................. Origen del espacio VR
    |   world_scale: 2.0
    |
    +-- vcamera (ARVRCamera) .............. Camara VR del jugador
    |   fov: 83.16
    |
    +-- vleft (ARVRController) ............ Controlador izquierdo
    |   |   controller_id: 1 (por defecto)
    |   |
    |   +-- mesh (MeshInstance) ........... Cubo del controlador
    |   |   transform: escala 0.1
    |   |   mesh: LowCube.obj
    |   |   material: ShaderMaterial (notecolor blanco)
    |   |
    |   +-- outline (MeshInstance) ........ Contorno negro
    |   |
    |   +-- trail (Particles) ............. Estela de particulas (oculta)
    |       amount: 500, lifetime: 0.25s
    |
    +-- vright (ARVRController) ........... Controlador derecho
        |   controller_id: 2
        |
        +-- mesh (MeshInstance) ........... Cubo del controlador
        |   transform: escala 0.1
        |   material: ShaderMaterial (notecolor blanco)
        |
        +-- outline (MeshInstance) ........ Contorno negro
        |
        +-- trail (Particles) ............. Estela de particulas (oculta)
        |   amount: 500, lifetime: 0.25s
        |
        +-- ray (RayCast) ................ Rayo de apuntado
            enabled: true
            cast_to: (0, 0, -36)
```

El avatar VR reemplaza la estructura antropomorfica del avatar normal con una representacion basada en los controladores VR. Cada controlador se visualiza como un cubo (`LowCube.obj`) con contorno negro, similar en estilo a las partes del avatar normal.

### Diferencias entre avatar normal y VR

| Aspecto | Avatar normal (`Avatar.tscn`) | Avatar VR (`ARVRAvatar.tscn`) |
|---------|-------------------------------|-------------------------------|
| **Nodo raiz** | `Spatial` | `Spatial` |
| **Componentes visuales** | Cabeza, torso, 2 brazos, ojos, accesorios, camisas | 2 cubos (uno por controlador) |
| **Seguimiento** | Brazo izquierdo sigue el cursor (`AvatarPointer.gd`) | Controladores siguen las manos VR nativamente |
| **Sistema de camara** | No incluye camara (usa la de la escena) | Incluye `ARVRCamera` con FOV 83.16 |
| **Animaciones** | `Idle`, `Blink` (AnimationPlayer) | Sin animaciones predefinidas |
| **Scripts** | `AvatarPointer.gd`, `shirt_animations.gd` | Sin scripts personalizados |
| **Accesorios/Camisas** | Si (instancias externas) | No |
| **Particulas** | 100 particulas en brazo izquierdo | 500 particulas por controlador (ocultas) |
| **Escala mundo** | Normal (1.0 implicito) | `world_scale: 2.0` |
| **RayCast** | No | Si, en controlador derecho (alcance: 36 unidades) |
| **Contornos** | En cabeza, brazos | En ambos controladores |
| **render_priority** | Multiples niveles (110, 111, 112) | Nivel unico (2) |

El avatar VR es significativamente mas simple porque delega el tracking de movimiento al sistema ARVR de Godot en lugar de usar scripts personalizados. El `RayCast` en el controlador derecho se usa para interaccion con la interfaz en modo VR.

---

## AvatarPointer.gd (Seguimiento del cursor)

- **Extiende**: `Spatial`
- **Archivo**: `scripts/avatar/AvatarPointer.gd`
- **Asignado a**: Nodo `ArmL` en `Avatar.tscn`
- **Proposito**: Hace que el brazo izquierdo del avatar apunte constantemente hacia la posicion del cursor en la grilla de juego.

### Codigo completo

```gdscript
extends Spatial

func _process(delta):
    if get_parent().get_parent().has_node("Spawn/Cursor"):
        look_at(get_parent().get_parent().get_node("Spawn/Cursor").translation - Vector3(2,0,0), Vector3.UP)
    else:
        pass
```

### Funcionamiento

1. **Cada frame** (`_process`), el script busca el nodo `Spawn/Cursor` en el abuelo del nodo actual.
2. **Navegacion de nodos**: `get_parent().get_parent()` sube dos niveles desde `ArmL` -> `Avatar` -> nodo padre del avatar (la escena de juego).
3. **Calculo de direccion**: Si el cursor existe, usa `look_at()` para rotar el brazo izquierdo hacia la posicion del cursor, con un offset de `-2` en el eje X para compensar la posicion relativa del brazo respecto a la grilla.
4. **Vector UP**: Usa `Vector3.UP` como eje "arriba" para mantener la orientacion correcta del brazo.
5. **Sin cursor**: Si el nodo `Spawn/Cursor` no existe (por ejemplo, en el editor de avatar o en el menu), el script simplemente no hace nada (`pass`).

### Contexto en la escena de juego

En la escena de juego (`song.tscn`), la jerarquia es:

```
Game
+-- Spawn
|   +-- Cursor ........... Posicion 3D del cursor del jugador
|   +-- Friend ........... Imagen del amigo
+-- Avatar (instancia de Avatar.tscn)
    +-- ArmL (script: AvatarPointer.gd)
        +-- Pointer
```

El brazo izquierdo apunta hacia donde el jugador mueve el mouse/cursor, creando la ilusion de que el avatar esta "senalando" las notas.

---

## shirt_animations.gd (Animaciones de camisa)

- **Extiende**: `Spatial`
- **Archivo**: `scripts/avatar/shirt_animations.gd`
- **Asignado a**: Nodo `Torso/Shirts` en `Avatar.tscn`
- **Proposito**: Reproduce automaticamente la animacion de reposo de la camisa del avatar al iniciar.

### Codigo completo

```gdscript
extends Spatial

func _ready():
    $CubellaBikini/Top/Animations.play("Idle")
```

### Funcionamiento

Al instanciar el avatar, el metodo `_ready()` busca el nodo `CubellaBikini/Top/Animations` (un `AnimationPlayer` dentro de la camisa `CubellaBikini`) y reproduce su animacion `Idle`. Esto permite que la camisa tenga movimiento propio (como ondulacion o balanceo) independiente de la animacion del cuerpo.

La estructura interna de la camisa es:

```
Shirts (Spatial, script: shirt_animations.gd)
+-- CubellaBikini
    +-- Top (parte superior)
    |   +-- Animations (AnimationPlayer)
    |       anim: "Idle"
    +-- Strap (tirante)
```

---

## Editor de Avatar

El editor de avatar permite al jugador personalizar la apariencia de su avatar directamente desde el menu del juego. Se compone de una escena principal (`AvatarEditor.tscn`) y cuatro scripts que gestionan la interaccion.

### AvatarEditor.gd (Controlador principal)

- **Extiende**: `Control`
- **Archivo**: `scripts/ui/avatarEditor/AvatarEditor.gd`
- **Proposito**: Inicializa la previsualizacion del avatar en el editor.

```gdscript
extends Control

func _ready():
    $VPContainer/VP/Avatar/Animations.play("Idle")
    $VPContainer/VP/Avatar/Head/Blinking.play("Blink")
```

Al abrirse el editor, se reproducen automaticamente las animaciones `Idle` del cuerpo y `Blink` del parpadeo para que el jugador vea una previsualizacion animada del avatar mientras lo personaliza.

**Estructura de la escena del editor:**

```
AvatarEditor (Control, script: AvatarEditor.gd)
+-- VPContainer
|   +-- VP (Viewport) .................... Vista 3D del avatar
|       +-- Avatar (instancia) ........... Previsualizacion del avatar
|           +-- Animations
|           +-- Head
|               +-- Blinking
+-- Head (contenedor UI)
|   +-- Input (LineEdit) ................. Campo de texto para nombre del accesorio
|   +-- AddAccessory (Button) ............ Boton para agregar accesorio de cabeza
|   +-- List (ItemList) .................. Lista de accesorios de cabeza activos
+-- Torso (contenedor UI)
|   +-- Input (LineEdit) ................. Campo de texto para nombre de camisa
|   +-- AddAccessory (Button) ............ Boton para agregar camisa
|   +-- List (ItemList) .................. Lista de camisas activas
+-- Back (Button) ........................ Boton para volver al menu
```

### AvatarEditorBack.gd (Navegacion)

- **Extiende**: `Button`
- **Archivo**: `scripts/ui/avatarEditor/AvatarEditorBack.gd`
- **Proposito**: Boton para cerrar el editor y volver al menu principal.

```gdscript
extends Button

func _pressed():
    get_tree().change_scene("menu2.tscn")
```

Al presionar el boton, cambia la escena activa a `menu2.tscn` (el menu principal del juego).

### AddAccessory.gd (Agregar accesorios)

- **Extiende**: `Button`
- **Archivo**: `scripts/ui/avatarEditor/AddAccessory.gd`
- **Proposito**: Boton compartido para agregar accesorios a la cabeza o camisas al torso.

#### Logica

El script detecta en que seccion se encuentra (cabeza o torso) segun el nombre del nodo padre:

```gdscript
func _pressed():
    if get_parent().name == "Head" and get_parent().get_node("Input").text != "":
        # Agrega accesorio de cabeza
        if get_parent().get_parent().get_node("VPContainer/VP/Avatar/Head/Accessories").has_node(...):
            # Hace visible el accesorio en el avatar
        get_parent().get_node("List").add_item(...)  # Agrega a la lista UI

    elif get_parent().name == "Torso" and get_parent().get_node("Input").text != "":
        # Agrega camisa al torso
        if get_parent().get_parent().get_node("VPContainer/VP/Avatar/Torso/Shirts").has_node(...):
            # Hace visible la camisa en el avatar
        get_parent().get_node("List").add_item(...)  # Agrega a la lista UI
```

**Flujo de ejecucion:**

1. Verifica que el campo de texto (`Input`) no este vacio.
2. Determina si es un accesorio de cabeza o una camisa segun `get_parent().name`.
3. Busca el nodo hijo correspondiente en el avatar (`Head/Accessories` o `Torso/Shirts`).
4. Si el accesorio/camisa existe como nodo, lo hace visible (`visible = true`).
5. Agrega el nombre a la lista visual (`ItemList`) para que el jugador lo vea.
6. Limpia el campo de texto.

### AccessoryList.gd (Lista de accesorios)

- **Extiende**: `ItemList`
- **Archivo**: `scripts/ui/avatarEditor/AccessoryList.gd`
- **Proposito**: Permite al jugador remover accesorios o camisas haciendo doble clic en la lista.

```gdscript
func _on_List_item_activated(index):
    if get_parent().get_parent().get_node("VPContainer/VP/Avatar/Head/Accessories").has_node(get_item_text(index)):
        # Oculta el accesorio de cabeza
        .get_node(get_item_text(index)).visible = false
    elif get_parent().get_parent().get_node("VPContainer/VP/Avatar/Torso/Shirts").has_node(get_item_text(index)):
        # Oculta la camisa
        .get_node(get_item_text(index)).visible = false
    remove_item(index)  # Remueve de la lista
```

**Flujo de remocion:**

1. Al activar un item (doble clic), obtiene el nombre del accesorio.
2. Busca si existe como nodo en `Head/Accessories` o `Torso/Shirts`.
3. Si lo encuentra, lo oculta (`visible = false`).
4. Remueve el item de la lista visual.

### Flujo de personalizacion

```
+-------------------------+
|   Jugador abre editor   |
|   (AvatarEditor.tscn)   |
+------------+------------+
             |
             v
+-------------------------+
|  Avatar se anima en el  |
|  Viewport (Idle+Blink)  |
+------------+------------+
             |
     +-------+-------+
     |               |
     v               v
+-----------+  +-----------+
| Seccion   |  | Seccion   |
| Head      |  | Torso     |
+-----------+  +-----------+
     |               |
     v               v
+-----------+  +-----------+
| Escribir  |  | Escribir  |
| nombre    |  | nombre    |
| accesorio |  | camisa    |
+-----------+  +-----------+
     |               |
     v               v
+-----------+  +-----------+
| Click en  |  | Click en  |
| "Add"     |  | "Add"     |
+-----------+  +-----------+
     |               |
     v               v
+-----------+  +-----------+
| Accesorio |  | Camisa    |
| visible   |  | visible   |
| en avatar |  | en avatar |
+-----------+  +-----------+
     |               |
     v               v
+-----------+  +-----------+
| Se agrega |  | Se agrega |
| a lista   |  | a lista   |
+-----------+  +-----------+
     |               |
     v               v
+-------------------------+
| Doble clic en lista     |
| = Remover accesorio     |
+-------------------------+
             |
             v
+-------------------------+
|  Click en "Back"        |
|  -> Volver a menu2.tscn |
+-------------------------+
```

**Nota**: El sistema de accesorios/camisas funciona activando y desactivando la visibilidad de nodos que ya existen dentro de `tempaccessories.tscn` y `tempshirts.tscn`. El jugador escribe el nombre exacto del nodo hijo que desea activar. Esto significa que los accesorios disponibles estan predefinidos en las escenas de plantilla.

---

## Friend.gd (Avatar de amigo)

- **Extiende**: `MeshInstance`
- **Archivo**: `scripts/game/Friend.gd`
- **Proposito**: Muestra una imagen reactiva del "amigo" del jugador durante la partida. La imagen cambia segun el estado actual del juego (vida, combo, pausa, etc.).

### Sistema de estados

El "amigo" es un `MeshInstance` plano (sprite 3D) cuya textura cambia dinamicamente segun el estado de la partida. El jugador puede colocar imagenes personalizadas en la carpeta `user://friend/` con nombres que corresponden a los estados disponibles.

**Estados disponibles (en orden de prioridad):**

| Estado | Condicion | Descripcion |
|--------|-----------|-------------|
| `done` | `ms > last_ms` | La cancion ha terminado |
| `fail` | `failed == true` | El jugador ha fallado |
| `givingup` | Tecla "give_up" presionada | El jugador esta rindiendo |
| `unpausing` | `pause_state > 0` | Saliendo de pausa |
| `paused` | `pause_state != 0` | Juego en pausa |
| `fullcombo` | `misses == 0` | Full combo (ningun fallo) |
| `1hp` | `energy <= 1` | Un punto de vida o menos |
| `halfhp` | `energy <= max_energy/2` | Mitad de vida o menos |
| `losthp` | `energy != max_energy` | Ha perdido algo de vida |
| `normal` | *(siempre true)* | Estado por defecto |

El sistema evalua los estados **en orden de prioridad** (de arriba a abajo). El primer estado cuya condicion sea verdadera se aplica. Esto significa que `done` tiene la mayor prioridad y `normal` la menor (es el fallback).

### Carga de texturas

```gdscript
func _ready():
    for s in all_states:
        var tex = Globals.imageLoader.load_if_exists("user://friend/" + s)
        if tex:
            states.append(s)
            textures.append(tex)
    if states.size() == 0: visible = false
```

Al iniciar, el script intenta cargar una imagen para cada estado desde `user://friend/`. Solo los estados que tienen imagen se activan. Si no hay ninguna imagen, el nodo se oculta completamente.

**Ruta de imagenes**: `user://friend/<estado>` (ej. `user://friend/normal`, `user://friend/fullcombo`).

### Posiciones disponibles

La posicion del amigo en la pantalla se configura a traves de `Rhythia.friend_position`. Hay **8 posiciones** definidas como enumeracion en `Globals.gd`:

| Constante | Valor | Nodo de referencia | Descripcion |
|-----------|-------|--------------------|-------------|
| `FRIEND_LOWER_RIGHT` | 0 | *(posicion por defecto)* | Esquina inferior derecha |
| `FRIEND_LOWER_LEFT` | 1 | `FriendLL` | Esquina inferior izquierda |
| `FRIEND_UPPER_RIGHT` | 2 | `FriendUR` | Esquina superior derecha |
| `FRIEND_UPPER_LEFT` | 3 | `FriendUL` | Esquina superior izquierda |
| `FRIEND_FILL_GRID` | 4 | `FriendC` | Llena la grilla (alpha 0.1, tamano 3x3) |
| `FRIEND_BEHIND_GRID` | 5 | `FriendBG` | Detras de la grilla (alpha 0.1, tamano 1x1) |
| `FRIEND_BELOW_UI_L` | 6 | *(ver nota)* | Debajo de la UI izquierda |
| `FRIEND_BELOW_UI_R` | 7 | *(ver nota)* | Debajo de la UI derecha |

**Nota**: El valor por defecto es `FRIEND_BEHIND_GRID` (detras de la grilla, practicamente oculto con alpha 0.1).

Las posiciones `FRIEND_FILL_GRID` y `FRIEND_BEHIND_GRID` modifican adicionalmente la opacidad y el tamano del mesh:

```gdscript
Globals.FRIEND_FILL_GRID:
    transform = get_node("../FriendC").transform
    get("material/0").albedo_color.a = 0.1  # Casi transparente
    mesh.size = Vector2(3,3)                # Cubre toda la grilla

Globals.FRIEND_BEHIND_GRID:
    transform = get_node("../FriendBG").transform
    get("material/0").albedo_color.a = 0.1  # Casi transparente
    mesh.size = Vector2(1,1)                # Tamano estandar
```

Los nodos de posicion (`FriendLR`, `FriendUR`, `FriendLL`, `FriendUL`, `FriendC`, `FriendBG`) son nodos `Position3D` definidos en la escena de juego (`scenes/song.tscn`) dentro de `Game/Spawn`.

---

## Integracion con el sistema de juego

### Flujo del avatar durante una partida

```
+------------------+          +-------------------+
|  scenes/song.tscn |         | prefabs/Avatar.tscn|
|  (escena de juego)|         | (prefab del avatar)|
+--------+---------+          +---------+---------+
         |                              |
         | instancia                    | se carga como hijo de
         v                              v
+------------------+          +-------------------+
|  Game (nodo)     |          |  Avatar (Spatial)  |
|  +-- Spawn       |          |  +-- Head          |
|  |   +-- Cursor  |<---------|--+-- ArmL (Pointer)|
|  |   +-- Friend  |          |  +-- ArmR          |
|  +-- HUD         |          |  +-- Torso         |
+------------------+          |  +-- Animations    |
                              +-------------------+
```

### Interacciones principales

| Componente | Interactua con | Tipo de interaccion |
|------------|----------------|---------------------|
| `AvatarPointer.gd` | `Spawn/Cursor` | Lee la posicion del cursor cada frame para rotar el brazo |
| `shirt_animations.gd` | `CubellaBikini/Top/Animations` | Reproduce animacion Idle al iniciar |
| `Friend.gd` | `HUD.gd` | HUD notifica a Friend sobre estado de fallo |
| `Friend.gd` | `Rhythia.gd` | Lee `friend_position` para determinar su posicion |
| `Friend.gd` | `Globals.imageLoader` | Carga imagenes personalizadas del jugador |
| `AvatarEditor.gd` | `Avatar.tscn` (en Viewport) | Muestra previsualizacion animada del avatar |
| `AddAccessory.gd` | `tempaccessories.tscn` / `tempshirts.tscn` | Activa/desactiva nodos de accesorios y camisas |

### Persistencia de configuracion

La posicion del amigo (`friend_position`) se guarda como parte de la configuracion del jugador en `Rhythia.gd`:

- **Carga JSON**: `if data.has("friend_position"): friend_position = data.friend_position`
- **Carga binaria**: `friend_position = file.get_8()` (formato version >= 30)
- **Guardado**: Se incluye en el diccionario de datos serializado como `friend_position = friend_position`

Las imagenes del amigo se almacenan en el directorio del usuario:

```
user://friend/
+-- normal       (imagen para estado normal)
+-- fullcombo    (imagen para full combo)
+-- fail         (imagen para fallo)
+-- paused       (imagen para pausa)
+-- done         (imagen para fin de cancion)
+-- 1hp          (imagen para 1 HP)
+-- halfhp       (imagen para mitad de vida)
+-- losthp       (imagen para vida perdida)
+-- givingup     (imagen para rendicion)
+-- unpausing    (imagen para salida de pausa)
```

### Diagrama de relaciones

```
+------------------+     lee posicion     +------------------+
|  AvatarPointer   |<--------------------|  Spawn/Cursor    |
|  (brazo izq.)    |     cada frame       |  (posicion 3D)   |
+------------------+                      +------------------+

+------------------+     carga texturas   +------------------+
|  Friend.gd       |<--------------------|  user://friend/  |
|  (amigo reactivo)|                      |  (imagenes)      |
+--------+---------+                      +------------------+
         |
         | lee estado del juego
         v
+------------------+     configuracion    +------------------+
|  Game (HUD)      |-------------------->|  Rhythia.gd      |
|  energy, misses  |                      |  friend_position |
+------------------+                      +------------------+

+------------------+     activa/oculta    +------------------+
|  Editor Avatar   |-------------------->|  tempaccessories  |
|  (AddAccessory,  |     nodos hijos      |  tempshirts      |
|   AccessoryList) |                      |  (escenas)       |
+------------------+                      +------------------+
```
