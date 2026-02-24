# Doc: scripts\ui\menu\buttons\Ghost.gd
# Funcion: Implementa ghost dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_ghost:
		Rhythia.mod_ghost = pressed

func upd(): pressed = Rhythia.mod_ghost

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
