# Doc: scripts\ui\menu\buttons\ModChaos.gd
# Funcion: Implementa mod chaos dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_chaos:
		Rhythia.mod_chaos = pressed

func upd(): pressed = Rhythia.mod_chaos

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
