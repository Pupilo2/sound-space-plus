# 12. Localización y Assets

## Visión general

Sound Space Plus (Rhythia) implementa un sistema de localización multi-idioma basado en archivos CSV nativos de Godot y organiza sus assets (~130 MB en total) en una estructura de directorios bien definida. El proyecto soporta cuatro idiomas (inglés, japonés, francés y español) y distribuye sus recursos entre texturas de UI, mundos 3D, efectos de sonido, fuentes tipográficas, shaders personalizados y más.

---

## Sistema de Localización

### Archivo CSV

El archivo principal de traducciones se encuentra en:

```
localization/localization.csv
```

Contiene **524 líneas** de claves de traducción organizadas en formato CSV con la siguiente estructura:

```csv
keys,en,ja,fr,es
ENGLISH,English,English,English,English
JAPANESE,日本語,日本語,日本語,日本語
Back,Back,戻る,Retour,Retroceder
Start!,Start!,スタート,Lancer !,¡Empezar!
```

La primera columna (`keys`) contiene el identificador de la cadena. Las columnas restantes contienen la traducción para cada idioma.

### Idiomas soportados

| Código | Idioma   | Ejemplo (`Start!`)  |
|--------|----------|----------------------|
| `en`   | Inglés   | `Start!`             |
| `ja`   | Japonés  | `スタート`            |
| `fr`   | Francés  | `Lancer !`           |
| `es`   | Español  | `¡Empezar!`          |

### Configuración en project.godot

La sección `[locale]` del archivo `project.godot` registra las traducciones compiladas:

```ini
[locale]
translations=PoolStringArray(
  "res://localization/localization.csv",
  "res://localization/localization.en.translation",
  "res://localization/localization.ja.translation",
  "res://localization/localization.fr.translation",
  "res://localization/localization.es.translation"
)
locale_filter=[ 0, [ "en", "ja" ] ]
```

Godot compila automáticamente el CSV en archivos `.translation` binarios (uno por idioma) durante la importación.

### Constante `Globals.locale`

En `scripts/Globals.gd` se define un arreglo constante con los códigos de idioma soportados:

```gdscript
const locale:Array = [
    "en",
    "ja",
    "fr",
    "es"
]
```

Este arreglo se usa para mapear el índice del idioma seleccionado por el usuario (almacenado en `Rhythia.language`) al código de locale correspondiente.

### Uso de `tr()` en GDScript

Para mostrar texto traducido en la interfaz, se utiliza la función integrada `tr()` de Godot, que busca la clave en las traducciones cargadas y devuelve la cadena en el idioma activo:

```gdscript
# Ejemplo de uso en scripts/ui/cmgr/AddSong.gd
$TxtFile/H/E/Info/Difficulty.text = tr("Difficulty") + ": " + tr(Globals.difficulty_names[song.difficulty])
$TxtFile/H/E/Info/Mapper.text = tr("Mapper") + ": %s" % song.creator

# Ejemplo en scripts/game/HUD.gd
if Rhythia.mod_nofail: ms += tr("[ NOFAIL ACTIVE ]") + "\n"
if Rhythia.mod_ghost: mods.append(tr("Ghost"))
if Rhythia.mod_chaos: mods.append(tr("Chaos"))
```

El idioma activo se establece mediante `TranslationServer`:

```gdscript
# En scripts/Rhythia.gd
TranslationServer.set_locale(Globals.locale[language])

# En scripts/ui/menu/languagemenu.gd
TranslationServer.set_locale(Globals.locale[Rhythia.language])
```

### Cómo agregar un nuevo idioma

1. Abrir `localization/localization.csv` y agregar una nueva columna con el código del idioma (por ejemplo, `de` para alemán).
2. Completar todas las filas con las traducciones correspondientes.
3. Agregar el código del idioma al arreglo `Globals.locale` en `scripts/Globals.gd`:
   ```gdscript
   const locale:Array = ["en", "ja", "fr", "es", "de"]
   ```
4. Reimportar el proyecto en Godot para que se genere el archivo `.translation` correspondiente.
5. Verificar que el archivo `.translation` generado se registre en `project.godot` bajo `[locale] > translations`.
6. Agregar la opción de selección del nuevo idioma en el menú de idiomas (`languagemenu`).

---

## Organización de Assets

### Tabla de directorios

| Directorio             | Tamaño aprox. | Contenido                                        |
|------------------------|---------------|--------------------------------------------------|
| `assets/images/`       | 38 MB         | Texturas de UI, branding, cursores, modificadores |
| `assets/worlds/`       | 61 MB         | Mundos/escenarios 3D del juego                   |
| `assets/sfx/`          | 7.9 MB        | Efectos de sonido y música de menú               |
| `assets/songs/`        | 14 MB         | Canciones incluidas de fábrica                   |
| `assets/font/`         | 18 MB         | Familias de fuentes tipográficas                 |
| `assets/notefx/`       | 253 KB        | Efectos de partículas para notas                 |
| `assets/meshes/`       | 222 KB        | Modelos 3D                                       |
| `assets/shaders/`      | 16 KB         | Shaders personalizados                           |
| `assets/blocks/`       | 76 KB         | Geometría de notas/bloques                       |
| `assets/accessories/`  | 185 KB        | Accesorios del avatar                            |
| `assets/animations/`   | ---           | Datos de animación                               |
| **Total**              | **~130 MB**   |                                                  |

### `assets/images/` (38 MB)

Contiene todas las texturas de la interfaz de usuario, organizadas en subdirectorios:

- **`branding/`**: Logotipos e íconos del proyecto (`icon.png`, `logo.png`, `splash.png`, `sspicon.png`).
- **`cursors/`**: Texturas de cursor personalizadas (`circle.png`).
- **`modifiers/`**: Íconos de modificadores de juego en múltiples resoluciones (`32/`, `64/`, `128/`, `512/`).
- **`ui/`**: Íconos de la interfaz general: favoritos, configuración, flechas, spinners, placeholders, errores, localización y más.
- **Raíz**: Texturas de approach (`approach.svg`), grid (`grid_inner.png`, `grid_outer.png`), spawn effect, tiles y transparente.

### `assets/worlds/` (61 MB)

Contiene los mundos/escenarios del juego. Cada mundo tiene su propio subdirectorio con escenas `.tscn`, scripts `.gd`, texturas y a veces meshes propios.

#### Lista completa de mundos

| Mundo                | Archivos principales                                    | Descripción                          |
|----------------------|---------------------------------------------------------|--------------------------------------|
| `baseplate`          | `baseplate.tscn`, `baseplate_night.tscn`, `skybox.png`  | Plataforma base con variante nocturna |
| `classic`            | `classic.tscn`, `classic.gd`, `classic.png`              | Mundo clásico de Sound Space         |
| `cubic`              | `cubic.tscn`, `cubic.gd`, `cubic_cube.gd`               | Entorno cúbico                       |
| `custom`             | `custom.tscn`, `custom.gd`, `custombg.gd`               | Mundo personalizable por el usuario   |
| `deep_space`         | `deep_space.tscn`, `deep_space.gd`                      | Espacio profundo                     |
| `event_horizon`      | `event_horizon.tscn`, `starmap.png`                      | Horizonte de eventos                 |
| `general`            | `space.gd`                                               | Script espacial general              |
| `grid`               | `grid.gd`, `grid.obj`, `cube.obj`, `cube.tscn`          | Mundo de cuadrícula                  |
| `neon_tunnel`        | `neon_tunnel.tscn`, `neon_tunnel.gd`, `ring.gd`         | Túnel de neón                        |
| `reality_dismissed`  | `reality_dismissed.tscn`, `reality_dismissed_dark.tscn`  | Realidad descartada (dos variantes)  |
| `space`              | `galaxy.tres`, `gradient.png`, `mk_rr_tour_dosei.png`   | Espacio con galaxia                  |
| `tri_tunnel`         | `tri_tunnel.tscn`, `tunnel.gd`, `tunnel.obj`            | Túnel triangular                     |
| `vaporwave`          | `vaporwave.tscn`, `scripts/`                             | Estética vaporwave                   |
| `void`               | `void.tscn`, `void.png`                                  | Vacío (fondo minimalista)            |

Archivos adicionales en la raíz de `assets/worlds/`:
- `pano.png` - Panorama genérico
- `seethrough.gd` / `seethrough.tscn` - Escena con efecto transparente

### `assets/sfx/` (7.9 MB)

Efectos de sonido del juego:

| Archivo             | Uso                                      |
|---------------------|------------------------------------------|
| `hit.wav`           | Sonido al acertar una nota               |
| `hit_old.wav`       | Sonido de acierto antiguo                |
| `miss.wav`          | Sonido al fallar una nota                |
| `fail.wav`          | Sonido de fallo/derrota                  |
| `beep.wav`          | Sonido de beep general                   |
| `button-16.wav`     | Sonido de botón de UI                    |
| `new_best.wav`      | Nueva mejor puntuación                   |
| `new_best_old.wav`  | Nueva mejor puntuación (versión antigua) |
| `menu_full.mp3`     | Música completa del menú                 |

Subdirectorio `music/`:
| Archivo             | Uso                          |
|---------------------|------------------------------|
| `menu_loop.ogg`     | Loop de música del menú      |
| `OLDmenu_loop.ogg`  | Loop de menú antiguo         |
| `cm.ogg`            | Música de content manager    |
| `error_loop.ogg`    | Loop de pantalla de error    |
| `yay.mp3`           | Efecto de celebración        |

### `assets/songs/` (14 MB)

Canciones y mapas incluidos de fábrica:

- `Meganeko - Feral (osu! edit).mp3` + `meganeko - Feral.txt`
- `MeteoricImpact.mp3` + `MeteoricImpact.txt`
- `BigShot.txt`
- `sexmode.mp3`
- `spamton_neo_mix_ex_wip.ogg`
- `built_in_maps.sspmr` - Registro de mapas incluidos

### `assets/font/` (18 MB)

Familias de fuentes tipográficas para soportar múltiples idiomas y estilos:

| Recurso                | Tipo                  | Uso                                    |
|------------------------|-----------------------|----------------------------------------|
| `Lato/`               | Directorio de fuente  | Fuente principal de UI                 |
| `Noto_Sans_JP/`       | Directorio de fuente  | Soporte para caracteres japoneses      |
| `Roboto/`             | Directorio de fuente  | Fuente alternativa de UI               |
| `UbuntuMono/`         | Directorio de fuente  | Fuente monoespaciada (consola)         |
| `bitmap/`             | Directorio            | Fuentes bitmap                         |
| `NotoColorEmoji.ttf`  | Archivo TTF           | Soporte para emojis a color            |
| `crypt.ttf`           | Archivo TTF           | Fuente decorativa                      |
| `main.ttf`            | Archivo TTF           | Fuente principal del juego             |
| `main.tres`           | Recurso Godot         | Configuración de fuente principal      |
| `console.tres`        | Recurso Godot         | Configuración de fuente de consola     |
| `debug.tres`          | Recurso Godot         | Configuración de fuente de depuración  |
| `debug2.tres`         | Recurso Godot         | Configuración de fuente de depuración 2|

### `assets/notefx/` (253 KB)

Efectos de partículas aplicados a las notas durante el juego:

| Directorio | Contenido                                          |
|------------|-----------------------------------------------------|
| `miss/`    | Efecto visual al fallar una nota                    |
| `ripple/`  | Efecto de ondulación al golpear                     |
| `score/`   | Efecto visual de puntuación al acertar              |
| `shards/`  | Fragmentos/partículas al destruir una nota          |

### `assets/meshes/` (222 KB)

Modelos 3D utilizados en el juego:

| Archivo              | Descripción                     |
|----------------------|---------------------------------|
| `Happy.obj`          | Modelo 3D decorativo            |
| `LowCube.obj`        | Cubo de baja poligonización     |
| `Material_46.material`| Material compartido             |

### `assets/blocks/` (76 KB)

Geometría de los bloques/notas del juego. Incluye múltiples formas:

| Archivo        | Forma                         |
|----------------|-------------------------------|
| `default.obj`  | Nota estándar                 |
| `cube.obj`     | Nota cúbica                   |
| `circle.obj`   | Nota circular                 |
| `rounded.obj`  | Nota redondeada               |
| `plane.obj`    | Nota plana                    |
| `quad.tres`    | Quad (recurso Godot)          |
| `mat_main.tres`| Material principal de notas   |

Cada `.obj` tiene su correspondiente archivo `.mtl` (material).

### `assets/accessories/` (185 KB)

Accesorios cosméticos para el avatar del jugador:

- `cubella_hair/` - Cabello estilo Cubella
- `alt_cubella_hair/` - Variante alternativa del cabello

### `assets/animations/`

Datos de animación en formato de recursos Godot:

| Archivo      | Descripción                    |
|--------------|--------------------------------|
| `Blink.tres` | Animación de parpadeo          |
| `Idle.tres`  | Animación de reposo            |
| `Pass.tres`  | Animación de paso/transición   |

---

## Shaders personalizados

El directorio `assets/shaders/` contiene tres shaders que añaden efectos visuales al juego:

### Tabla de shaders

| Archivo                   | Tipo           | Descripción                                    |
|---------------------------|----------------|------------------------------------------------|
| `sun.gdshader`            | `spatial`      | Efecto de sol con gradiente y líneas de corte   |
| `vertex_shader.gdshader`  | `spatial`      | Shader de vértices para la cuadrícula de notas  |
| `VHS.shader`              | `canvas_item`  | Efecto visual VHS/retro con grano de película   |

### `sun.gdshader` - Efecto de sol

Shader espacial que genera un sol estilizado con efecto de gradiente y líneas horizontales animadas.

- **Tipo**: `shader_type spatial`
- **Uniforms**: `time_float` (control de animación temporal)
- **Efecto**: Mezcla de colores amarillo-rojo con cutout animado que simula líneas de horizonte sobre el disco solar. Incluye un halo de brillo (glow) alrededor del sol.

### `vertex_shader.gdshader` - Shader de cuadrícula

Shader espacial complejo que deforma una cuadrícula 3D mediante ruido fractal (FBM) para crear un suelo animado.

- **Tipo**: `shader_type spatial`
- **Uniforms**: `noise` (textura de ruido), `time_float` (animación), `note_color_front` y `note_color_back` (colores de las notas)
- **Vertex**: Deforma los vértices usando FBM (Fractional Brownian Motion) para crear un terreno ondulante que se desplaza.
- **Fragment**: Renderiza una cuadrícula con iluminación dinámica que mezcla los colores de las notas según la distancia.

### `VHS.shader` - Efecto VHS/retro

Shader de canvas que simula la apariencia de una cinta VHS con múltiples capas de distorsión.

- **Tipo**: `shader_type canvas_item`
- **Origen**: Portado de Shadertoy por Ahopness (@ahopness), licencia CC0.
- **Uniforms configurables**:
  - `colored` - Habilitar ruido a color
  - `grain_amount` / `grain_size` - Control del grano de película
  - `tape_wave_amount` - Ondulación de cinta
  - `tape_crease_amount` - Pliegues de cinta
  - `color_displacement` - Desplazamiento cromático
  - `lines_velocity` - Velocidad de líneas de escaneo
- **Efectos**: Distorsión de cinta (tape wave), pliegues (tape crease), ruido de conmutación, bloom con desplazamiento cromático, latido AC y grano de película con ruido Perlin 3D.

---

## Sistema de Input

El mapa de inputs se define en la sección `[input]` de `project.godot`. Los controles están organizados por categoría funcional.

### Controles de juego

| Acción         | Tecla principal          | Alternativa             | Descripción                      |
|----------------|--------------------------|-------------------------|----------------------------------|
| `pause`        | `Espacio`                | `Escape`, Gamepad X     | Pausar/reanudar el juego         |
| `give_up`      | `R`                      | Gamepad B               | Abandonar la partida             |
| `fullscreen`   | `F11`                    | `Alt+Enter`             | Alternar pantalla completa       |

### Free Cam (Cámara libre)

| Acción                    | Tecla          | Alternativa          | Descripción                    |
|---------------------------|----------------|----------------------|--------------------------------|
| `fc_front`                | `W`            | Joystick arriba      | Mover cámara adelante          |
| `fc_back`                 | `S`            | Joystick abajo       | Mover cámara atrás             |
| `fc_left`                 | `A`            | Joystick izquierda   | Mover cámara a la izquierda    |
| `fc_right`                | `D`            | Joystick derecha     | Mover cámara a la derecha      |
| `fc_up`                   | `E`            | Gatillo derecho      | Mover cámara arriba            |
| `fc_down`                 | `Q`            | Gatillo izquierdo    | Mover cámara abajo             |
| `fc_trigger`              | Clic derecho   | ---                  | Disparador de cámara libre     |
| `debug_freecam_toggle`    | `O`            | ---                  | Activar/desactivar cámara libre|
| `debug_enable_mouse`      | `I`            | ---                  | Habilitar ratón en modo debug  |

### VR (Realidad Virtual)

| Acción            | Tecla     | Descripción                              |
|-------------------|-----------|------------------------------------------|
| `vr_switch_hands` | ---       | Cambiar mano dominante en VR             |
| `vr_click`        | ---       | Clic en modo VR                          |

### Menú y navegación

| Acción             | Tecla               | Alternativa          | Descripción                      |
|--------------------|----------------------|----------------------|----------------------------------|
| `menu_click`       | Clic izquierdo       | Gamepad A            | Clic en menús                    |
| `menu_quickbar`    | `Escape`             | Gamepad Select       | Abrir barra rápida               |
| `retry`            | `` ` `` (acento)     | ---                  | Reintentar mapa                  |
| `ui_quicksettings` | `Ctrl+O`             | Gamepad D-Pad arriba | Abrir ajustes rápidos            |
| `toggle_mouse_lock`| Clic derecho         | ---                  | Bloquear/desbloquear ratón       |

### Joystick (navegación con gamepad)

| Acción       | Entrada                                      | Descripción                 |
|--------------|----------------------------------------------|-----------------------------|
| `joy_up`     | Eje Y izq. arriba / Eje Y der. arriba       | Navegar arriba              |
| `joy_down`   | Eje Y izq. abajo / Eje Y der. abajo         | Navegar abajo               |
| `joy_left`   | Eje X izq. izquierda / Eje X der. izquierda | Navegar a la izquierda      |
| `joy_right`  | Eje X izq. derecha / Eje X der. derecha      | Navegar a la derecha        |

### Debug y herramientas

| Acción          | Tecla               | Descripción                             |
|-----------------|----------------------|-----------------------------------------|
| `console`       | `Shift+\`            | Abrir consola de depuración             |
| `fps`           | `F3`                 | Mostrar contador de FPS                 |
| `skip_convert`  | `Ctrl+M`             | Saltar conversión de mapas              |
| `warning_test`  | `Alt+Shift+W`        | Disparar advertencia de prueba          |
| `debug_notify`  | ---                  | Notificación de depuración              |

### Arcade Wheel (Rueda arcade)

| Acción  | Tecla física | Descripción              |
|---------|--------------|--------------------------|
| `arcw1` | `A`          | Botón 1 de rueda arcade  |
| `arcw2` | `R`          | Botón 2 de rueda arcade  |
| `arcw3` | `C`          | Botón 3 de rueda arcade  |
| `arcw4` | `W`          | Botón 4 de rueda arcade  |

> **Nota**: Las acciones de Arcade Wheel usan `physical_scancode` en lugar de `scancode`, lo que significa que responden a la posición física de la tecla independientemente del layout del teclado.

---

## Recursos de Godot (raíz del proyecto)

El directorio raíz del proyecto contiene archivos de recursos `.tres` que definen configuraciones globales:

| Archivo                   | Descripción                                                    |
|---------------------------|----------------------------------------------------------------|
| `default_bus_layout.tres` | Layout de buses de audio (master, efectos, música, etc.)       |
| `default_env.tres`        | Configuración del entorno 3D predeterminado (cielo, iluminación)|
| `uitheme.tres`            | Tema de UI global (colores, fuentes, estilos de controles)     |
| `galaxymesh.tres`         | Mesh de la galaxia usada en los mundos espaciales              |

---

## Diagrama de estructura de assets

```
assets/
├── accessories/          # Accesorios del avatar (185 KB)
│   ├── cubella_hair/
│   └── alt_cubella_hair/
├── animations/           # Animaciones (Blink, Idle, Pass)
├── blocks/               # Geometría de notas (76 KB)
│   ├── default.obj
│   ├── cube.obj
│   ├── circle.obj
│   ├── rounded.obj
│   └── plane.obj
├── font/                 # Fuentes tipográficas (18 MB)
│   ├── Lato/
│   ├── Noto_Sans_JP/
│   ├── Roboto/
│   ├── UbuntuMono/
│   └── bitmap/
├── images/               # Texturas de UI (38 MB)
│   ├── branding/
│   ├── cursors/
│   ├── modifiers/
│   └── ui/
├── meshes/               # Modelos 3D (222 KB)
├── notefx/               # Efectos de partículas (253 KB)
│   ├── miss/
│   ├── ripple/
│   ├── score/
│   └── shards/
├── sfx/                  # Efectos de sonido (7.9 MB)
│   └── music/
├── shaders/              # Shaders personalizados (16 KB)
│   ├── sun.gdshader
│   ├── vertex_shader.gdshader
│   └── VHS.shader
├── songs/                # Canciones de fábrica (14 MB)
└── worlds/               # Mundos del juego (61 MB)
    ├── baseplate/
    ├── classic/
    ├── cubic/
    ├── custom/
    ├── deep_space/
    ├── event_horizon/
    ├── general/
    ├── grid/
    ├── neon_tunnel/
    ├── reality_dismissed/
    ├── space/
    ├── tri_tunnel/
    ├── vaporwave/
    └── void/
```
