# Doc: scripts\ui\settings\ReplayIntro.gd
# Funcion: Implementa replay intro dentro de logica interna del proyecto.
extends Node

func _on_Play_pressed():
	get_tree().change_scene("res://scenes/Intro.tscn")
