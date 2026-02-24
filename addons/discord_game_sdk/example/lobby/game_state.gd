# Doc: addons\discord_game_sdk\example\lobby\game_state.gd
# Funcion: Implementa game state dentro de logica interna del proyecto.
extends Resource
class_name GameState

signal members_changed
signal chat_changed

export(Dictionary) var members
export(Array, Resource) var chat
