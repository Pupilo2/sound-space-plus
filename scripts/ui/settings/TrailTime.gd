# Doc: scripts\ui\settings\TrailTime.gd
# Funcion: Implementa trail time dentro de logica interna del proyecto.
extends SpinBox

func upd():
	Rhythia.trail_time = float(str(value))

func _process(_d):
	if float(str(value)) != float(str(Rhythia.trail_time)): upd()

func _ready():
	value = float(str(Rhythia.trail_time))
	connect("changed",self,"upd")
