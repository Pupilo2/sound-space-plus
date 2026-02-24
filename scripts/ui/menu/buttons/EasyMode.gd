# Doc: scripts\ui\menu\buttons\EasyMode.gd
# Funcion: Implementa easy mode dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.mod_extra_energy:
		Rhythia.mod_extra_energy = pressed

func upd(): pressed = Rhythia.mod_extra_energy

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
