# Doc: debug\console\toast.gd
# Funcion: Implementa toast dentro de logica interna del proyecto.
extends Node

var time:float = INF

func _process(delta):
	time -= delta
	if time <= 0: queue_free()
