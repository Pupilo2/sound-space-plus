# Doc: scripts\ui\avatarEditor\AvatarEditor.gd
# Funcion: Implementa avatar editor dentro de logica interna del proyecto.
extends Control

func _ready():
	$VPContainer/VP/Avatar/Animations.play("Idle")
	$VPContainer/VP/Avatar/Head/Blinking.play("Blink")
