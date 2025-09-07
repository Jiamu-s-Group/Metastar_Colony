extends Node2D

func _ready() -> void:
	$AudioStreamPlayer.play()

func _on_start_button_pressed() -> void:
	Game.change_scene("")

func _on_option_button_pressed() -> void:
	pass

func _on_exit_button_pressed() -> void:
	get_tree().quit()
