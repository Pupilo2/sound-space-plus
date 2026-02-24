# Doc: vr\CursorTester.gd
# Funcion: Implementa cursor tester dentro de interaccion y flujo para modo VR.
extends Sprite

func _input(event):
	if event is InputEventMouse:
		position = event.position

func _ready():
	visible = Rhythia.vr
