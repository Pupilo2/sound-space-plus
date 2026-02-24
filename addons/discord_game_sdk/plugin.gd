# Doc: addons\discord_game_sdk\plugin.gd
# Funcion: Implementa plugin dentro de logica interna del proyecto.
tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("Discord", "res://addons/discord_game_sdk/discord.gd")

func disable_plugin():
	remove_autoload_singleton("Discord")
