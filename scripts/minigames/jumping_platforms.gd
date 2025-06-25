extends "res://scripts/minigames/minigame_base.gd"

# Player settings
const PLAYER_SPEED = 200.0
const PLAYER_HORIZONTAL_SPEED = 200.0
const JUMP_VELOCITY = -550.0        # Moderate jump velocity
const JUMP_GRAVITY_SCALE_UP = 0.9   # Slightly lighter gravity when moving up
const JUMP_GRAVITY_SCALE_DOWN = 1.4 # Moderately heavier gravity when falling
const PUSH_POWER = 1000.0
const PUSH_RANGE = 60.0

# Jump physics calculations
# Max height: velocity² / (2 * gravity * scale_up) = 550² / (2 * 980 * 0.9) ≈ 172 pixels
# Time to peak: velocity / (gravity * scale_up) = 550 / (980 * 0.9) ≈ 0.62 seconds
# Total jump time: time_to_peak + fall_time ≈ 1.1 seconds (asymmetric due to different fall gravity)
# Max horizontal distance: horizontal_speed * total_time = 200 * 1.1 ≈ 220 pixels

# Platform settings
const PLATFORM_WIDTH_MIN = 60
const PLATFORM_WIDTH_MAX = 160
const PLATFORM_HEIGHT = 20
const PLATFORM_VERTICAL_SPACING_SAFE = 80      # Easy to reach with margin
const PLATFORM_VERTICAL_SPACING_RISKY = 110    # Reachable but requires good timing
const PLATFORM_VERTICAL_SPACING_TRAP = 150     # Unreachable - trap spacing
const PLATFORM_HORIZONTAL_SPREAD = 800

# Jump reachability constants (calculated from physics)
const MAX_JUMP_HEIGHT = 172                    # Maximum vertical reach
const MAX_HORIZONTAL_DISTANCE = 220            # Maximum horizontal reach during jump
const SAFE_HORIZONTAL_DISTANCE = 180          # Safe horizontal distance with margin

# Platform spawn patterns
enum PlatformPattern {
	ZIGZAG_DUAL,    # Two zigzag paths that cross each other
	FUNNEL_IN,      # Paths start wide, converge to center
	FUNNEL_OUT,     # Paths start center, spread out wide
	ALTERNATING,    # Single path that alternates left-right
	CROSSING_PATHS, # Paths that intersect and create push opportunities
	RECOVERY_AREA   # Help players who fell behind
}

# Camera and map progression settings
const CAMERA_FOLLOW_SPEED = 2.0
const MAP_PROGRESSION_THRESHOLD = 0.3  # 30% up the screen triggers map movement
const ELIMINATION_DISTANCE = 400  # Distance below camera before elimination

# Game state
var current_camera_y = 360.0
var highest_player_y = 360.0
var platform_spawn_y = 200.0
var map_height_meters = 0.0
var player_heights = {}
var player_detailed_scores = {}
var eliminated_players = {}

# Dynamic platform generation
var current_pattern = PlatformPattern.ZIGZAG_DUAL
var pattern_platforms_left = 0
var platform_generation_height = 0
var last_platform_positions: Array = []

# Node references
@onready var camera = $GameContainer/Camera2D
@onready var platform_spawn_timer = $GameContainer/PlatformSpawnTimer
@onready var platform_container = $GameContainer/PlatformContainer
@onready var player1 = $GameContainer/Players/Player1
@onready var player2 = $GameContainer/Players/Player2
@onready var ground_platform = $GameContainer/GroundPlatform
@onready var debug_info = $GameContainer/DebugInfo
@onready var height_label_p1 = $UI/HeightContainer/Player1HeightLabel
@onready var height_label_p2 = $UI/HeightContainer/Player2HeightLabel
@onready var tile_map = $GameContainer/TileMapLayer

func _ready():
	minigame_id = "jumping_platforms"
	minigame_name = "Jumping Platforms!"
	minigame_description = "Jump on platforms and reach the highest point! Push enemies to make them fall!\nControls:\nP1: A/D (move) + W (jump) + Space (push)\nP2: Arrows (move) + Up (jump) + Enter (push)"

	minigame_duration = 60.0
	has_time_limit = true

	super._ready()

	$BackgroundMusic.play()

	if description_label:
		description_label.text = minigame_description

	platform_spawn_timer.timeout.connect(_on_platform_spawn_timer_timeout)

func initialize_minigame():
	super.initialize_minigame()
	print("JumpingPlatforms: Initializing Minigame")

	# Reset state - start at ground level
	current_camera_y = 600.0  # Camera starts lower
	highest_player_y = 700.0  # Players start at ground level
	platform_spawn_y = 650.0  # First platforms closer to ground
	map_height_meters = 0.0
	player_heights = {0: 0.0, 1: 0.0}
	player_detailed_scores.clear()
	eliminated_players.clear()
	last_platform_positions.clear()
	
	# Reset height labels
	if height_label_p1:
		height_label_p1.text = "Player 1: 0m"
	if height_label_p2:
		height_label_p2.text = "Player 2: 0m"
	
	tile_map.clear()
	
	# Clear existing platforms
	for platform in platform_container.get_children():
		platform.queue_free()

	# Setup players and camera
	setup_players()
	setup_camera()

	# Create initial platforms above starting platform
	create_initial_platforms()

	update_debug_display()

func setup_players():
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)

	# Setup player 1
	if is_instance_valid(player1):
		player1.position = $GameContainer/PlayerSpawnPositions/P1Spawn.position
		player1.visible = true
		player1.speed = PLAYER_SPEED
		player1.jump_velocity = JUMP_VELOCITY
		player1.jump_gravity_scale_up = JUMP_GRAVITY_SCALE_UP
		player1.jump_gravity_scale_down = JUMP_GRAVITY_SCALE_DOWN
		player1.eliminated = false

	# Setup player 2
	if is_instance_valid(player2):
		player2.position = $GameContainer/PlayerSpawnPositions/P2Spawn.position
		player2.visible = player_count > 1
		player2.speed = PLAYER_SPEED
		player2.jump_velocity = JUMP_VELOCITY
		player2.jump_gravity_scale_up = JUMP_GRAVITY_SCALE_UP
		player2.jump_gravity_scale_down = JUMP_GRAVITY_SCALE_DOWN
		player2.eliminated = false

	# Initialize player scores
	for i in range(player_count):
		player_scores[i] = 0
		player_finished[i] = false
		player_heights[i] = 0.0

func setup_camera():
	if camera:
		camera.position = Vector2(640, current_camera_y)
		camera.limit_bottom = 800  # Set bottom limit so players can't fall infinitely

func create_initial_platforms():
	# Create fewer initial platforms
	for i in range(5):
		spawn_platform()

	# Create some easier starting platforms close to the ground
	create_starting_platforms()

func create_starting_platforms():
	var start_positions = [
		Vector2(400, 650),
		Vector2(880, 650),
		Vector2(640, 580)
	]

	for pos in start_positions:
		# Use the main create_platform_at function, forcing a specific width
		create_platform_at(pos, Color.WHITE, 120)

func start_gameplay():
	super.start_gameplay()
	
	player1.movable = true
	player2.movable = true
	
	print("JumpingPlatforms: Gameplay Started")

	# Start platform spawning
	platform_spawn_timer.start()

func _physics_process(delta):
	if current_state != MinigameState.PLAYING:
		return

	# Handle player movement and input
	handle_player_movement(delta)

	# Check push
	check_push()

	# Update highest player position
	update_highest_player_position()

	# Update camera position
	update_camera_position(delta)

	# Check for player eliminations
	check_player_eliminations()

	# Update UI displays
	update_height_displays()
	update_debug_display()

func handle_player_movement(delta):
	# Handle Player 1 movement and height tracking
	if is_instance_valid(player1) and not player1.eliminated and player1.visible:
		handle_single_player_movement(player1, 0, delta)
	
	# Handle Player 2 movement and height tracking  
	if is_instance_valid(player2) and not player2.eliminated and player2.visible:
		handle_single_player_movement(player2, 1, delta)

func handle_single_player_movement(player: CharacterBody2D, player_id: int, delta):
	var velocity = player.velocity
	
	# Apply variable gravity for better jump feel
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980)
	if not player.is_on_floor():
		var gravity_scale = JUMP_GRAVITY_SCALE_UP if velocity.y < 0 else JUMP_GRAVITY_SCALE_DOWN
		velocity.y += gravity * gravity_scale * delta

	# Horizontal movement
	var direction = 0
	if player_id == 0:  # Player 1 controls
		if Input.is_action_pressed("p1_left"):
			direction -= 1
		if Input.is_action_pressed("p1_right"):
			direction += 1
		if Input.is_action_just_pressed("p1_up") and player.is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:  # Player 2 controls
		if Input.is_action_pressed("p2_left"):
			direction -= 1
		if Input.is_action_pressed("p2_right"):
			direction += 1
		if Input.is_action_just_pressed("p2_up") and player.is_on_floor():
			velocity.y = JUMP_VELOCITY

	velocity.x = direction * PLAYER_HORIZONTAL_SPEED

	# Apply movement
	player.velocity = velocity
	player.move_and_slide()

	# Update player height score (now based on ground level at y=700)
	var height_meters = (700 - player.position.y) / 50.0  # Convert pixels to "meters" from ground
	player_heights[player_id] = max(player_heights[player_id], height_meters)

func check_push():
	if Input.is_action_just_pressed("p1_action"):
		push_other_players(player1, 0)

	if Input.is_action_just_pressed("p2_action"):
		push_other_players(player2, 1)

func push_other_players(pusher: CharacterBody2D, pusher_id: int):
	var other_player = player2 if pusher_id == 0 else player1

	if is_instance_valid(other_player) and not other_player.eliminated and other_player.visible:
		var distance = pusher.global_position.distance_to(other_player.global_position)

		if distance < PUSH_RANGE:
			var push_direction = (other_player.global_position - pusher.global_position).normalized()

			# Apply push directly to the other player's position and velocity
			other_player.position += push_direction * PUSH_POWER * 0.05  # Small immediate push
			other_player.velocity += push_direction * PUSH_POWER

func update_highest_player_position():
	var new_highest = highest_player_y

	# Check player 1
	if is_instance_valid(player1) and not player1.eliminated and player1.visible:
		new_highest = min(new_highest, player1.position.y)

	# Check player 2
	if is_instance_valid(player2) and not player2.eliminated and player2.visible:
		new_highest = min(new_highest, player2.position.y)

	highest_player_y = new_highest

func update_camera_position(delta):
	if not camera:
		return

	# Calculate target camera Y based on highest player
	var screen_progress = (current_camera_y - highest_player_y) / 720.0

	# If highest player is in upper portion of screen, move camera up
	if screen_progress > MAP_PROGRESSION_THRESHOLD:
		var target_y = highest_player_y + 360.0 * MAP_PROGRESSION_THRESHOLD
		current_camera_y = lerp(current_camera_y, target_y, CAMERA_FOLLOW_SPEED * delta)
		camera.position.y = current_camera_y

		# Update map height
		map_height_meters = (600 - current_camera_y) / 50.0

func check_player_eliminations():
	# Check if players have fallen too far behind the camera
	var elimination_y = current_camera_y + ELIMINATION_DISTANCE

	# Check player 1
	if is_instance_valid(player1) and not player1.eliminated and player1.visible:
		if player1.position.y > elimination_y:
			eliminate_player(0)

	# Check player 2
	if is_instance_valid(player2) and not player2.eliminated and player2.visible:
		if player2.position.y > elimination_y:
			eliminate_player(1)

func eliminate_player(player_id):
	if eliminated_players.has(player_id) or player_finished.get(player_id, false):
		return

	var player = player1 if player_id == 0 else player2
	if not is_instance_valid(player):
		return

	print("Player " + str(player_id + 1) + " eliminated for falling behind!")
	player.eliminate()
	player.visible = false

	# Calculate final score
	var height_score = int(player_heights.get(player_id, 0.0) * 10)

	player_detailed_scores[player_id] = {
		"height_score": height_score,
		"elimination_penalty": 0,
		"total": height_score
	}

	eliminated_players[player_id] = true
	# Use base class function to properly register the score
	set_player_finished(player_id, height_score)

	# Update height display with final height
	if player_id == 0 and height_label_p1:
		var height = int(player_heights.get(player_id, 0.0))
		height_label_p1.text = "Player 1: " + str(height) + "m (OUT)"
	elif player_id == 1 and height_label_p2:
		var height = int(player_heights.get(player_id, 0.0))
		height_label_p2.text = "Player 2: " + str(height) + "m (OUT)"

	# Check if game should end
	check_game_over()

func check_game_over():
	var active_players = 0
	var last_player = -1

	for player_id in [0, 1]:
		if not eliminated_players.has(player_id) and not player_finished.get(player_id, false):
			var player = player1 if player_id == 0 else player2
			if is_instance_valid(player) and player.visible:
				active_players += 1
				last_player = player_id

	# If only one player left, they win
	if active_players == 1 and eliminated_players.size() > 0:
		var height_score = int(player_heights.get(last_player, 0.0) * 10)
		var first_place_bonus = 50  # First place bonus
		var survival_bonus = 100  # Bonus for surviving to the end
		var total_score = height_score + first_place_bonus + survival_bonus

		player_detailed_scores[last_player] = {
			"height_score": height_score,
			"first_place_bonus": first_place_bonus,
			"survival_bonus": survival_bonus,
			"total": total_score
		}

		# Use the base class function to properly set the winner's score
		set_player_finished(last_player, total_score)
		print("Player " + str(last_player + 1) + " wins by elimination! Score: " + str(total_score))
		print("Debug - player_scores after win: ", player_scores)
		end_minigame()
	elif active_players == 0:
		# All players eliminated
		end_minigame()

func update_height_displays():
	# Update height labels with current height values (only for active players)
	if height_label_p1 and player_heights.has(0) and not eliminated_players.has(0):
		var height = int(player_heights[0])
		height_label_p1.text = "Player 1: " + str(height) + "m"

	if height_label_p2 and player_heights.has(1) and not eliminated_players.has(1):
		var height = int(player_heights[1])
		height_label_p2.text = "Player 2: " + str(height) + "m"

func update_debug_display():
	if debug_info:
		debug_info.text = "Camera Y: " + str(int(current_camera_y)) + "\n"
		debug_info.text += "Tiles Used: " + str(tile_map.get_used_cells().size()) + "\n" # MODIFIED
		debug_info.text += "Highest Player: " + str(int(highest_player_y)) + "\n"
		debug_info.text += "P1 Height: " + str(int(player_heights.get(0, 0.0))) + "m\n"
		debug_info.text += "P2 Height: " + str(int(player_heights.get(1, 0.0))) + "m"

func _on_platform_spawn_timer_timeout():
	if current_state != MinigameState.PLAYING:
		return

	# Only spawn if we need more platforms ahead of the camera
	if platform_spawn_y > current_camera_y - 1000:
		spawn_platform()

func spawn_platform():
	# Check if we need a new pattern
	if pattern_platforms_left <= 0:
		choose_next_pattern()

	# Generate platforms based on current pattern
	match current_pattern:
		PlatformPattern.ZIGZAG_DUAL:
			spawn_zigzag_dual()
		PlatformPattern.FUNNEL_IN:
			spawn_funnel_in()
		PlatformPattern.FUNNEL_OUT:
			spawn_funnel_out()
		PlatformPattern.ALTERNATING:
			spawn_alternating()
		PlatformPattern.CROSSING_PATHS:
			spawn_crossing_paths()
		PlatformPattern.RECOVERY_AREA:
			spawn_recovery_area_platforms()

	pattern_platforms_left -= 1
	cleanup_old_platforms()

func choose_next_pattern():
	# Competitive pattern selection based on screen position and height
	var height_factor = platform_generation_height / 3000.0
	var rand_value = randf()

	# Always use dynamic patterns that force movement
	if rand_value < 0.25:
		current_pattern = PlatformPattern.ZIGZAG_DUAL
		pattern_platforms_left = randi_range(3, 5)  # More platforms for zigzag
	elif rand_value < 0.4:
		current_pattern = PlatformPattern.FUNNEL_IN
		pattern_platforms_left = randi_range(2, 3)
	elif rand_value < 0.55:
		current_pattern = PlatformPattern.FUNNEL_OUT
		pattern_platforms_left = randi_range(2, 3)
	elif rand_value < 0.75:
		current_pattern = PlatformPattern.ALTERNATING
		pattern_platforms_left = randi_range(3, 4)
	elif rand_value < 0.9:
		current_pattern = PlatformPattern.CROSSING_PATHS
		pattern_platforms_left = randi_range(2, 3)
	else:
		current_pattern = PlatformPattern.RECOVERY_AREA
		pattern_platforms_left = 1

func spawn_zigzag_dual():
	# Two paths that zigzag back and forth, creating dynamic movement
	var base_y = platform_spawn_y - PLATFORM_VERTICAL_SPACING_SAFE

	# Determine current step in zigzag pattern
	var step = (platform_generation_height / PLATFORM_VERTICAL_SPACING_SAFE) % 4

	match step:
		0:  # Start moderate spread
			create_platform_at(Vector2(400, base_y), Color(0.4, 0.3, 0.2))
			create_platform_at(Vector2(800, base_y), Color(0.4, 0.3, 0.2))
		1:  # Move inward
			create_platform_at(Vector2(500, base_y), Color(0.4, 0.3, 0.2))
			create_platform_at(Vector2(700, base_y), Color(0.4, 0.3, 0.2))
		2:  # Center convergence
			create_platform_at(Vector2(570, base_y), Color(0.4, 0.3, 0.2))
			create_platform_at(Vector2(630, base_y), Color(0.4, 0.3, 0.2))
		3:  # Back out moderate
			create_platform_at(Vector2(450, base_y), Color(0.4, 0.3, 0.2))
			create_platform_at(Vector2(750, base_y), Color(0.4, 0.3, 0.2))

	platform_spawn_y = base_y
	platform_generation_height += PLATFORM_VERTICAL_SPACING_SAFE

func spawn_funnel_in():
	# Paths start wide and funnel toward center
	var base_y = platform_spawn_y - PLATFORM_VERTICAL_SPACING_SAFE
	var step = pattern_platforms_left

	if step > 1:  # Starting moderately wide
		create_platform_at(Vector2(350 + randf_range(-30, 30), base_y), Color(0.4, 0.3, 0.2))
		create_platform_at(Vector2(850 + randf_range(-30, 30), base_y), Color(0.4, 0.3, 0.2))
	else:  # Funnel to center
		create_platform_at(Vector2(600 + randf_range(-60, 60), base_y), Color(0.4, 0.3, 0.2), 120)  # Wider center platform

	platform_spawn_y = base_y
	platform_generation_height += PLATFORM_VERTICAL_SPACING_SAFE

func spawn_funnel_out():
	# Paths start center and spread outward
	var base_y = platform_spawn_y - PLATFORM_VERTICAL_SPACING_SAFE
	var step = pattern_platforms_left

	if step > 1:  # Starting narrow
		create_platform_at(Vector2(580 + randf_range(-30, 30), base_y), Color(0.4, 0.3, 0.2))
		create_platform_at(Vector2(620 + randf_range(-30, 30), base_y), Color(0.4, 0.3, 0.2))
	else:  # Spread out moderately
		create_platform_at(Vector2(400 + randf_range(-40, 40), base_y), Color(0.4, 0.3, 0.2))
		create_platform_at(Vector2(800 + randf_range(-40, 40), base_y), Color(0.4, 0.3, 0.2))

	platform_spawn_y = base_y
	platform_generation_height += PLATFORM_VERTICAL_SPACING_SAFE

func spawn_alternating():
	# Single path that forces left-right movement
	var base_y = platform_spawn_y - PLATFORM_VERTICAL_SPACING_SAFE
	var step = (platform_generation_height / PLATFORM_VERTICAL_SPACING_SAFE) % 3

	var x_pos = 0
	match step:
		0:  x_pos = 450  # Left-center
		1:  x_pos = 600  # Center
		2:  x_pos = 750  # Right-center

	# Add some randomness but keep within reachable bounds
	x_pos += randf_range(-50, 50)
	create_platform_at(Vector2(x_pos, base_y), Color(0.4, 0.3, 0.2), 100)

	platform_spawn_y = base_y
	platform_generation_height += PLATFORM_VERTICAL_SPACING_SAFE

func spawn_crossing_paths():
	# Two paths that cross each other, creating push opportunities
	var base_y = platform_spawn_y - PLATFORM_VERTICAL_SPACING_SAFE
	var step = pattern_platforms_left

	if step > 1:  # First level - moderately separated
		create_platform_at(Vector2(400, base_y), Color(0.4, 0.3, 0.2))
		create_platform_at(Vector2(800, base_y), Color(0.4, 0.3, 0.2))
	else:  # Crossing point - close together for push interactions
		create_platform_at(Vector2(560, base_y), Color(0.4, 0.3, 0.2), 80)
		create_platform_at(Vector2(640, base_y), Color(0.4, 0.3, 0.2), 80)

	platform_spawn_y = base_y
	platform_generation_height += PLATFORM_VERTICAL_SPACING_SAFE

func spawn_recovery_area_platforms():
	# Multiple wider platforms to help players catch up
	var base_y = platform_spawn_y - PLATFORM_VERTICAL_SPACING_SAFE + 30  # Closer spacing for recovery

	create_platform_at(Vector2(350, base_y), Color(0.4, 0.3, 0.2), 140)  # Wide platform
	create_platform_at(Vector2(640, base_y + 15), Color(0.4, 0.3, 0.2), 140)  # Wide platform
	create_platform_at(Vector2(850, base_y), Color(0.4, 0.3, 0.2), 140)  # Wide platform

	platform_spawn_y = base_y
	platform_generation_height += PLATFORM_VERTICAL_SPACING_SAFE

func is_platform_reachable(from_pos: Vector2, to_pos: Vector2) -> bool:
	# Calculate if a platform is reachable with current jump physics
	var horizontal_distance = abs(to_pos.x - from_pos.x)
	var vertical_distance = from_pos.y - to_pos.y  # Positive when jumping up

	# Check if horizontal distance is achievable
	if horizontal_distance > MAX_HORIZONTAL_DISTANCE:
		return false

	# Check if we can reach the height
	if vertical_distance > MAX_JUMP_HEIGHT:
		return false

	# Check if falling too far (can always fall)
	if vertical_distance < -200:  # Allow reasonable falling distance
		return false

	return true

func get_last_platform_positions() -> Array:
	return last_platform_positions

func create_platform_at(pos: Vector2, _color: Color, width: float = -1):
	# Reachability logic
	var recent_positions = get_last_platform_positions()
	var is_reachable = false
	if recent_positions.size() > 0:
		for recent_pos in recent_positions:
			if is_platform_reachable(recent_pos, pos):
				is_reachable = true
				break
		if not is_reachable:
			pos = adjust_position_for_reachability(recent_positions.back(), pos)
	
	# Add to our tracking array for the next platform's reachability check
	last_platform_positions.append(pos)
	if last_platform_positions.size() > 5: # Keep the list small
		last_platform_positions.pop_front()
		
	# --- New TileMap Generation Logic ---
	if not tile_map:
		printerr("TileMap node not assigned! Cannot create platform.")
		return

	var platform_width = width if width > 0 else randf_range(PLATFORM_WIDTH_MIN, PLATFORM_WIDTH_MAX)
	var tile_size = tile_map.tile_set.tile_size
	var num_tiles = int(platform_width / tile_size.x)
	if num_tiles < 2: num_tiles = 2 # Ensure at least a left/right corner can be formed

	var start_coord = tile_map.local_to_map(pos - Vector2(platform_width / 2.0, 0))
	var platform_cells = []
	for i in range(num_tiles):
		platform_cells.append(start_coord + Vector2i(i, 0))

	# The second argument still needs to be a PackedVector2iArray.
	# By providing the full path, we avoid potential issues with the function's
	# internal pathfinding.
	tile_map.set_cells_terrain_path(platform_cells, 0, 0, 0)
	
func adjust_position_for_reachability(from_pos: Vector2, target_pos: Vector2) -> Vector2:
	# Adjust target position to be reachable from from_pos
	var horizontal_distance = target_pos.x - from_pos.x
	var vertical_distance = from_pos.y - target_pos.y

	# Limit horizontal distance
	if abs(horizontal_distance) > SAFE_HORIZONTAL_DISTANCE:
		var sign = 1 if horizontal_distance > 0 else -1
		horizontal_distance = SAFE_HORIZONTAL_DISTANCE * sign

		# Limit vertical distance
	if vertical_distance > PLATFORM_VERTICAL_SPACING_RISKY:
		vertical_distance = PLATFORM_VERTICAL_SPACING_RISKY
	elif vertical_distance < -100:  # Don't fall too far
		vertical_distance = -100

	return Vector2(from_pos.x + horizontal_distance, from_pos.y - vertical_distance)

func cleanup_old_platforms():
	var cleanup_threshold = current_camera_y + 1000
	var cells_to_erase = []
	
	var used_cells = tile_map.get_used_cells()
	for cell_coord in used_cells:
		var cell_world_pos = tile_map.map_to_local(cell_coord)
		if cell_world_pos.y > cleanup_threshold:
			cells_to_erase.append(cell_coord)
			
	for cell in cells_to_erase:
		tile_map.set_cell(cell)

func process_playing(delta):
	# Check if game should end due to time
	super.process_playing(delta)

func end_minigame():
	if current_state == MinigameState.FINISHED or current_state == MinigameState.RESULTS:
		return

	print("JumpingPlatforms: Ending Minigame")
	platform_spawn_timer.stop()

	# Handle any players still active when time runs out
	for player_id in [0, 1]:
		if not player_finished.get(player_id, false):
			var height_score = int(player_heights.get(player_id, 0.0) * 10)

			player_detailed_scores[player_id] = {
				"height_score": height_score,
				"first_place_bonus": 0,
				"survival_bonus": 0,
				"total": height_score
			}

			# Use base class function to properly register the score
			set_player_finished(player_id, height_score)

	super.end_minigame()

func display_results():
	var results_list = $UI/ResultsContainer/VBoxContainer/ResultsList
	if results_list:
		for child in results_list.get_children():
			child.queue_free()

	super.display_results()

	# Get team panels and labels
	var red_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/RedTeamPanel/RedTeamLabel
	var blue_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/BlueTeamPanel/BlueTeamLabel

	# Add jumping-specific info to team labels
	if red_team_label and blue_team_label:
		var red_height = player_heights.get(0, 0.0)
		var blue_height = player_heights.get(1, 0.0)
		var red_eliminated = eliminated_players.has(0)
		var blue_eliminated = eliminated_players.has(1)

		if not red_eliminated and blue_eliminated:
			red_team_label.text = "RED TEAM WINS\nReached higher!"
			blue_team_label.text = "BLUE TEAM LOSES\nFell behind!"
		elif not blue_eliminated and red_eliminated:
			blue_team_label.text = "BLUE TEAM WINS\nReached higher!"
			red_team_label.text = "RED TEAM LOSES\nFell behind!"
		else:
			if red_height > blue_height:
				red_team_label.text = "RED TEAM WINS\nReached " + str(int(red_height)) + "m!"
				blue_team_label.text = "BLUE TEAM LOSES\nReached " + str(int(blue_height)) + "m!"
			else:
				blue_team_label.text = "BLUE TEAM WINS\nReached " + str(int(blue_height)) + "m!"
				red_team_label.text = "RED TEAM LOSES\nReached " + str(int(red_height)) + "m!"

	# Add detailed player score breakdowns
	if results_list:
		var ranking = get_player_ranking()

		for player_data in ranking:
			var player_id = player_data.player_id
			var team = player_teams.get(player_id, "red")

			var player_results = VBoxContainer.new()
			player_results.add_theme_constant_override("separation", 5)

			var player_header = Label.new()
			player_header.text = "Player " + str(player_id + 1) + " (" + team.capitalize() + " Team)"
			player_header.add_theme_font_size_override("font_size", 18)
			player_header.add_theme_color_override("font_color", team_colors[team])
			player_results.add_child(player_header)

			if player_detailed_scores.has(player_id):
				var score_data = player_detailed_scores[player_id]

				var height_label = Label.new()
				var height_meters = player_heights.get(player_id, 0.0)
				height_label.text = "+ " + str(score_data.height_score) + " points (reached " + str(int(height_meters)) + " meters)"
				player_results.add_child(height_label)

				# First place bonus if applicable
				if score_data.get("first_place_bonus", 0) > 0:
					var first_place_label = Label.new()
					first_place_label.text = "+ " + str(score_data.first_place_bonus) + " points (first place bonus)"
					first_place_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
					player_results.add_child(first_place_label)
				
				# Survival bonus if applicable
				if score_data.get("survival_bonus", 0) > 0:
					var survival_label = Label.new()
					survival_label.text = "+ " + str(score_data.survival_bonus) + " points (survival bonus)"
					survival_label.add_theme_color_override("font_color", Color(0, 1, 0))
					player_results.add_child(survival_label)

				var total_label = Label.new()
				total_label.text = "Total: " + str(score_data.total) + " points"
				total_label.add_theme_font_size_override("font_size", 16)
				total_label.add_theme_color_override("font_color", Color(1, 1, 1))
				player_results.add_child(total_label)

			results_list.add_child(player_results)

			var spacer = HSeparator.new()
			results_list.add_child(spacer)
