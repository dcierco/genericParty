extends RigidBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var collision_shape_frame_0 = $CollisionShape2D_Frame0
@onready var collision_shape_frame_1 = $CollisionShape2D_Frame1

func _on_animated_sprite_2d_frame_changed():
	# Use a match statement to check the current frame index
	match animated_sprite_2d.frame:
		0:
			# If it's frame 0, enable the first collision shape and disable the second.
			collision_shape_frame_0.disabled = false
			collision_shape_frame_1.disabled = true
		1:
			# If it's frame 1, do the opposite.
			collision_shape_frame_0.disabled = true
			collision_shape_frame_1.disabled = false
