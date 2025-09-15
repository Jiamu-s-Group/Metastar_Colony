extends Node2D

func _ready() -> void:
	self.show()
	$AudioStreamPlayer.play()

func _on_start_button_pressed() -> void:
	Game.change_scene("res://StartingPage/position_choosing_page.tscn")

func _on_option_button_pressed() -> void:
	$CanvasLayerFront/SettingsMenu.open_menu()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
