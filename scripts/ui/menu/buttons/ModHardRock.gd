# Doc: scripts\ui\menu\buttons\ModHardRock.gd
# Funcion: Implementa mod hard rock dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_hardrock:
		Rhythia.mod_hardrock = pressed

func upd(): pressed = Rhythia.mod_hardrock

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
