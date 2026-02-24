# Doc: scripts\avatar\shirt_animations.gd
# Funcion: Implementa shirt animations dentro de logica interna del proyecto.
extends Spatial

func _ready():
	$CubellaBikini/Top/Animations.play("Idle")
