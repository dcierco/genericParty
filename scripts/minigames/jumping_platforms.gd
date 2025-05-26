extends "res://scripts/minigames/minigame_base.gd"

# Player settings
const PLAYER_HORIZONTAL_SPEED = 300.0
const JUMP_VELOCITY = -700.0 
const PLAYER_GRAVITY_SCALE = 1.2
const PUSH_POWER = 4000.0
const PUSH_RANGE = 60.0

# Platform settings
const PLATFORM_WIDTH_MIN = 80
const PLATFORM_WIDTH_MAX = 200
const PLATFORM_HEIGHT = 20
const PLATFORM_VERTICAL_SPACING_MIN = 80
const PLATFORM_VERTICAL_SPACING_MAX = 120
const PLATFORM_HORIZONTAL_SPREAD = 600

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

# Player input mapping
var player_input_map = {
	0: {
		"left": "p1_left", 
		"right": "p1_right", 
		"jump": "p1_up",
		"push": "p1_action",
		"team": "red"
	},
	1: {
		"left": "p2_left", 
		"right": "p2_right", 
		"jump": "p2_up",
		"push": "p2_action",
		"team": "blue"
	}
}

func _ready():
	minigame_id = "jumping_platforms"
	minigame_name = "Jumping Platforms!"
	minigame_description = "Jump on platforms and reach the highest point! Push enemies to make them fall!\nControls:\nP1: A/D (move) + W (jump) + Space (push)\nP2: Arrows (move) + Up (jump) + Enter (push)"

	minigame_duration = 60.0
	has_time_limit = true

	super._ready()

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
	
	# Reset height labels
	if height_label_p1:
		height_label_p1.text = "Player 1: 0m"
	if height_label_p2:
		height_label_p2.text = "Player 2: 0m"
	
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
		player1.set_meta("player_id", 0)
		player1.set_meta("eliminated", false)
		player_teams[0] = player_input_map[0].get("team", "red")
	
	# Setup player 2
	if is_instance_valid(player2):
		player2.position = $GameContainer/PlayerSpawnPositions/P2Spawn.position
		player2.visible = player_count > 1
		player2.set_meta("player_id", 1)
		player2.set_meta("eliminated", false)
		player_teams[1] = player_input_map[1].get("team", "blue")
	
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
	# Create a few platforms above the starting platform that are reachable
	for i in range(10):
		spawn_platform()
	
	# Create some easier starting platforms close to the ground
	create_starting_platforms()

func create_starting_platforms():
	# Create some guaranteed reachable platforms near the starting position
	var start_positions = [
		Vector2(400, 650),   # Left platform
		Vector2(640, 600),   # Center platform (a bit higher)
		Vector2(880, 650),   # Right platform
		Vector2(520, 550),   # Mid-left higher
		Vector2(760, 550)    # Mid-right higher
	]
	
	for pos in start_positions:
		var platform = StaticBody2D.new()
		platform.name = "StartingPlatform_" + str(platform_container.get_child_count())
		platform.collision_layer = 1
		platform.collision_mask = 0
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(120, PLATFORM_HEIGHT)
		collision.shape = shape
		collision.one_way_collision = true
		platform.add_child(collision)
		
		var visual = ColorRect.new()
		visual.size = Vector2(120, PLATFORM_HEIGHT)
		visual.position = Vector2(-60, -PLATFORM_HEIGHT/2)
		visual.color = Color(0.4, 0.3, 0.2)
		platform.add_child(visual)
		
		platform.position = pos
		platform_container.add_child(platform)

func start_gameplay():
	super.start_gameplay()
	print("JumpingPlatforms: Gameplay Started")
	
	# Start platform spawning
	platform_spawn_timer.start()

func _physics_process(delta):
	if current_state != MinigameState.PLAYING:
		return
		
	# Handle player movement
	process_player_movement(player1, 0, delta)
	process_player_movement(player2, 1, delta)
	
	# Update highest player position
	update_highest_player_position()
	
	# Update camera position
	update_camera_position(delta)
	
	# Check for player eliminations
	check_player_eliminations()
	
	# Update UI displays
	update_height_displays()
	update_debug_display()

func process_player_movement(player: CharacterBody2D, player_id: int, delta: float):
	if not is_instance_valid(player) or player.get_meta("eliminated") or not player.visible:
		return
		
	var inputs = player_input_map.get(player_id)
	if not inputs:
		return
	
	var velocity = player.velocity
	
	# Apply gravity
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980)
	if not player.is_on_floor():
		velocity.y += gravity * PLAYER_GRAVITY_SCALE * delta
	
	# Horizontal movement
	var direction = 0
	if Input.is_action_pressed(inputs.left):
		direction -= 1
	if Input.is_action_pressed(inputs.right):
		direction += 1
	
	velocity.x = direction * PLAYER_HORIZONTAL_SPEED
	
	# Jump
	if Input.is_action_just_pressed(inputs.jump) and player.is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Push action
	if Input.is_action_just_pressed(inputs.push):
		push_other_players(player, player_id)
	
	# Apply movement
	player.velocity = velocity
	player.move_and_slide()
	
	# Update player height score (now based on ground level at y=700)
	var height_meters = (700 - player.position.y) / 50.0  # Convert pixels to "meters" from ground
	player_heights[player_id] = max(player_heights[player_id], height_meters)

func push_other_players(pusher: CharacterBody2D, pusher_id: int):
	var other_player = player2 if pusher_id == 0 else player1
	
	if is_instance_valid(other_player) and not other_player.get_meta("eliminated") and other_player.visible:
		var distance = pusher.global_position.distance_to(other_player.global_position)
		
		if distance < PUSH_RANGE:
			var push_direction = (other_player.global_position - pusher.global_position).normalized()
			
			# Apply push directly to the other player's position and velocity
			other_player.position += push_direction * PUSH_POWER * 0.05  # Small immediate push
			other_player.velocity += push_direction * PUSH_POWER

func update_highest_player_position():
	var new_highest = highest_player_y
	
	# Check player 1
	if is_instance_valid(player1) and not player1.get_meta("eliminated") and player1.visible:
		new_highest = min(new_highest, player1.position.y)
	
	# Check player 2
	if is_instance_valid(player2) and not player2.get_meta("eliminated") and player2.visible:
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
	if is_instance_valid(player1) and not player1.get_meta("eliminated") and player1.visible:
		if player1.position.y > elimination_y:
			eliminate_player(0)
	
	# Check player 2
	if is_instance_valid(player2) and not player2.get_meta("eliminated") and player2.visible:
		if player2.position.y > elimination_y:
			eliminate_player(1)

func eliminate_player(player_id):
	if eliminated_players.has(player_id) or player_finished.get(player_id, false):
		return
	
	var player = player1 if player_id == 0 else player2
	if not is_instance_valid(player):
		return
	
	print("Player " + str(player_id + 1) + " eliminated for falling behind!")
	player.set_meta("eliminated", true)
	player.visible = false
	
	# Calculate final score
	var height_score = int(player_heights.get(player_id, 0.0) * 10)
	
	player_detailed_scores[player_id] = {
		"height_score": height_score,
		"elimination_penalty": 0,
		"total": height_score
	}
	
	eliminated_players[player_id] = true
	player_finished[player_id] = true
	player_scores[player_id] = height_score
	
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
		var win_bonus = 200  # Bonus for being last player standing
		var total_score = height_score + win_bonus
		
		player_detailed_scores[last_player] = {
			"height_score": height_score,
			"win_bonus": win_bonus,
			"total": total_score
		}
		
		player_scores[last_player] = total_score
		print("Player " + str(last_player + 1) + " wins by elimination!")
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
		debug_info.text += "Platforms: " + str(platform_container.get_child_count()) + "\n"
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
	var platform = StaticBody2D.new()
	platform.name = "Platform_" + str(platform_container.get_child_count())
	
	# Set collision layers
	platform.collision_layer = 1  # World layer
	platform.collision_mask = 0
	
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	# Random platform width
	var platform_width = randf_range(PLATFORM_WIDTH_MIN, PLATFORM_WIDTH_MAX)
	shape.size = Vector2(platform_width, PLATFORM_HEIGHT)
	collision.shape = shape
	
	# Enable one-way collision (players can jump up through platforms)
	collision.one_way_collision = true
	
	platform.add_child(collision)
	
	# Create visual
	var visual = ColorRect.new()
	visual.size = Vector2(platform_width, PLATFORM_HEIGHT)
	visual.position = Vector2(-platform_width/2, -PLATFORM_HEIGHT/2)
	visual.color = Color(0.4, 0.3, 0.2)  # Brown platform color
	platform.add_child(visual)
	
	# Position platform
	var x_pos = randf_range(100, 1180)  # Random X within screen bounds with some padding
	var y_spacing = randf_range(PLATFORM_VERTICAL_SPACING_MIN, PLATFORM_VERTICAL_SPACING_MAX)
	platform_spawn_y -= y_spacing
	
	platform.position = Vector2(x_pos, platform_spawn_y)
	
	# Add to container
	platform_container.add_child(platform)
	
	# Clean up platforms that are too far below camera
	cleanup_old_platforms()

func cleanup_old_platforms():
	var cleanup_threshold = current_camera_y + 1000
	
	for platform in platform_container.get_children():
		if platform.position.y > cleanup_threshold:
			platform.queue_free()

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
		if not player_finished.get(player_id, true):
			var height_score = int(player_heights.get(player_id, 0.0) * 10)
			
			player_detailed_scores[player_id] = {
				"height_score": height_score,
				"win_bonus": 0,
				"total": height_score
			}
			
			player_scores[player_id] = height_score
			player_finished[player_id] = true
	
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
				
				if score_data.has("win_bonus") and score_data.win_bonus > 0:
					var bonus_label = Label.new()
					bonus_label.text = "+ " + str(score_data.win_bonus) + " points (victory bonus)"
					bonus_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
					player_results.add_child(bonus_label)
				
				var total_label = Label.new()
				total_label.text = "Total: " + str(score_data.total) + " points"
				total_label.add_theme_font_size_override("font_size", 16)
				total_label.add_theme_color_override("font_color", Color(1, 1, 1))
				player_results.add_child(total_label)
			
			results_list.add_child(player_results)
			
			var spacer = HSeparator.new()
			results_list.add_child(spacer)
