# Doc: scripts\ui\settings\VSync.gd
# Funcion: Implementa vsync dentro de logica interna del proyecto.
extends CheckBox

func _pressed():
	if pressed != OS.vsync_enabled:
		OS.vsync_enabled = pressed

func _ready():
	pressed = OS.vsync_enabled
