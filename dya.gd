# Doc: dya.gd
# Funcion: Implementa dya dentro de script auxiliar del proyecto.
extends Control

func _ready():
	$dya.play()

func _on_dya_finished():
	get_tree().quit()
