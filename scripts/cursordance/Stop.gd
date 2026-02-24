# Doc: scripts\cursordance\Stop.gd
# Funcion: Implementa stop dentro de logica interna del proyecto.
extends Button

func _pressed():
	get_tree().quit()
