# Doc: scripts\ui\menu\buttons\NoFail.gd
# Funcion: Implementa no fail dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_nofail:
		Rhythia.mod_nofail = pressed

func upd(): pressed = Rhythia.mod_nofail

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
