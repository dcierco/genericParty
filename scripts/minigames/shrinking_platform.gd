extends "res://scripts/minigames/minigame_base.gd"

# Game settings
var platform_size = Vector2(1000, 1000)  # Larger platform (25x25 cells)
var cell_size = 40
var lava_speed = 13.0  # Cells per second (to fill 625 cells in 60 seconds)
var push_power = 1500.0
var player_speed = 300.0

# Spiral shrinking parameters
var spiral_pos = Vector2.ZERO
var spiral_direction = 0  # 0 = right, 1 = down, 2 = left, 3 = up
var spiral_length = 1
var spiral_step_count = 0

# Player colors - same as race game for consistency
var player_colors = [
	Color(1, 0.2, 0.2),   # Red (Player 1)
	Color(0.2, 0.4, 1),   # Blue (Player 2)
]

# Game state
var platform
var lava_cells = []
var players = []
var player_inputs = {}
var eliminated_players = {}

# Time tracking
var shrink_timer = 0.0
var shrink_interval = 0.0  # Will be calculated in _ready

func _ready():
	print("Shrinking Platform: Ready")
	# Set minigame properties
	minigame_id = "shrinking_platform"
	minigame_name = "Shrinking Platform"
	minigame_description = "Stay on the platform as it shrinks! Push opponents into the lava!\nControls:\nPlayer 1: WASD (move) + Space (push)\nPlayer 2: Arrow Keys (move) + Enter (push)"
	
	# Set time limit to 60 seconds
	minigame_duration = 60.0
	
	# Set shrink interval based on lava speed
	shrink_interval = 1.0 / lava_speed  # Duration between adding lava cells
	
	super._ready()
	
	# Update description label
	if description_label:
		description_label.text = minigame_description

func initialize_minigame():
	print("Shrinking Platform: Initializing")
	super.initialize_minigame()
	
	setup_game_area()
	setup_players()
	setup_player_inputs()
	reset_spiral()

# Create the platform and initialize the game area
func setup_game_area():
	# Create a container for the game area
	var game_container = Control.new()
	game_container.name = "GameContainer"
	game_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_container)
	
	# Create a centered container for the platform
	var platform_container = CenterContainer.new()
	platform_container.name = "PlatformContainer"
	platform_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_container.add_child(platform_container)
	
	# Create the grid platform
	platform = GridContainer.new()
	platform.name = "Platform"
	platform.columns = int(platform_size.x / cell_size)
	platform_container.add_child(platform)
	
	# Add cells to the platform
	var total_cells = int(platform_size.x / cell_size) * int(platform_size.y / cell_size)
	for i in range(total_cells):
		var cell = ColorRect.new()
		cell.name = "Cell_" + str(i)
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.color = Color(0.8, 0.8, 0.8) # Light gray platform
		platform.add_child(cell)

# Configure player input mappings
func setup_player_inputs():
	player_inputs = {
		0: {
			"up": "p1_up",
			"down": "p1_down",
			"left": "p1_left",
			"right": "p1_right",
			"action": "p1_action"
		},
		1: {
			"up": "p2_up",
			"down": "p2_down",
			"left": "p2_left",
			"right": "p2_right",
			"action": "p2_action"
		}
	}

# Create player characters
func setup_players():
	var player_count = MinigameManager.get_player_count()
	
	for i in range(player_count):
		var player = CharacterBody2D.new()
		player.name = "Player" + str(i+1)
		
		# Create collision shape
		var collision = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 15
		collision.shape = circle_shape
		player.add_child(collision)
		
		# Create sprite
		var sprite = ColorRect.new()
		sprite.color = player_colors[i % player_colors.size()]
		sprite.size = Vector2(30, 30)
		sprite.position = Vector2(-15, -15)
		player.add_child(sprite)
		
		# Position player in the middle of the platform, slightly offset
		var offset = Vector2(30 * (i - 0.5), 0)
		player.position = Vector2(platform_size.x / 2, platform_size.y / 2) + offset
		
		# Store player data
		player.set_meta("player_id", i)
		player.set_meta("eliminated", false)
		
		add_child(player)
		players.append(player)

# Reset the spiral parameters to start from the edge
func reset_spiral():
	# Start from the top-left corner of the grid
	var grid_width = int(platform_size.x / cell_size)
	var grid_height = int(platform_size.y / cell_size)
	
	spiral_pos = Vector2(0, 0)
	spiral_direction = 0  # Start moving right
	spiral_length = grid_width
	spiral_step_count = 0
	
	# Clear existing lava cells
	lava_cells.clear()

func start_gameplay():
	print("Shrinking Platform: Starting")
	super.start_gameplay()
	
	# Make all players visible and active
	for player in players:
		player.visible = true

func _process(delta):
	match current_state:
		MinigameState.INTRO:
			super.process_intro(delta)
		MinigameState.PLAYING:
			process_playing(delta)
		MinigameState.FINISHED:
			process_finished(delta)

func process_playing(delta):
	if has_time_limit:
		time_remaining -= delta
		update_time_display()
		
		if time_remaining <= 0:
			end_minigame()
			return
	
	# Shrink the platform over time
	shrink_timer += delta
	if shrink_timer >= shrink_interval:
		shrink_timer = 0
		add_lava_cell()
	
	# Process player movement and collisions
	process_player_movement(delta)
	
	# Check if players are in lava
	check_player_eliminations()
	
	# Check if game is over (only one player left)
	check_game_over()

# Add a new lava cell at the current spiral position
func add_lava_cell():
	var grid_width = int(platform_size.x / cell_size)
	var grid_height = int(platform_size.y / cell_size)
	
	# Calculate cell index
	var cell_index = int(spiral_pos.y * grid_width + spiral_pos.x)
	
	# Get the cell if it exists and not already lava
	if cell_index >= 0 and cell_index < platform.get_child_count() and not cell_index in lava_cells:
		var cell = platform.get_child(cell_index)
		cell.color = Color(1, 0.5, 0, 0.8)  # Orange lava
		lava_cells.append(cell_index)
	
	# Move to next position in spiral
	spiral_step_count += 1
	
	# Check if we need to change direction
	if spiral_step_count == spiral_length:
		spiral_direction = (spiral_direction + 1) % 4  # Change direction
		spiral_step_count = 0
		
		# After turning twice (completing one "layer" of the spiral), reduce spiral_length
		if spiral_direction % 2 == 0:
			spiral_length -= 1
	
	# Move in current direction
	match spiral_direction:
		0: # Right
			spiral_pos.x += 1
		1: # Down
			spiral_pos.y += 1
		2: # Left
			spiral_pos.x -= 1
		3: # Up
			spiral_pos.y -= 1
	
	# Ensure we stay within bounds
	spiral_pos.x = clamp(spiral_pos.x, 0, grid_width - 1)
	spiral_pos.y = clamp(spiral_pos.y, 0, grid_height - 1)

# Process player input and movement
func process_player_movement(delta):
	for player in players:
		if player.get_meta("eliminated"):
			continue
			
		var player_id = player.get_meta("player_id")
		if not player_inputs.has(player_id):
			continue
			
		var inputs = player_inputs[player_id]
		var direction = Vector2.ZERO
		
		# Gather input direction
		if Input.is_action_pressed(inputs["up"]):
			direction.y -= 1
			print("Player " + str(player_id + 1) + " moving up")
		if Input.is_action_pressed(inputs["down"]):
			direction.y += 1
			print("Player " + str(player_id + 1) + " moving down")
		if Input.is_action_pressed(inputs["left"]):
			direction.x -= 1
			print("Player " + str(player_id + 1) + " moving left")
		if Input.is_action_pressed(inputs["right"]):
			direction.x += 1
			print("Player " + str(player_id + 1) + " moving right")
			
		# Normalize direction for consistent speed
		if direction.length() > 0:
			direction = direction.normalized()
			
		# Apply movement
		player.velocity = direction * player_speed
		player.move_and_slide()
		
		# Handle push action
		if Input.is_action_just_pressed(inputs["action"]):
			print("Player " + str(player_id + 1) + " pushing")
			push_other_players(player)

# Push other players away from this player
func push_other_players(pusher):
	for player in players:
		if player == pusher or player.get_meta("eliminated"):
			continue
			
		var distance = player.position.distance_to(pusher.position)
		if distance < 50:  # Push range
			var push_direction = (player.position - pusher.position).normalized()
			player.position += push_direction * push_power * 0.05  # Small immediate push
			player.velocity += push_direction * push_power

# Check if any players are touching lava
func check_player_eliminations():
	var grid_width = int(platform_size.x / cell_size)
	
	for player in players:
		if player.get_meta("eliminated"):
			continue
			
		# Get the cell the player is on
		var player_pos = player.position - platform.global_position
		var cell_x = int(player_pos.x / cell_size)
		var cell_y = int(player_pos.y / cell_size)
		
		# Keep within bounds
		cell_x = clamp(cell_x, 0, grid_width - 1)
		cell_y = clamp(cell_y, 0, int(platform_size.y / cell_size) - 1)
		
		var cell_index = cell_y * grid_width + cell_x
		
		# Check if player is on a lava cell
		if cell_index in lava_cells:
			eliminate_player(player)
		
		# Also check if player is out of bounds
		if player_pos.x < 0 or player_pos.x >= platform_size.x or player_pos.y < 0 or player_pos.y >= platform_size.y:
			eliminate_player(player)

# Eliminate a player who fell into lava
func eliminate_player(player):
	if player.get_meta("eliminated"):
		return
		
	player.set_meta("eliminated", true)
	player.visible = false
	
	var player_id = player.get_meta("player_id")
	eliminated_players[player_id] = true
	
	print("Player " + str(player_id + 1) + " eliminated!")

# Check if game should end
func check_game_over():
	var remaining_players = 0
	var last_player_standing = -1
	
	for player in players:
		if not player.get_meta("eliminated"):
			remaining_players += 1
			last_player_standing = player.get_meta("player_id")
	
	if remaining_players <= 1 or (eliminated_players.size() > 0 and eliminated_players.size() >= players.size() - 1):
		# Award score to last player, if any
		if last_player_standing >= 0:
			var score = 100
			set_player_finished(last_player_standing, score)
		
		# Give scores to eliminated players based on elimination order
		var rank = 2
		for player_id in eliminated_players:
			if not player_finished.get(player_id, false):
				var score = max(0, (players.size() - rank + 1) * 50)
				set_player_finished(player_id, score)
				rank += 1
		
		# End the minigame
		print("Shrinking Platform: Game over, last player standing: " + str(last_player_standing + 1))
		end_minigame()

func process_finished(delta):
	super.process_finished(delta)

# Clean up when scene is removed
func _exit_tree():
	print("Shrinking Platform: Cleaning up")
	eliminated_players.clear()
	lava_cells.clear()
	player_inputs.clear()
	players.clear() 
