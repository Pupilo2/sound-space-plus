# Doc: scripts\ui\menu\buttons\PlayAutoSwitch.gd
# Funcion: Implementa play auto switch dentro de logica interna del proyecto.
extends CheckBox

func _pressed():
	get_parent().get_parent().get_node("S/G").auto_switch_to_play = pressed

func _ready():
	pressed = Rhythia.was_auto_play_switch
	get_parent().get_parent().get_node("S/G").auto_switch_to_play = pressed
