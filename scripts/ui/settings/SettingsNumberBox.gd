# Doc: scripts\ui\settings\SettingsNumberBox.gd
# Funcion: Implementa settings number box dentro de logica interna del proyecto.
extends SpinBox

export(String) var target

func upd():
	Rhythia.set(target,value)

func _process(_d):
	if value != Rhythia.get(target): upd()
	
func _ready():
	value = Rhythia.get(target)
	connect("changed",self,"upd")
