# Doc: scripts\ui\settings\ReplayLimit.gd
# Funcion: Implementa replay limit dentro de logica interna del proyecto.
extends OptionButton

func upd(value):
	Rhythia.record_limit = get_item_id(value)

func _process(_d):
	if get_item_id(selected) != Rhythia.record_limit: upd(selected)
	
func _ready():
	selected = get_item_index(Rhythia.record_limit)
	connect("item_selected",self,"upd")
