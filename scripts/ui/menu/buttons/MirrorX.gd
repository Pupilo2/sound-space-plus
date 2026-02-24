# Doc: scripts\ui\menu\buttons\MirrorX.gd
# Funcion: Implementa mirror x dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_mirror_x:
		Rhythia.mod_mirror_x = pressed

func upd(): pressed = Rhythia.mod_mirror_x

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
