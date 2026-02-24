# Doc: scripts\ui\settings\ToAvEditor.gd
# Funcion: Implementa to av editor dentro de logica interna del proyecto.
extends Button

func _pressed():
	get_tree().change_scene("res://scenes/menu/AvatarEditor.tscn")
