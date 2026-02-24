# Doc: scripts\game\FPS.gd
# Funcion: Implementa fps dentro de logica interna del proyecto.
extends Label

func _process(delta):
	text = String(Engine.get_frames_per_second())
