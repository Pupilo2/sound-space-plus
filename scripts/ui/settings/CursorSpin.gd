# Doc: scripts\ui\settings\CursorSpin.gd
# Funcion: Implementa cursor spin dentro de logica interna del proyecto.
extends SpinBox

func upd():
	Rhythia.cursor_spin = value

func _process(_d):
	if value != Rhythia.cursor_spin: upd()

func _ready():
	value = Rhythia.cursor_spin
	connect("changed",self,"upd")
