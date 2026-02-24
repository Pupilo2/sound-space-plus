# Doc: scripts\ui\menu\buttons\Quit.gd
# Funcion: Implementa quit dentro de logica interna del proyecto.
extends Button

func _pressed():
	get_tree().quit()
