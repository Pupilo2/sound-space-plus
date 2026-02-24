# Doc: assets\worlds\vaporwave\scripts\time_setter.gd
# Funcion: Implementa time setter dentro de logica interna del proyecto.
extends MeshInstance

var time:float = 0

func _process(delta):
	time += delta
	self.mesh.material.set_shader_param('time_float', time)
