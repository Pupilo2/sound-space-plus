# Doc: scripts\ui\menu\buttons\CSpeedLabel.gd
# Funcion: Implementa cspeed label dentro de logica interna del proyecto.
extends Label

func upd():
	text = "C (%.0f%%)" % (Globals.speed_multi[Globals.SPEED_CUSTOM] * 100)

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
	Rhythia.connect("speed_mod_changed",self,"upd")
