# Doc: scripts\ui\settings\MusicOffset.gd
# Funcion: Implementa music offset dentro de logica interna del proyecto.
extends SpinBox

func upd():
	Rhythia.music_offset = value

func _process(_d):
	if value != Rhythia.music_offset: upd()

func _ready():
	connect("changed",self,"upd")
	value = Rhythia.music_offset
