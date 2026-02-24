# Doc: scripts\ui\settings\SaveSettings.gd
# Funcion: Implementa save settings dentro de logica interna del proyecto.
extends Button

func _pressed():
	Rhythia.save_settings()

func _exit_tree():
	if !OS.has_feature("debug"):
		Rhythia.save_settings()

func _ready():
	visible = OS.has_feature("debug")
