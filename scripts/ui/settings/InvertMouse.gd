# Doc: scripts\ui\settings\InvertMouse.gd
# Funcion: Implementa invert mouse dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.invert_mouse:
		Rhythia.invert_mouse = pressed

func upd(): pressed = Rhythia.invert_mouse

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
