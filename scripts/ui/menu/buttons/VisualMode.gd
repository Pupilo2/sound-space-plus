# Doc: scripts\ui\menu\buttons\VisualMode.gd
# Funcion: Implementa visual mode dentro de logica interna del proyecto.
extends CheckBox

func _process(_d):
	if pressed != Rhythia.visual_mode:
		Rhythia.visual_mode = pressed

func upd(): pressed = Rhythia.visual_mode

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
