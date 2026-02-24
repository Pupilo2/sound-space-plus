# Doc: scripts\ui\menu\MenuMouse.gd
# Funcion: Implementa menu mouse dentro de logica interna del proyecto.
extends Particles2D

func _input(event):
	if event is InputEventMouseMotion:
		position = event.position
