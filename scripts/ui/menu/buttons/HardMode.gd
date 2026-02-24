# Doc: scripts\ui\menu\buttons\HardMode.gd
# Funcion: Implementa hard mode dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_no_regen:
		Rhythia.mod_no_regen = pressed

func upd(): pressed = Rhythia.mod_no_regen

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
