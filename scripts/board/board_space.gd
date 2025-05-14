@tool
extends Node2D
class_name BoardSpace

# Space types
enum SpaceType {BLUE, RED, GREEN, SPECIAL, STAR, START}

# Space properties
@export var space_id: int = 0
@export var space_type: SpaceType = SpaceType.BLUE
@export var next_space_ids: Array[int] = []  # IDs of connected spaces
@export var coins_value: int = 3  # Coins granted/taken when landing on this space

# Visual elements
@export var highlight_color: Color = Color(1, 1, 0, 0.5)
var is_highlighted: bool = false

# References to connected spaces
var next_spaces: Array = []

# Called when the node enters the scene tree for the first time
func _ready():
	setup_visuals()

# Set up visuals based on space type
func setup_visuals():
	var sprite = $Sprite2D
	if not sprite:
		return
	
	# Set color based on space type
	match space_type:
		SpaceType.BLUE:
			sprite.modulate = Color(0.2, 0.2, 1.0)
		SpaceType.RED:
			sprite.modulate = Color(1.0, 0.2, 0.2)
		SpaceType.GREEN:
			sprite.modulate = Color(0.2, 1.0, 0.2)
		SpaceType.SPECIAL:
			sprite.modulate = Color(1.0, 0.6, 0.0)
		SpaceType.STAR:
			sprite.modulate = Color(1.0, 1.0, 0.0)
		SpaceType.START:
			sprite.modulate = Color(1.0, 1.0, 1.0)

# Called when a player lands on this space
func on_player_landed(player_id: int):
	# Get player data
	var player = null
	for p in GameManager.players:
		if p.player_id == player_id:
			player = p
			break
	
	if not player:
		push_error("Player not found: " + str(player_id))
		return
	
	# Apply space effect based on type
	match space_type:
		SpaceType.BLUE:
			# Give coins
			player.coins += coins_value
		SpaceType.RED:
			# Take coins
			player.coins = max(0, player.coins - coins_value)
		SpaceType.GREEN:
			# Special effect (override in derived classes)
			pass
		SpaceType.SPECIAL:
			# Special event (override in derived classes)
			pass
		SpaceType.STAR:
			# Star space - buy a star if enough coins
			if player.coins >= 20:
				player.coins -= 20
				player.stars += 1
		SpaceType.START:
			# Starting space - bonus coins
			player.coins += 10
	
	# Additional effects can be implemented in derived classes

# Highlight this space (for showing available moves)
func highlight(enabled: bool = true):
	is_highlighted = enabled
	if has_node("Highlight"):
		$Highlight.visible = enabled

# Get random next space (for path branches)
func get_random_next_space():
	if next_spaces.is_empty():
		return null
	
	var idx = randi() % next_spaces.size()
	return next_spaces[idx]

# Get all possible next spaces
func get_all_next_spaces() -> Array:
	return next_spaces 