# Doc: scripts\ui\settings\NoteScale.gd
# Funcion: Implementa note scale dentro de logica interna del proyecto.
extends SpinBox

func upd():
	Rhythia.note_size = value

func _process(_d):
	if value != Rhythia.note_size: upd()

func _ready():
	value = Rhythia.note_size
	connect("changed",self,"upd")
