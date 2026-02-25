# 06 - Sistema de Configuracion

> Documentacion de arquitectura para **Sound Space Plus (Rhythia)** - Motor: Godot 3.x

---

## Indice

1. [Vision general](#vision-general)
2. [Arquitectura de Settings](#arquitectura-de-settings)
   - [Patron de script individual](#patron-de-script-individual)
   - [Componentes base reutilizables](#componentes-base-reutilizables)
   - [Escena de pagina de settings](#escena-de-pagina-de-settings)
3. [Categorias de Settings](#categorias-de-settings)
   - [Notas y Approach](#notas-y-approach)
   - [Camara y Parallax](#camara-y-parallax)
   - [Cursor](#cursor)
   - [Audio](#audio)
   - [HUD e Interfaz](#hud-e-interfaz)
   - [Colores del HUD](#colores-del-hud)
   - [Modificadores](#modificadores)
   - [Replays](#replays)
   - [Graficos y Shaders](#graficos-y-shaders)
   - [Avanzado y Sistema](#avanzado-y-sistema)
   - [Contenido y Utilidades](#contenido-y-utilidades)
4. [Tabla completa de scripts de settings](#tabla-completa-de-scripts-de-settings)
5. [Persistencia](#persistencia)
   - [Formato JSON](#formato-json)
   - [Carga de settings](#carga-de-settings)
   - [Guardado de settings](#guardado-de-settings)
   - [Valores por defecto](#valores-por-defecto)
   - [Perfiles de configuracion](#perfiles-de-configuracion)
   - [Formato binario legacy](#formato-binario-legacy)
6. [Senales relacionadas](#senales-relacionadas)
7. [Diagrama de flujo de datos](#diagrama-de-flujo-de-datos)
8. [Referencia adicional](#referencia-adicional)

---

## Vision general

El sistema de configuracion de Sound Space Plus permite al jugador personalizar practicamente todos los aspectos del juego: desde parametros visuales de las notas hasta controles de camara, modificadores de gameplay, colores del HUD y opciones avanzadas de rendimiento.

El sistema se estructura alrededor de tres pilares:

1. **`Rhythia.gd` (Autoload)**: Almacena todas las variables de configuracion como propiedades del singleton global. Actua como fuente de verdad unica (single source of truth).
2. **Scripts individuales en `scripts/ui/settings/`**: Cada control de la UI de settings tiene su propio script que sincroniza bidirecionalmente el valor del widget con la propiedad correspondiente en `Rhythia`.
3. **Persistencia en `user://settings.json`**: Al salir de la pantalla de settings (o al cerrar el juego fuera de modo debug), los valores actuales se serializan a un archivo JSON en el directorio de usuario.

---

## Arquitectura de Settings

### Patron de script individual

Cada setting sigue un patron comun. La mayoria de los scripts extienden `SpinBox`, `CheckBox`, `MenuButton` u otro control de Godot, y siguen este ciclo de vida:

```
_ready()     --> Lee el valor actual de Rhythia y lo asigna al widget
_process()   --> Detecta si el valor del widget difiere de Rhythia y llama a upd()
upd()        --> Escribe el valor del widget en la propiedad de Rhythia
```

**Ejemplo tipico** (`ApproachRate.gd`):

```gdscript
extends SpinBox

func upd():
    Rhythia.approach_rate = value

func _process(_d):
    if value != Rhythia.approach_rate: upd()

func _ready():
    value = Rhythia.approach_rate
    connect("changed", self, "upd")
```

Este patron garantiza que:
- El widget refleja siempre el estado real del juego al abrirse.
- Los cambios del usuario se propagan inmediatamente a `Rhythia`.
- Si algo externo cambia el valor en `Rhythia` (p. ej. un preset de camara), el widget se actualiza en el siguiente frame via `_process()`.

### Componentes base reutilizables

Ademas de los scripts especificos, existen componentes genericos que evitan la duplicacion de codigo:

| Script | Extiende | Proposito |
|--------|----------|-----------|
| `SettingsCheckbox.gd` | `CheckBox` | Checkbox generico. Usa `export(String) var target` para apuntar a cualquier propiedad booleana de `Rhythia`. |
| `SettingsNumberBox.gd` | `SpinBox` | SpinBox generico. Usa `export(String) var target` para apuntar a cualquier propiedad numerica de `Rhythia`. |
| `SettingsColorPicker.gd` | `ColorPickerButton` | Color picker generico. Usa `export(String) var target` para apuntar a cualquier propiedad `Color` de `Rhythia`. |
| `EnumDropdownMenu.gd` | `MenuButton` | Dropdown generico para valores enumerados. Usa `export(Array,String) var options` y `export(String) var target`. |
| `SettingsGroup.gd` | `VBoxContainer` | Contenedor colapsable de settings. Tiene un boton de titulo que muestra/oculta el grupo. |

Estos componentes genericos se configuran desde el editor de Godot mediante propiedades `export`, lo que permite agregar nuevos settings sin escribir scripts adicionales.

### Escena de pagina de settings

La interfaz de settings se construye en la escena:

```
prefabs/menu/settings_page.tscn
```

Esta escena (92 load steps) contiene:
- Todos los scripts de settings referenciados como `ext_resource`
- Controles organizados en secciones/grupos dentro de un `VBoxContainer` scrollable
- Fuentes personalizadas (Lato, Noto Sans JP, Noto Color Emoji)
- Un tema UI compartido (`uitheme.tres`)

Cada control (SpinBox, CheckBox, MenuButton, etc.) tiene asignado su script correspondiente de `scripts/ui/settings/`, que se encarga de la logica de sincronizacion con `Rhythia`.

---

## Categorias de Settings

### Notas y Approach

Controlan como se muestran y comportan las notas al acercarse a la grilla.

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `ApproachRate.gd` | `approach_rate` | `40` | Velocidad a la que las notas se acercan a la grilla (m/s) |
| `SpawnDist.gd` | `spawn_distance` | `40` | Distancia desde la grilla a la que aparecen las notas (metros) |
| `FadeLength.gd` | `fade_length` | `0.5` (50%) | Porcentaje de la distancia de spawn en que las notas se desvanecen de invisible a opaco |
| `NoteScale.gd` | `note_size` | `1` | Escala visual de las notas |
| `NoteOpacity.gd` | `note_opacity` | `1` (100%) | Opacidad maxima de las notas |
| `NoteSpin.gd` | `note_spin_x/y/z` | `0` | Rotacion continua de las notas en cada eje (X, Y, Z). Un solo script maneja los 3 ejes basandose en el nombre del nodo. |
| `NoteMesh.gd` | `selected_mesh` | (registro) | Seleccion de la mesh 3D utilizada para las notas. Se lee del `registry_mesh`. |
| `NoteHitboxSize.gd` | `note_hitbox_size` | `1.140` | Tamano del hitbox de las notas |
| `HitWindow.gd` | `hitwindow_ms` | `55` | Ventana de tiempo para acertar una nota (ms) |

> **Nota**: Los valores de distancia/velocidad en SSP son la mitad de los de Vulnus y Sound Space. Ver la seccion de conversion en `docs/SettingsManual.md`.

### Camara y Parallax

Controlan el comportamiento de la camara, parallax y campo de vision.

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `Parallax.gd` | `parallax` | `6.5` | Parallax de la camara principal. Afecta mundo 3D, HUD y notas. |
| `UIParallax.gd` | `ui_parallax` | `1.63` | Parallax solo de los elementos de UI del HUD |
| `GridParallax.gd` | `grid_parallax` | `0` | Parallax solo de la grilla y las notas |
| `fov.gd` | `fov` | `70` | Campo de vision de la camara (grados) |
| `HitFOVAmplifier.gd` | `hit_fov_amplifier` | `2` | Amplificador del efecto de FOV al acertar notas |
| `HitFOVDecay.gd` | `hit_fov_decay` | `20` | Velocidad de decaimiento del efecto de FOV |
| `HitFOVModes.gd` | `hit_fov_additive`, `hit_fov_exponential` | Additive: `true`, Exp: `false` | Modo del efecto de FOV: Normal, Additive o Exponential |
| `CameraPresets.gd` | (multiples) | -- | Dropdown con presets de camara: Half-lock, Full-lock, Spin, Reverse-lock, etc. Modifica parallax, ui_parallax, grid_parallax, cam_unlock y faraway_hud de golpe. |

#### Presets de camara disponibles

| Preset | Cam Parallax | UI Parallax | Grid Parallax | Spin | Faraway |
|--------|-------------|-------------|---------------|------|---------|
| Half-lock | 10 | 2.28 | 0 | No | No |
| Full-lock | 0 | 0 | 0 | No | No |
| Reverse-lock | 10 | -2.28 | 0 | No | No |
| Spin | 10 | 0 | 0 | Si | Si |
| Half-lock (faraway) | 10 | 0 | 0 | No | Si |
| Full-lock (faraway) | 0 | 0 | 0 | No | Si |
| Reverse-lock (faraway) | 10 | 0 | 0 | No | Si |
| Spin-lock (mid-pivot) | 0 | -89.6 | -44.8 | Si | Si |

### Cursor

Configuracion del cursor, trail y sensibilidad.

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `Sensitivity.gd` | `sensitivity` | `0.5` | Sensibilidad del mouse |
| `CursorScale.gd` | `cursor_scale` | `1` | Escala visual del cursor |
| `CursorSpin.gd` | `cursor_spin` | `0` | Velocidad de rotacion del cursor |
| `CursorTrailType.gd` | `trail_mode_scale`, `trail_mode_opacity` | Ambos: `true` | Tipo de trail: Normal (ambos), Solo escala, Solo opacidad |
| `TrailDetail.gd` | `trail_detail` | `10` | Cantidad de segmentos del trail del cursor |
| `TrailTime.gd` | `trail_time` | `0.15` | Duracion del trail del cursor (segundos) |
| `InvertMouse.gd` | `invert_mouse` | `false` | Invierte el eje del mouse. Emite `mods_changed`. |
| `LockMouseResize.gd` | `absolute_scale` | `1` | Escala del modo de mouse absoluto |
| `EdgeBuffer.gd` | `edge_drift` | `0` | Buffer en los bordes para el drift del cursor |

### Audio

Configuracion de volumen y efectos de sonido.

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `VolumeSetting.gd` | (bus de audio) | Variable | Control generico de volumen. Se configura via `export(String) var target_bus` para apuntar a los buses: Master, Music, HitSound, MissSound, FailSound, PBSound. Permite ajustar tanto en porcentaje como en dB. |
| `MusicVolumeSetter.gd` | `music_volume_db` | `0` | Nodo `AudioStreamPlayer` que escucha la senal `volume_changed` y aplica el volumen de musica con interpolacion suave. |
| `MusicOffset.gd` | `music_offset` | `0` | Offset de sincronizacion de la musica (ms) |

### HUD e Interfaz

Controlan la visibilidad y comportamiento de los elementos del HUD durante el gameplay.

Muchos de estos se configuran via los componentes genericos `SettingsCheckbox.gd` y `SettingsNumberBox.gd` directamente en la escena, apuntando a las siguientes variables en `Rhythia`:

| Variable en `Rhythia` | Valor por defecto | Descripcion |
|-----------------------|-------------------|-------------|
| `show_config` | `true` | Mostrar configuracion en el HUD |
| `enable_grid` | `false` | Mostrar grilla visual |
| `enable_border` | `true` | Mostrar borde de la grilla |
| `show_hp_bar` | `true` | Mostrar barra de vida |
| `show_timer` | `true` | Mostrar temporizador de progreso |
| `show_left_panel` | `true` | Mostrar panel izquierdo del HUD |
| `show_right_panel` | `true` | Mostrar panel derecho del HUD |
| `show_accuracy_bar` | `true` | Mostrar barra de precision |
| `show_letter_grade` | `true` | Mostrar letra de calificacion |
| `attach_hp_to_grid` | `false` | Anclar barra de vida a la grilla 3D |
| `attach_timer_to_grid` | `false` | Anclar temporizador a la grilla 3D |
| `simple_hud` | `false` | HUD simplificado |
| `faraway_hud` | `true` | HUD alejado (perspectiva lejana) |
| `display_true_combo` | `true` | Mostrar combo verdadero |
| `rainbow_grid` | `false` | Grilla con efecto arcoiris |
| `rainbow_hud` | `false` | HUD con efecto arcoiris |
| `play_menu_music` | `true` | Reproducir musica de fondo en el menu |
| `language` | `0` | Idioma de la interfaz (indice en `Globals.locale`) |

### Colores del HUD

Gestionados por `SettingsColorPicker.gd` (generico) y `ColorPresets.gd` para presets predefinidos.

| Script | Proposito |
|--------|-----------|
| `ColorPresets.gd` | Dropdown con presets de color: "Classic" (colores claros sobre fondo oscuro) e "Inverted" (colores oscuros sobre fondo claro). Aplica todos los colores del HUD de golpe. |
| `ColorSet.gd` | Selector visual de conjuntos de colores de notas (colorsets). Muestra una grilla con todos los colorsets registrados en `registry_colorset`. |

Las propiedades de color en `Rhythia` incluyen:

- `panel_bg`, `panel_text` -- Fondo y texto del panel
- `unpause_fill_color`, `unpause_empty_color` -- Barra de des-pausa
- `how_to_quit` -- Texto de instrucciones de salida
- `combo_fill_color`, `combo_empty_color` -- Barra de combo
- `acc_fill_color`, `acc_empty_color` -- Barra de precision
- `giveup_text`, `giveup_fill_color`, `giveup_fill_color_end_skip` -- UI de rendicion
- `timer_text`, `timer_fg`, `timer_bg` (+ variantes `_done`, `_canskip`) -- Temporizador
- `miss_flash_color`, `pause_used_color` -- Flash de miss y pausas usadas
- `miss_text_color`, `pause_text_color`, `score_text_color` -- Textos
- `grade_ss_saturation`, `grade_ss_value`, `grade_ss_shine` -- Grado SS (arcoiris)
- `grade_s_color`, `grade_s_shine` -- Grado S
- `grade_a_color` a `grade_f_color` -- Grados A-F
- `cursor_color` -- Color del cursor
- `pause_ui_opacity` -- Opacidad de la UI de pausa

### Modificadores

Los modificadores no tienen scripts de UI dedicados en `scripts/ui/settings/` sino que se manejan desde la pantalla de modificadores del juego. Sin embargo, el valor de velocidad personalizada si tiene su script:

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `CustomSpeed.gd` | `custom_speed` | `1` (100%) | Velocidad personalizada. El widget muestra porcentaje (value/100). |

Las propiedades de modificadores en `Rhythia` (todas con `setget` que emiten `mods_changed`):

| Modificador | Variable | Valor por defecto |
|-------------|----------|-------------------|
| Extra Energy | `mod_extra_energy` | `false` |
| No Regen | `mod_no_regen` | `false` |
| Speed Level | `mod_speed_level` | `SPEED_NORMAL` |
| No Fail | `mod_nofail` | `false` |
| Mirror X | `mod_mirror_x` | `false` |
| Mirror Y | `mod_mirror_y` | `false` |
| Nearsighted | `mod_nearsighted` | `false` |
| Ghost | `mod_ghost` | `false` |
| Sudden Death | `mod_sudden_death` | `false` |
| Chaos | `mod_chaos` | `false` |
| Earthquake | `mod_earthquake` | `false` |
| Flashlight | `mod_flashlight` | `false` |
| Hard Rock | `mod_hardrock` | `false` |
| Invert Mouse | `invert_mouse` | `false` |
| Health Model | `health_model` | `HP_SOUNDSPACE` |
| Visual Mode | `visual_mode` | `false` |
| Disable Pausing | `disable_pausing` | `false` |
| Speed Hitwindow | `speed_hitwindow` | `true` |
| Restart on Death | `restart_on_death` | `false` |

### Replays

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `ReplayMode.gd` | `record_mode` | `1` | Modo de grabacion de replays (OptionButton con IDs) |
| `ReplayLimit.gd` | `record_limit` | `0` | Limite de replays almacenados |
| `ReplayDir.gd` | -- | -- | Boton para abrir la carpeta `user://replays/` en el explorador de archivos |
| `ReplayIntro.gd` | -- | -- | Boton para ir a la escena de intro (`Intro.tscn`) |

### Graficos y Shaders

| Script | Variable en `Rhythia` | Valor por defecto | Descripcion |
|--------|-----------------------|-------------------|-------------|
| `Glow.gd` | `glow` | `0` | Intensidad del efecto glow |
| `Bloom.gd` | `bloom` | `0` | Intensidad del efecto bloom |
| `RenderScale.gd` | `render_scale` | `1` | Escala de renderizado (afecta resolucion interna). Nota: el `_ready()` esta comentado, por lo que este control puede estar deshabilitado. |

### Avanzado y Sistema

| Script | Variable en `Rhythia` / API | Valor por defecto | Descripcion |
|--------|-----------------------------|-------------------|-------------|
| `Fullscreen.gd` | `OS.window_fullscreen` | `false` | Alterna pantalla completa. Solo visible en PC. |
| `VSync.gd` | `OS.vsync_enabled` | (sistema) | Alterna VSync |
| `TargetFPS.gd` | `Engine.target_fps` | (sistema) | FPS objetivo. Minimo 15 (excepto 0 = ilimitado). |
| `SaveSettings.gd` | `Rhythia.save_settings()` | -- | Boton de guardado manual. Solo visible en modo debug. Al salir del arbol (`_exit_tree`), guarda automaticamente si no es debug. |

### Contenido y Utilidades

| Script | Proposito |
|--------|-----------|
| `HitEffect.gd` | Selector de efectos visuales de acertar notas. Lee del `registry_effect`. |
| `MissEffect.gd` | Selector de efectos visuales de fallar notas. Lee del `registry_effect`. |
| `WorldSel.gd` | Selector de mundo de fondo. Lee del `registry_world`. |
| `Profiles.gd` | Gestor de perfiles de configuracion. Permite crear, cargar, sobreescribir y eliminar perfiles (archivos `*.settings.json` en `user://`). |
| `ReplaceCustomFile.gd` | Permite reemplazar archivos personalizados (cursor, etc.) con imagenes del usuario. Soporta PNG, JPG, JPEG, WEBP, BMP. |
| `ReloadContent.gd` | Boton para recargar todo el contenido (vuelve a `init.tscn`). Muestra confirmacion previa. |
| `ArchiveConvert.gd` | Boton para convertir el archivo SS Archive. Requiere 8 GB de espacio. |
| `UserDir.gd` | Boton para abrir la carpeta `user://` en el explorador. Deshabilitado en Android. |
| `ToAvEditor.gd` | Boton para navegar al editor de avatar (`AvatarEditor.tscn`). |

---

## Tabla completa de scripts de settings

| # | Script | Ruta completa | Extiende | Categoria | Variable/Accion |
|---|--------|---------------|----------|-----------|-----------------|
| 1 | `ApproachRate.gd` | `scripts/ui/settings/ApproachRate.gd` | `SpinBox` | Notas | `Rhythia.approach_rate` |
| 2 | `ArchiveConvert.gd` | `scripts/ui/settings/ArchiveConvert.gd` | `Button` | Utilidades | Convierte SS Archive |
| 3 | `Bloom.gd` | `scripts/ui/settings/Bloom.gd` | `SpinBox` | Graficos | `Rhythia.bloom` |
| 4 | `CameraPresets.gd` | `scripts/ui/settings/CameraPresets.gd` | `MenuButton` | Camara | Presets de camara (parallax, spin, faraway) |
| 5 | `ColorPresets.gd` | `scripts/ui/settings/ColorPresets.gd` | `MenuButton` | Colores | Presets de colores del HUD |
| 6 | `ColorSet.gd` | `scripts/ui/settings/ColorSet.gd` | `GridContainer` | Colores | Selector de colorsets de notas |
| 7 | `CursorScale.gd` | `scripts/ui/settings/CursorScale.gd` | `SpinBox` | Cursor | `Rhythia.cursor_scale` |
| 8 | `CursorSpin.gd` | `scripts/ui/settings/CursorSpin.gd` | `SpinBox` | Cursor | `Rhythia.cursor_spin` |
| 9 | `CursorTrailType.gd` | `scripts/ui/settings/CursorTrailType.gd` | `MenuButton` | Cursor | `Rhythia.trail_mode_scale/opacity` |
| 10 | `CustomSpeed.gd` | `scripts/ui/settings/CustomSpeed.gd` | `SpinBox` | Modificadores | `Rhythia.custom_speed` |
| 11 | `EdgeBuffer.gd` | `scripts/ui/settings/EdgeBuffer.gd` | `SpinBox` | Cursor | `Rhythia.edge_drift` |
| 12 | `EnumDropdownMenu.gd` | `scripts/ui/settings/EnumDropdownMenu.gd` | `MenuButton` | Base/Generico | Dropdown generico para enums |
| 13 | `FadeLength.gd` | `scripts/ui/settings/FadeLength.gd` | `SpinBox` | Notas | `Rhythia.fade_length` |
| 14 | `fov.gd` | `scripts/ui/settings/fov.gd` | `SpinBox` | Camara | `Rhythia.fov` |
| 15 | `Fullscreen.gd` | `scripts/ui/settings/Fullscreen.gd` | `CheckBox` | Sistema | `OS.window_fullscreen` |
| 16 | `Glow.gd` | `scripts/ui/settings/Glow.gd` | `SpinBox` | Graficos | `Rhythia.glow` |
| 17 | `GridParallax.gd` | `scripts/ui/settings/GridParallax.gd` | `SpinBox` | Camara | `Rhythia.grid_parallax` |
| 18 | `HitEffect.gd` | `scripts/ui/settings/HitEffect.gd` | `MenuButton` | Contenido | Seleccion de hit effect |
| 19 | `HitFOVAmplifier.gd` | `scripts/ui/settings/HitFOVAmplifier.gd` | `SpinBox` | Camara | `Rhythia.hit_fov_amplifier` |
| 20 | `HitFOVDecay.gd` | `scripts/ui/settings/HitFOVDecay.gd` | `SpinBox` | Camara | `Rhythia.hit_fov_decay` |
| 21 | `HitFOVModes.gd` | `scripts/ui/settings/HitFOVModes.gd` | `MenuButton` | Camara | Modo de Hit FOV (Normal/Additive/Exponential) |
| 22 | `HitWindow.gd` | `scripts/ui/settings/HitWindow.gd` | `SpinBox` | Notas | `Rhythia.hitwindow_ms` |
| 23 | `InvertMouse.gd` | `scripts/ui/settings/InvertMouse.gd` | `CheckBox` | Cursor | `Rhythia.invert_mouse` |
| 24 | `LockMouseResize.gd` | `scripts/ui/settings/LockMouseResize.gd` | `SpinBox` | Cursor | `Rhythia.absolute_scale` |
| 25 | `MissEffect.gd` | `scripts/ui/settings/MissEffect.gd` | `MenuButton` | Contenido | Seleccion de miss effect |
| 26 | `MusicOffset.gd` | `scripts/ui/settings/MusicOffset.gd` | `SpinBox` | Audio | `Rhythia.music_offset` |
| 27 | `MusicVolumeSetter.gd` | `scripts/ui/settings/MusicVolumeSetter.gd` | `AudioStreamPlayer` | Audio | Aplica volumen con interpolacion |
| 28 | `NoteHitboxSize.gd` | `scripts/ui/settings/NoteHitboxSize.gd` | `SpinBox` | Notas | `Rhythia.note_hitbox_size` |
| 29 | `NoteMesh.gd` | `scripts/ui/settings/NoteMesh.gd` | `MenuButton` | Contenido | Seleccion de mesh de notas |
| 30 | `NoteOpacity.gd` | `scripts/ui/settings/NoteOpacity.gd` | `SpinBox` | Notas | `Rhythia.note_opacity` |
| 31 | `NoteScale.gd` | `scripts/ui/settings/NoteScale.gd` | `SpinBox` | Notas | `Rhythia.note_size` |
| 32 | `NoteSpin.gd` | `scripts/ui/settings/NoteSpin.gd` | `SpinBox` | Notas | `Rhythia.note_spin_x/y/z` |
| 33 | `Parallax.gd` | `scripts/ui/settings/Parallax.gd` | `SpinBox` | Camara | `Rhythia.parallax` |
| 34 | `Profiles.gd` | `scripts/ui/settings/Profiles.gd` | `MenuButton` | Sistema | Perfiles de configuracion |
| 35 | `ReloadContent.gd` | `scripts/ui/settings/ReloadContent.gd` | `Button` | Utilidades | Recarga todo el contenido |
| 36 | `RenderScale.gd` | `scripts/ui/settings/RenderScale.gd` | `SpinBox` | Graficos | `Rhythia.render_scale` |
| 37 | `ReplaceCustomFile.gd` | `scripts/ui/settings/ReplaceCustomFile.gd` | `Button` | Contenido | Reemplazar assets personalizados |
| 38 | `ReplayDir.gd` | `scripts/ui/settings/ReplayDir.gd` | `Button` | Replays | Abre carpeta de replays |
| 39 | `ReplayIntro.gd` | `scripts/ui/settings/ReplayIntro.gd` | `Node` | Replays | Navega a la intro |
| 40 | `ReplayLimit.gd` | `scripts/ui/settings/ReplayLimit.gd` | `OptionButton` | Replays | `Rhythia.record_limit` |
| 41 | `ReplayMode.gd` | `scripts/ui/settings/ReplayMode.gd` | `OptionButton` | Replays | `Rhythia.record_mode` |
| 42 | `SaveSettings.gd` | `scripts/ui/settings/SaveSettings.gd` | `Button` | Sistema | Guarda settings manualmente |
| 43 | `Sensitivity.gd` | `scripts/ui/settings/Sensitivity.gd` | `SpinBox` | Cursor | `Rhythia.sensitivity` |
| 44 | `SettingsCheckbox.gd` | `scripts/ui/settings/SettingsCheckbox.gd` | `CheckBox` | Base/Generico | Checkbox generico (export target) |
| 45 | `SettingsColorPicker.gd` | `scripts/ui/settings/SettingsColorPicker.gd` | `ColorPickerButton` | Base/Generico | Color picker generico (export target) |
| 46 | `SettingsGroup.gd` | `scripts/ui/settings/SettingsGroup.gd` | `VBoxContainer` | Base/Generico | Grupo colapsable de settings |
| 47 | `SettingsNumberBox.gd` | `scripts/ui/settings/SettingsNumberBox.gd` | `SpinBox` | Base/Generico | SpinBox generico (export target) |
| 48 | `SpawnDist.gd` | `scripts/ui/settings/SpawnDist.gd` | `SpinBox` | Notas | `Rhythia.spawn_distance` |
| 49 | `TargetFPS.gd` | `scripts/ui/settings/TargetFPS.gd` | `SpinBox` | Sistema | `Engine.target_fps` |
| 50 | `ToAvEditor.gd` | `scripts/ui/settings/ToAvEditor.gd` | `Button` | Utilidades | Navega al avatar editor |
| 51 | `TrailDetail.gd` | `scripts/ui/settings/TrailDetail.gd` | `SpinBox` | Cursor | `Rhythia.trail_detail` |
| 52 | `TrailTime.gd` | `scripts/ui/settings/TrailTime.gd` | `SpinBox` | Cursor | `Rhythia.trail_time` |
| 53 | `UIParallax.gd` | `scripts/ui/settings/UIParallax.gd` | `SpinBox` | Camara | `Rhythia.ui_parallax` |
| 54 | `UserDir.gd` | `scripts/ui/settings/UserDir.gd` | `Button` | Utilidades | Abre carpeta de usuario |
| 55 | `VolumeSetting.gd` | `scripts/ui/settings/VolumeSetting.gd` | `Control` | Audio | Control de volumen por bus (% y dB) |
| 56 | `VSync.gd` | `scripts/ui/settings/VSync.gd` | `CheckBox` | Sistema | `OS.vsync_enabled` |
| 57 | `WorldSel.gd` | `scripts/ui/settings/WorldSel.gd` | `MenuButton` | Contenido | Seleccion de mundo de fondo |

---

## Persistencia

### Formato JSON

Los settings se persisten en un archivo JSON ubicado en:

```
user://settings.json
```

El archivo contiene un diccionario con todas las claves de configuracion serializadas. Ejemplo parcial:

```json
{
    "approach_rate": 40,
    "sensitivity": 0.5,
    "play_hit_snd": true,
    "play_miss_snd": true,
    "selected_colorset": "ssp_cottoncandy",
    "parallax": 6.5,
    "fov": 70,
    "master_volume": -6.02,
    "cursor_color": "ffffff",
    "language": 0,
    "glow": 0,
    "bloom": 0
}
```

Los valores de `Color` se serializan como strings hexadecimales HTML (sin alfa si alfa == 1). Los floats especiales (`NaN`, `+Inf`, `-Inf`) se manejan con funciones auxiliares `ser_float()` y `dser_float()`.

### Carga de settings

La funcion `Rhythia.load_saved_settings()` se invoca durante la inicializacion (`init.tscn`):

```gdscript
func load_saved_settings(saveFile:String = Globals.p("user://settings.json")):
```

**Proceso de carga:**

1. Abre el archivo JSON con `File.open()`
2. Parsea el contenido con `JSON.parse()`
3. Para cada clave conocida, verifica si existe en el diccionario con `data.has("clave")`
4. Si existe, asigna el valor a la propiedad correspondiente de `Rhythia`
5. Los colores se cargan con la funcion auxiliar `lcol()` que valida la conversion
6. Los items de registro (colorset, mesh, world, effects) se buscan por ID en sus respectivos registros
7. Los volumenes de audio se establecen directamente en los buses de `AudioServer`

**Codigos de error de carga:**

| Codigo | Significado |
|--------|-------------|
| `0` | Exito |
| `-1` | Forzado por Ctrl+L (debug) |
| `-2` | Error al abrir archivo |
| `-100 - N` | Error de parsing JSON en linea N |

### Guardado de settings

La funcion `Rhythia.save_settings()` serializa todos los valores actuales:

```gdscript
func save_settings(saveFile:String = Globals.p("user://settings.json")):
```

**Proceso de guardado:**

1. Abre el archivo con `File.open()` en modo escritura
2. Construye un diccionario con todas las propiedades de configuracion
3. Los colores se serializan con `scol()` (a HTML hex)
4. Los volumenes de audio se leen de los buses de `AudioServer` y se serializan con `ser_float()`
5. Los IDs de registros (colorset, mesh, world, effects) se guardan como strings
6. Se escribe el JSON con indentacion de tabulador: `JSON.print(data, "\t")`

**Cuando se guarda automaticamente:**

- Al salir de la pagina de settings (via `SaveSettings.gd._exit_tree()`) si no es modo debug
- Al cargar un perfil de settings (se guarda como `user://settings.json`)
- Al convertir desde formato binario legacy

### Valores por defecto

Cuando no existe `user://settings.json`, los valores por defecto se toman de las declaraciones de variables en `Rhythia.gd`. A continuacion los valores por defecto mas relevantes:

| Propiedad | Valor por defecto |
|-----------|-------------------|
| `approach_rate` | `40` |
| `spawn_distance` | `40` |
| `fade_length` | `0.5` |
| `sensitivity` | `0.5` |
| `note_size` | `1` |
| `note_opacity` | `1` |
| `note_hitbox_size` | `1.140` |
| `hitwindow_ms` | `55` |
| `parallax` | `6.5` |
| `ui_parallax` | `1.63` |
| `grid_parallax` | `0` |
| `fov` | `70` |
| `cursor_scale` | `1` |
| `cursor_spin` | `0` |
| `cursor_trail` | `false` |
| `trail_detail` | `10` |
| `trail_time` | `0.15` |
| `custom_speed` | `1` |
| `cam_unlock` | `false` |
| `faraway_hud` | `true` |
| `enable_border` | `true` |
| `play_menu_music` | `true` |
| `play_hit_snd` | `true` |
| `play_miss_snd` | `true` |
| `language` | `0` |
| `glow` | `0` |
| `bloom` | `0` |

Los volumenes por defecto se establecen en `Rhythia._ready()`:
- Master: `linear2db(0.5)` (~-6 dB)
- Music: `linear2db(0.5)` (~-6 dB)
- HitSound: `linear2db(0.3)` (~-10.5 dB)
- MissSound: `linear2db(0.6)` (~-4.4 dB)
- FailSound: `linear2db(0.6)` (~-4.4 dB)
- PBSound: `linear2db(0.6)` (~-4.4 dB)

### Perfiles de configuracion

El sistema de perfiles (`Profiles.gd`) permite mantener multiples configuraciones:

- Los perfiles se guardan como `user://<nombre>.settings.json`
- "Create New From Current" guarda la configuracion actual como un nuevo perfil
- Al seleccionar un perfil, se carga con `Rhythia.load_saved_settings(path)` y se sobreescribe `user://settings.json`
- Soporte para sobreescribir y eliminar perfiles via submenus

### Formato binario legacy

Antes del formato JSON, los settings se guardaban en un archivo binario `user://settings` con un sistema de versiones (`current_sf_version = 48`). La funcion `load_saved_settings()` todavia soporta este formato: si no encuentra el JSON pero encuentra el archivo binario, lo lee y lo convierte automaticamente a JSON llamando `save_settings()` al final.

---

## Senales relacionadas

Las siguientes senales en `Rhythia.gd` estan directamente relacionadas con el sistema de configuracion:

| Senal | Emitida por | Proposito |
|-------|-------------|-----------|
| `mods_changed` | Todos los setters de modificadores (`set_mod_*`, `_set_hitbox_size`, `_set_hitwindow`, etc.) | Notifica que un modificador de gameplay cambio. Usada por la UI de modificadores para actualizar su estado. |
| `speed_mod_changed` | `set_mod_speed_level()`, `_set_custom_speed()` | Notifica que la velocidad de juego cambio. |
| `volume_changed` | `_set_music_volume()` | Notifica que el volumen de musica cambio. Usada por `MusicVolumeSetter.gd` para interpolar suavemente el volumen. |
| `selected_space_changed` | `select_world()` | Notifica que el mundo de fondo seleccionado cambio. |
| `selected_colorset_changed` | `select_colorset()` | Notifica que el colorset seleccionado cambio. |
| `selected_mesh_changed` | `select_mesh()` | Notifica que la mesh de notas cambio. |
| `selected_hit_effect_changed` | `select_hit_effect()` | Notifica que el efecto de hit cambio. |
| `selected_miss_effect_changed` | `select_miss_effect()` | Notifica que el efecto de miss cambio. |
| `menu_music_state_changed` | `_set_menu_music()` | Notifica que la musica del menu se activo o desactivo. |

---

## Diagrama de flujo de datos

```
+---------------------------+
|   settings_page.tscn      |
|  (Escena de UI)           |
+---------------------------+
         |
         | Contiene nodos con scripts de:
         v
+--------------------------------------+
|  scripts/ui/settings/*.gd            |
|                                      |
|  SpinBox / CheckBox / MenuButton     |
|  SettingsCheckbox / SettingsNumberBox |
|  SettingsColorPicker / EnumDropdown  |
+--------------------------------------+
         |                    ^
         | _ready(): lee      | _process(): detecta
         | valor de Rhythia   | cambios externos
         |                    |
         | upd(): escribe     |
         | valor a Rhythia    |
         v                    |
+--------------------------------------+
|  Rhythia.gd (Autoload/Singleton)     |
|                                      |
|  - Variables de settings             |
|  - Setters con signals               |
|  - save_settings()                   |
|  - load_saved_settings()             |
+--------------------------------------+
         |                    ^
         | save_settings()    | load_saved_settings()
         | (al salir de       | (en init.tscn,
         |  settings o al     |  al inicio del
         |  cerrar el juego)  |  juego)
         v                    |
+--------------------------------------+
|  user://settings.json                |
|                                      |
|  Archivo JSON con todas las          |
|  configuraciones persistidas         |
+--------------------------------------+
         |
         | Perfiles opcionales:
         v
+--------------------------------------+
|  user://<nombre>.settings.json       |
|  (Perfiles de configuracion)         |
+--------------------------------------+
```

**Flujo de escritura** (usuario cambia un setting):

```
Widget UI --> upd() --> Rhythia.propiedad = valor
                                |
                                +--> [setget] --> emit_signal()
                                                     |
                                                     v
                                              Otros sistemas
                                              reaccionan al cambio
```

**Flujo de lectura** (al abrir settings):

```
Rhythia.propiedad --> _ready() --> widget.value = Rhythia.propiedad
```

**Flujo de persistencia**:

```
Inicio del juego:
  init.tscn --> Rhythia.load_saved_settings()
                    --> Lee user://settings.json
                    --> Asigna cada valor a Rhythia.*

Cierre de settings:
  SaveSettings._exit_tree() --> Rhythia.save_settings()
                                    --> Serializa Rhythia.* a JSON
                                    --> Escribe user://settings.json
```

---

## Referencia adicional

- **`docs/SettingsManual.md`**: Guia para usuarios sobre como funcionan los settings de camara/parallax y approach/notas. Incluye formulas de conversion desde Vulnus.
- **`scripts/Rhythia.gd`**: Fuente de verdad de todas las variables de configuracion, senales y logica de persistencia.
- **`prefabs/menu/settings_page.tscn`**: Escena que define el layout visual de la pagina de settings.
- **`docs/arquitectura/01-globals-y-estado.md`**: Documentacion de los autoloads `Globals` y `Rhythia`.
