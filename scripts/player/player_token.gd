@tool
extends Node2D
class_name PlayerToken

# Player properties
@export var player_id: int = 0
@export var player_name: String = "Player"
@export var player_color: Color = Color(1, 0, 0)  # Default red

# Visual elements
@onready var sprite = $Sprite2D
@onready var color_rect = $Sprite2D/ColorRect
@onready var name_label = $NameLabel

func _ready():
	setup_visuals()
	
# Set up player visuals
func setup_visuals():
	# Set player color (each player should have a unique color)
	match player_id:
		0:  # Player 1 (Red)
			player_color = Color(1, 0.2, 0.2)
		1:  # Player 2 (Blue)
			player_color = Color(0.2, 0.4, 1)
		2:  # Player 3 (Green)
			player_color = Color(0.2, 0.8, 0.2)
		3:  # Player 4 (Yellow)
			player_color = Color(1, 0.9, 0.2)
	
	print("Setting up player " + str(player_id) + " visuals with color " + str(player_color))
	
	# Apply color to ColorRect
	if color_rect:
		color_rect.color = player_color
		print("Applied color to ColorRect")
	else:
		print("ColorRect not found!")
		# Try to find ColorRect
		for child in get_children():
			if child is Sprite2D:
				for subchild in child.get_children():
					if subchild is ColorRect:
						color_rect = subchild
						color_rect.color = player_color
						print("Found ColorRect in children")
						break
	
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

# Jump animation
func jump():
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 20, 0.2)
	tween.tween_property(self, "position:y", position.y, 0.2)
	
	await tween.finished 