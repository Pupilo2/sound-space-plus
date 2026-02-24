# Doc: scripts\ui\avatarEditor\AvatarEditorBack.gd
# Funcion: Implementa avatar editor back dentro de logica interna del proyecto.
extends Button

func _pressed():
	get_tree().change_scene("menu2.tscn")
