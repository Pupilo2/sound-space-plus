# Doc: scripts\cursordance\DanceMover.gd
# Funcion: Implementa dance mover dentro de logica interna del proyecto.
extends Resource
class_name DanceMover

func update(ms:float) -> Vector2:
	return call("_update",ms)
