# Doc: scripts\ui\menu\buttons\ModFlashlight.gd
# Funcion: Implementa mod flashlight dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_flashlight:
		Rhythia.mod_flashlight = pressed

func upd(): pressed = Rhythia.mod_flashlight

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
