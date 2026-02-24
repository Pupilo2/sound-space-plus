# Doc: assets\worlds\neon_tunnel\ring.gd
# Funcion: Implementa ring dentro de logica interna del proyecto.
extends MeshInstance

func _process(delta):
	transform.origin += Vector3(0,0,delta*(Rhythia.get("approach_rate")*0.1))
	if transform.origin.z >= 45: transform.origin.z -= 105
