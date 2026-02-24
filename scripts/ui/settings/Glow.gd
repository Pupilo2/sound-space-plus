# Doc: scripts\ui\settings\Glow.gd
# Funcion: Implementa glow dentro de logica interna del proyecto.
extends SpinBox

func upd():
	Rhythia.glow = value

func _process(_d):
	if value != Rhythia.glow: upd()

func _ready():
	value = Rhythia.glow
	connect("changed",self,"upd")
