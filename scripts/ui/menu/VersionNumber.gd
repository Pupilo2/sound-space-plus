# Doc: scripts\ui\menu\VersionNumber.gd
# Funcion: Implementa version number dentro de logica interna del proyecto.
extends Label

func _ready():
	text = "Rhythia [%s]" % ProjectSettings.get_setting("application/config/version")
