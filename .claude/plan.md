# Plan de Documentación - Sound Space Plus (Rhythia)

## Resumen
Crear documentación de arquitectura completa en español (archivos markdown separados) cubriendo los 238 scripts del proyecto, organizados por sistema/módulo.

## Estructura de Documentación

Se creará una carpeta `docs/arquitectura/` con los siguientes documentos:

### Fase 1: Documento principal + sistemas core
1. **`docs/arquitectura/README.md`** - Índice general del proyecto
   - Descripción del proyecto, motor, versión
   - Diagrama de arquitectura general
   - Mapa de directorios y su propósito
   - Flujo de inicialización del juego
   - Lista de autoloads y su rol
   - Enlaces a cada documento de sistema

2. **`docs/arquitectura/01-globals-y-estado.md`** - Estado Global
   - `Globals.gd` - Enums, constantes, utilidades
   - `Rhythia.gd` - Estado del juego, señales, configuración, registros
   - `init.gd` / `Intro.gd` - Secuencia de arranque

3. **`docs/arquitectura/02-gameplay.md`** - Sistema de Juego
   - `Game.gd` (SongPlayerManager) - Loop principal, puntaje, energía
   - `NoteManager.gd` - Spawn de notas, MultiMesh, detección de colisiones
   - `HUD.gd` - Interfaz durante el juego
   - `Camera.gd` / `CameraControl.gd` - Sistema de cámara
   - `Cursor.gd` / `CursorTrail.gd` - Cursor del jugador
   - `PauseHud.gd` - Pausa
   - `TrueComboHandler.gd` - Sistema de combo
   - `SFXManager.gd` - Efectos de sonido
   - Scripts de modificadores (Flashlight, etc.)

4. **`docs/arquitectura/03-contenido.md`** - Sistema de Contenido
   - `Registry.gd` - Registros de contenido
   - `Song.gd` - Modelo de datos de canciones, formatos (TXT, RAW, SSPM, Vulnus)
   - `Note.gd` / `NoteMesh.gd` / `NoteEffect.gd` - Entidades de notas
   - `ColorSet.gd` - Esquemas de color
   - `BackgroundWorld.gd` - Mundos de fondo
   - `Replay.gd` - Sistema de replays

### Fase 2: Sistemas secundarios
5. **`docs/arquitectura/04-recursos.md`** - Carga de Recursos
   - `AudioLoader.gd` - Carga de audio
   - `ImageLoader.gd` - Carga de imágenes
   - `ObjParse.gd` - Parseo de modelos 3D
   - `ResourceQueue.gd` - Cola de recursos asincrónicos
   - `gdunzip.gd` - Manejo de archivos ZIP

6. **`docs/arquitectura/05-ui-menus.md`** - Interfaz y Menús
   - Escenas de menú (`menu2.tscn`, etc.)
   - Scripts de botones y navegación
   - `ConfirmationPrompt2D.gd`, `StringPrompt2D.gd`, `FileSelector.gd`
   - `Notify2D.gd` - Notificaciones
   - Sistema de cola de canciones (queue)
   - Content Manager (`cmgr/`)

7. **`docs/arquitectura/06-settings.md`** - Sistema de Configuración
   - Todas las páginas de settings (~30 scripts)
   - Categorías: audio, visual, gameplay, controles, VR
   - Cómo se persisten los ajustes
   - Referencia a `SettingsManual.md` existente

8. **`docs/arquitectura/07-cursor-dance.md`** - Sistema de Cursor Dance
   - `Dance.gd` - Orquestador
   - `DanceMover.gd` - Clase base
   - `Simple.gd`, `Bouncy.gd`, `Directional.gd`, `Momentum.gd`, `Stop.gd`
   - `Cursor.gd` (dance), `Main.gd`

### Fase 3: Sistemas especializados
9. **`docs/arquitectura/08-avatar.md`** - Sistema de Avatar
    - `AvatarPointer.gd`, `shirt_animations.gd`
    - Editor de avatar (`avatarEditor/`)
    - Escenas: `Avatar.tscn`, `ARVRAvatar.tscn`

10. **`docs/arquitectura/09-online.md`** - Sistema Online
    - `Online.gd` - API de MapDB, descargas, conectividad
    - Flujo de descarga de mapas
    - Formato de API y manejo de errores

11. **`docs/arquitectura/10-vr.md`** - Soporte VR
    - `VRPlayer.gd` - Controlador VR
    - `MenuPointer.gd`, `Pointer.gd` - Interacción VR
    - `FakeVRHead.gd`, `CursorTester.gd`
    - Addon `godot-openvr`

12. **`docs/arquitectura/11-addons.md`** - Plugins y Addons
    - Discord Game SDK - Rich Presence
    - OpenVR - Soporte de realidad virtual
    - Native Dialogs - Diálogos nativos del SO

13. **`docs/arquitectura/12-localizacion-y-assets.md`** - Localización y Assets
    - Sistema de localización (CSV, 4 idiomas)
    - Organización de assets (mundos, imágenes, fuentes, SFX)
    - Shaders personalizados
    - Inputs y controles mapeados

14. **`docs/arquitectura/13-escenas-y-loaders.md`** - Escenas y Cargadores
    - Flujo entre escenas (init → intro → menu → song)
    - Escenas de carga (`loaders/`)
    - Escenas de error (`errors/`)
    - Prefabs reutilizables (`prefabs/`)

## Formato de cada documento
Cada archivo seguirá esta estructura:
- **Título y descripción** del sistema
- **Scripts incluidos** (tabla con ruta, clase, extensión)
- **Diagrama de flujo** (ASCII) mostrando cómo interactúan
- **Descripción de cada script**: propósito, señales, métodos clave, variables importantes
- **Conexiones con otros sistemas**
- **Notas técnicas** relevantes (patrones, optimizaciones)

## Orden de ejecución
1. Crear carpeta `docs/arquitectura/`
2. Escribir los 14 documentos en orden (Fase 1 → 2 → 3)
3. Cada documento se basa en lectura directa del código fuente

## Estimación
- 14 documentos markdown
- Cobertura de los 238 scripts organizados por sistema
- Todo en español
