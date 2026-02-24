# Doc: vr\vrmenu.gd
# Funcion: Implementa vrmenu dentro de interaccion y flujo para modo VR.
extends Spatial

func _ready():
	Rhythia.vr_player.transform = Transform()
