extends AnimatedSprite2D

func _physics_process(delta: float) -> void:
	$".".global_rotation += 0.005
