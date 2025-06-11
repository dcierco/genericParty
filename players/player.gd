extends CharacterBody2D

@export var player_id: int = 0
@export var player_name: String = "Player 1"
@export var player_color: Color = Color(1, 0, 0)  # Default red
@export var eliminated = false

@export var speed = 350.0
@export var jump_velocity = -650.0 
@export var gravity := 980.0
@export var player_gravity_scale = 2.0

# If the player can push other players
@export var can_push_other_players: bool = true
@export var push_power = 2000.0

# Visual elements
@onready var sprite = $PlayerSprite
@onready var jump_sound = $JumpSound
@onready var name_label = $NameLabel
@onready var eliminated_sound = $EliminatedSound

# Movement type
enum MovementType { SIDE, TOP_DOWN_8_WAY }
@export var movement_type: MovementType = MovementType.SIDE

var player_input_map = {
	0: {
		"up": "p1_up",
		"down": "p1_down",
		"left": "p1_left", 
		"right": "p1_right",
		"push": "p1_action",
		"team": "red"
	},
	1: {
		"up": "p2_up",
		"down": "p2_down",
		"left": "p2_left", 
		"right": "p2_right", 
		"push": "p2_action",
		"team": "blue"
	}
}

func _ready():
	setup_visuals()
	if can_push_other_players:
		set_collision_mask_value(2, true)
	else:
		set_collision_mask_value(2, false)
	
func setup_visuals():

	print("Setting up player " + str(player_id) + " visuals with color " + str(player_color))
	
	# Set name label
	if name_label:
		name_label.text = player_name
	else:
		# Create a name label if it doesn't exist
		name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = player_name
		name_label.position = Vector2(-30, -30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(name_label)
		print("Created new name label")
	
# Show dice roll animation
func show_dice_roll(value: int):
	# Create dice roll animation
	var dice_label = Label.new()
	add_child(dice_label)
	
	dice_label.text = str(value)
	dice_label.position = Vector2(0, -40)
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Animation
	var tween = create_tween()
	tween.tween_property(dice_label, "position", Vector2(0, -80), 1.0)
	tween.parallel().tween_property(dice_label, "modulate", Color(1, 1, 1, 0), 1.0)
	
	await tween.finished
	dice_label.queue_free()

# Show coin animation
func show_coins_change(amount: int):
	if amount == 0:
		return
	
	# Create coin label
	var coin_label = Label.new()
	add_child(coin_label)
	
	if amount > 0:
		coin_label.text = "+" + str(amount)
		coin_label.modulate = Color(1, 0.9, 0.1)
	else:
		coin_label.text = str(amount)
		coin_label.modulate = Color(1, 0.3, 0.3)
	
	coin_label.position = Vector2(0, -30)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Animation
	var tween = create_tween()
	tween.tween_property(coin_label, "position", Vector2(0, -70), 1.0)
	tween.parallel().tween_property(coin_label, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	coin_label.queue_free()

# Show star animation
func show_star_gained():
	# Create star label/icon
	var star_label = Label.new()
	add_child(star_label)
	
	star_label.text = "+1 ★"
	star_label.modulate = Color(1, 1, 0)
	star_label.position = Vector2(0, -30)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Animation
	var tween = create_tween()
	tween.tween_property(star_label, "position", Vector2(0, -80), 1.2)
	tween.parallel().tween_property(star_label, "scale", Vector2(1.5, 1.5), 1.2)
	tween.parallel().tween_property(star_label, "modulate:a", 0.0, 1.2)
	
	await tween.finished
	star_label.queue_free()

func print_position():
	print(position)

func _physics_process(delta):
	# Escolhe qual lógica de movimento e física aplicar baseado na variável 'movement_type'
	match movement_type:
		MovementType.SIDE:
			move_side(delta)
		MovementType.TOP_DOWN_8_WAY:
			move_8way(delta)
			
	# Atualiza a animação e move o personagem
	animate()
	move_and_slide()

func move_side(delta):
	var inputs = player_input_map.get(player_id)
	if not inputs:
		return
	
	velocity.x = 0
	velocity.y += player_gravity_scale * gravity * delta
	
	var vel := Input.get_axis(inputs.left, inputs.right)
	var jump := Input.is_action_just_pressed(inputs.up)
	
	if is_on_floor() and jump:
		velocity.y = jump_velocity
		jump_sound.pitch_scale = randf_range(0.8,1.2)
		jump_sound.play()

	velocity.x = vel * speed

func move_8way(delta): 
	var inputs = player_input_map.get(player_id)
	if not inputs:
		return
	
	var input_direction = Input.get_vector(inputs.left, inputs.right, inputs.up, inputs.down)
	velocity = input_direction * speed
	
	var collision_info = move_and_collide(velocity * delta)
	if collision_info:
		velocity = velocity.bounce(collision_info.get_normal())
		move_and_collide(velocity * delta * 10)

func animate():
	if velocity.x > 0:
		sprite.play("right")
	elif velocity.x < 0:
		sprite.play("left")
	elif velocity.y > 0 and movement_type == MovementType.TOP_DOWN_8_WAY:
		sprite.play("down")
	elif velocity.y < 0 and movement_type == MovementType.TOP_DOWN_8_WAY:
		sprite.play("up")
	else:
		sprite.stop()
		
func eliminate():
	eliminated = true
	eliminated_sound.play()
