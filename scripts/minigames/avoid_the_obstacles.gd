extends "res://scripts/minigames/minigame_base.gd"

# Player settings
const PLAYER_SPEED = 300.0
const JUMP_VELOCITY = -700.0 
const JUMP_GRAVITY_SCALE_UP = 1.2
const PUSH_POWER = 2000.0

const PUSH_RANGE = 60.0

# Obstacle settings
const OBSTACLE_FALL_SPEED_MIN = 150.0
const OBSTACLE_FALL_SPEED_MAX = 350.0
var initial_obstacle_spawn_interval = 1.8
var current_obstacle_spawn_interval = 1.8
var min_obstacle_spawn_interval = 0.5 # Max difficulty
var spawn_interval_decrease_rate = 0.05 # How much to decrease interval per second
var difficulty_percent = 0.0 # 0-100%

# Node references
@onready var ground_node = $GameContainer/Ground
@onready var obstacle_spawn_timer = $GameContainer/ObstacleSpawnTimer
@onready var obstacle_spawn_positions = $GameContainer/ObstacleSpawnPositions
@onready var obstacle_container = $GameContainer/ObstacleContainer
@onready var player1 = $GameContainer/Players/Player1
@onready var player2 = $GameContainer/Players/Player2
@onready var debug_info = $GameContainer/DebugInfo
@onready var difficulty_label = $UI/DifficultyLabel
@onready var survival_bar_p1 = $UI/SurvivalContainer/Player1SurvivalVBox/SurvivalBarP1
@onready var survival_bar_p2 = $UI/SurvivalContainer/Player2SurvivalVBox/SurvivalBarP2

# Game state
var player_velocities = {0: Vector2.ZERO, 1: Vector2.ZERO}
var player_survival_times = {0: 0.0, 1: 0.0}
var player_detailed_scores = {}
var eliminated_players = {}
var obstacle_count = 0

func _ready():
	minigame_id = "avoid_the_obstacles"
	minigame_name = "Avoid the Obstacles!"
	minigame_description = "Dodge the falling objects! Last player standing wins, or survive the longest!\nControls:\nP1: A/D (move) + W (jump) + Space (push)\nP2: Arrows (move) + Up (jump) + Enter (push)"

	minigame_duration = 60.0
	has_time_limit = true

	super._ready()
	
	$BackgroundMusic.play()

	if description_label:
		description_label.text = minigame_description

	obstacle_spawn_timer.timeout.connect(_on_obstacle_spawn_timer_timeout)

func initialize_minigame():
	super.initialize_minigame()
	print("AvoidTheObstacles: Initializing Minigame")

	# Reset state
	player_velocities = {0: Vector2.ZERO, 1: Vector2.ZERO}
	player_survival_times = {0: 0.0, 1: 0.0}
	player_detailed_scores.clear()
	eliminated_players.clear()
	obstacle_count = 0
	
	# Reset difficulty
	difficulty_percent = 0.0
	current_obstacle_spawn_interval = initial_obstacle_spawn_interval
	obstacle_spawn_timer.wait_time = current_obstacle_spawn_interval
	
	# Reset survival bars
	survival_bar_p1.value = 0
	survival_bar_p2.value = 0
	
	# Clear any obstacles
	for obstacle in obstacle_container.get_children():
		obstacle.queue_free()
		
	# Setup players
	setup_players()
	
	# Update UI
	update_difficulty_display()
	update_debug_display()

func setup_players():
	# Get player count from MinigameManager
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2) # Limit to 2 players for this minigame
	
	# Setup player 1
	if is_instance_valid(player1):
		player1.position = $GameContainer/PlayerSpawnPositions/P1Spawn.position
		player1.visible = true
		player1.speed = PLAYER_SPEED
		player1.jump_velocity = JUMP_VELOCITY
		player1.jump_gravity_scale_up = JUMP_GRAVITY_SCALE_UP
		player1.eliminated = false
	
	# Setup player 2
	if is_instance_valid(player2):
		player2.position = $GameContainer/PlayerSpawnPositions/P2Spawn.position
		player2.visible = player_count > 1
		player2.speed = PLAYER_SPEED
		player2.jump_velocity = JUMP_VELOCITY
		player2.jump_gravity_scale_up = JUMP_GRAVITY_SCALE_UP
		player2.eliminated = false
	
	# Initialize player scores
	for i in range(player_count):
		player_scores[i] = 0
		player_finished[i] = false
		player_survival_times[i] = 0.0

func start_gameplay():
	super.start_gameplay()
	print("AvoidTheObstacles: Gameplay Started")
	
	# Start spawning obstacles
	obstacle_spawn_timer.start()

func _physics_process(delta):
	if current_state != MinigameState.PLAYING:
		return
	
	# Check push
	check_push()
	
	# Check for collisions with obstacles
	check_obstacle_collisions(player1, 0)
	check_obstacle_collisions(player2, 1)
	
	# Update sine wave obstacles
	update_sine_obstacles(delta)

func check_push():
	if Input.is_action_just_pressed("p1_action"):
		push_other_players(player1, 0)
		
	if Input.is_action_just_pressed("p2_action"):
		push_other_players(player2, 1)

func push_other_players(pusher: CharacterBody2D, pusher_id: int):
	var other_player = player2 if pusher_id == 0 else player1
	
	if is_instance_valid(other_player) and not other_player.eliminated and other_player.visible:
		var distance = pusher.global_position.distance_to(other_player.global_position)
		
		if distance < PUSH_RANGE:  # Push range
			var push_direction = (other_player.global_position - pusher.global_position).normalized()
			
			# Apply push directly to the other player's position and velocity
			other_player.position += push_direction * PUSH_POWER * 0.05  # Small immediate push
			other_player.velocity += push_direction * PUSH_POWER

func check_obstacle_collisions(player: CharacterBody2D, player_id: int):
	if not is_instance_valid(player) or player.eliminated or not player.visible:
		return
		
	# Check for collisions with obstacles
	for obstacle in obstacle_container.get_children():
		# Calculate distance between centers
		var distance = player.global_position.distance_to(obstacle.global_position)
		
		# Get approximate sizes
		var player_size = 25  # Based on the capsule shape size
		var obstacle_size = 30  # Average obstacle size
		
		# Simple circular collision check
		if distance < (player_size + obstacle_size):
			eliminate_player(player_id)
			break

func process_playing(delta):
	var active_player_count = 0
	
	# Update survival times and bars for active players
	for player_id in [0, 1]:
		var player = player1 if player_id == 0 else player2
		if is_instance_valid(player) and player.visible and not player.eliminated:
			active_player_count += 1
			player_survival_times[player_id] += delta
			player_scores[player_id] = int(player_survival_times[player_id] * 10)
			
			# Update survival bar
			if player_id == 0 and survival_bar_p1:
				survival_bar_p1.value = player_survival_times[player_id]
			elif player_id == 1 and survival_bar_p2:
				survival_bar_p2.value = player_survival_times[player_id]
	
	# Increase difficulty
	increase_difficulty(delta)
	
	# Update displays
	update_difficulty_display()
	update_debug_display()
	
	# Check if game should end (no players left)
	if active_player_count == 0:
		end_game_if_someone_eliminated()
	
	# Base class will handle time running out
	super.process_playing(delta)

func increase_difficulty(delta):
	# Increase difficulty over time (10% faster progression)
	difficulty_percent += delta * 1.65  # 0-100% over ~60 seconds
	difficulty_percent = min(difficulty_percent, 100.0)
	
	# Update spawn interval based on difficulty
	var difficulty_factor = difficulty_percent / 100.0
	current_obstacle_spawn_interval = lerp(initial_obstacle_spawn_interval, min_obstacle_spawn_interval, difficulty_factor)
	obstacle_spawn_timer.wait_time = current_obstacle_spawn_interval

func update_difficulty_display():
	# Update difficulty text
	if difficulty_label:
		var difficulty_text = "Difficulty: "
		if difficulty_percent < 30:
			difficulty_text += "Easy"
		elif difficulty_percent < 60:
			difficulty_text += "Medium"
		else:
			difficulty_text += "Hard"
		difficulty_label.text = difficulty_text

func update_debug_display():
	if debug_info:
		debug_info.text = "Active Obstacles: " + str(obstacle_container.get_child_count()) + "\n"
		debug_info.text += "Difficulty: " + str(int(difficulty_percent)) + "%\n"
		debug_info.text += "Spawn Rate: " + str(snapped(current_obstacle_spawn_interval, 0.01)) + "s"

func _on_obstacle_spawn_timer_timeout():
	if current_state != MinigameState.PLAYING:
		return
	
	# Create a new obstacle
	spawn_obstacle()
	
	# Restart timer
	obstacle_spawn_timer.start()

func spawn_obstacle():
	var obstacle = RigidBody2D.new()
	obstacle.name = "Obstacle" + str(obstacle_count)
	obstacle_count += 1
	
	# Decide obstacle type (0 = falling, 1 = side, 2 = sine wave)
	var obstacle_type = 0
	var random_value = randf()
	
	if random_value < 0.4:  # 40% chance for side obstacle
		obstacle_type = 1
	elif random_value < 0.5:  # 50% chance for sine wave obstacle
		obstacle_type = 2
	
	# Setup physics
	obstacle.gravity_scale = randf_range(1.0, 2.0) if obstacle_type == 0 else 0.0
	obstacle.mass = randf_range(1.0, 3.0)
	obstacle.collision_layer = 4  # Layer 3 (obstacles)
	obstacle.collision_mask = 0   # Don't collide with anything (we'll do manual collision checks)
	obstacle.add_to_group("obstacles_group")
	
	# Store obstacle type as metadata
	obstacle.set_meta("type", obstacle_type)
	if obstacle_type == 2:  # Sine wave
		obstacle.set_meta("sine_time", 0.0)
		obstacle.set_meta("sine_amplitude", randf_range(30, 100))  # How much it moves up/downAdd commentMore actions
		obstacle.set_meta("sine_frequency", randf_range(1.5, 5.0))  # How fast it oscillates
		# Some obstacles have no slope (straight), others have slope
		var slope = 0.0
		if randf() > 0.3:  # 70% chance to have slope
			slope = randf_range(-0.3, 0.3)
		obstacle.set_meta("sine_slope", slope)  # Vertical slope while moving horizontally
	
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape
	
	if obstacle_type == 1:  # Side obstacle - always rectangle with half player height
		shape = RectangleShape2D.new()
		shape.size = Vector2(randf_range(40, 80), 25)  # Half player height
	else:
		# Randomize shape type for other obstacles
		if randf() > 0.5:
			shape = RectangleShape2D.new()
			var size = Vector2(randf_range(30, 80), randf_range(30, 80))
			shape.size = size
		else:
			shape = CircleShape2D.new()
			shape.radius = randf_range(15, 40)
	
	collision.shape = shape
	obstacle.add_child(collision)
	
	# Create visual
	var visual = ColorRect.new()
	if shape is RectangleShape2D:
		visual.size = shape.size
		visual.position = -shape.size/2
	else:
		visual.size = Vector2(shape.radius * 2, shape.radius * 2)
		visual.position = Vector2(-shape.radius, -shape.radius)
	
	# Color based on obstacle type
	if obstacle_type == 0:
		# Falling obstacles - red
		var color_value = lerp(0.3, 0.7, difficulty_percent / 100.0)
		visual.color = Color(color_value, 0.2, 0.2)
	elif obstacle_type == 1:
		# Side obstacles - blue
		visual.color = Color(0.2, 0.2, 0.7)
	else:
		# Sine wave obstacles - purple
		visual.color = Color(0.7, 0.2, 0.7)
	
	obstacle.add_child(visual)
	
	# Set spawn position and velocity based on type
	if obstacle_type == 0:  # Falling from top
		var spawn_markers = obstacle_spawn_positions.get_children()
		var spawn_pos = spawn_markers[randi() % spawn_markers.size()].global_position
		spawn_pos.x += randf_range(-50, 50)
		obstacle.global_position = spawn_pos
		
		# Variation in fall speed based on difficulty
		var min_speed = lerp(OBSTACLE_FALL_SPEED_MIN, OBSTACLE_FALL_SPEED_MIN * 1.5, difficulty_percent / 100.0)
		var max_speed = lerp(OBSTACLE_FALL_SPEED_MAX, OBSTACLE_FALL_SPEED_MAX * 1.5, difficulty_percent / 100.0)
		
		obstacle.linear_velocity = Vector2(
			randf_range(-50, 50),  # Some horizontal velocity
			randf_range(min_speed, max_speed)  # Vertical fall speed
		)
	elif obstacle_type == 1:  # Side obstacle
		# Spawn on left or right side
		var from_left = randf() > 0.5
		var y_pos = ground_node.global_position.y - 15  # Just above ground level
		
		if from_left:
			obstacle.global_position = Vector2(-50, y_pos)
			obstacle.linear_velocity = Vector2(randf_range(200, 300), 0)  # Move right
		else:
			obstacle.global_position = Vector2(1330, y_pos)
			obstacle.linear_velocity = Vector2(randf_range(-300, -200), 0)  # Move left
	else:  # Sine wave
		# Spawn at same height as side obstacles
		var from_left = randf() > 0.5
		var y_pos = ground_node.global_position.y - 15  # Same as side obstacles
		
		# Store initial center position for sine wave calculations
		obstacle.set_meta("initial_y", y_pos)
		
		if from_left:
			obstacle.global_position = Vector2(-50, y_pos)
			obstacle.linear_velocity = Vector2(randf_range(120, 280), 0)  # Varying horizontal speed
		else:
			obstacle.global_position = Vector2(1330, y_pos)
			obstacle.linear_velocity = Vector2(randf_range(-280, -120), 0)  # Varying horizontal speed
	
	# Add auto-cleanup when obstacle exits screen
	var visibility_notifier = VisibleOnScreenNotifier2D.new()
	visibility_notifier.screen_exited.connect(func(): obstacle.queue_free())
	obstacle.add_child(visibility_notifier)
	
	# Add to container
	obstacle_container.add_child(obstacle)

func eliminate_player(player_id):
	# Check if already eliminated
	if player_finished.get(player_id, false) or eliminated_players.has(player_id):
		return
	
	# Get player node
	var player = player1 if player_id == 0 else player2
	if not is_instance_valid(player):
		return
	
	print("Player " + str(player_id + 1) + " eliminated!")
	player.eliminate()
	player.visible = false
	
	# Disable collision so eliminated player doesn't interfere
	player.set_collision_layer_value(2, false)  # Remove from player layer
	player.set_collision_mask_value(1, false)   # Don't collide with world
	player.set_collision_mask_value(3, false)   # Don't collide with enemies
	
	# Calculate survival score (time survived * 10 points per second)
	var survival_time = player_survival_times.get(player_id, 0.0)
	var survival_score = int(survival_time * 10) 
	
	# Store detailed score
	player_detailed_scores[player_id] = {
		"survival_time": survival_time,
		"survival_score": survival_score,
		"win_bonus": 0,  # Will be added if this is the last player
		"total": survival_score
	}
	
	# Mark as eliminated
	eliminated_players[player_id] = true
	player_finished[player_id] = true
	
	# End game if this was the first elimination (meaning only one player left)
	end_game_if_someone_eliminated()

func end_game_if_someone_eliminated():
	# Check if we should end the game (only one player left)
	var active_players = []
	var active_player_id = -1
	
	# Check which players are still active
	if is_instance_valid(player1) and not player1.eliminated and player1.visible:
		active_players.append(player1)
		active_player_id = 0
		
	if is_instance_valid(player2) and not player2.eliminated and player2.visible:
		active_players.append(player2)
		active_player_id = 1
	
	# If we have no active players, end the game
	if active_players.size() == 0:
		# End the minigame
		print("AvoidTheObstacles: Game over, no players left")
		end_minigame()
	# If we have exactly one active player and at least one elimination
	elif active_players.size() == 1 and eliminated_players.size() > 0:
		# Award win bonus to the last player standing
		if active_player_id >= 0:
			var survival_time = player_survival_times.get(active_player_id, 0.0)
			var survival_score = int(survival_time * 10)
			var win_bonus = 100  # Bonus for being last player standing
			var total_score = survival_score + win_bonus
			
			# Store detailed score
			player_detailed_scores[active_player_id] = {
				"survival_time": survival_time,
				"survival_score": survival_score,
				"win_bonus": win_bonus,
				"total": total_score
			}
			
			# Update score and mark as finished
			player_scores[active_player_id] = total_score
			# Don't mark as finished so they can keep playing
			# player_finished[active_player_id] = true
		
		# Don't end the minigame - let the player continue until time runs out
		print("AvoidTheObstacles: One player left standing, continuing game")

# Update sine wave obstacles movement pattern
func update_sine_obstacles(delta):
	for obstacle in obstacle_container.get_children():
		if obstacle.has_meta("type") and obstacle.get_meta("type") == 2:  # Sine wave type
			# Update sine parameters
			var sine_time = obstacle.get_meta("sine_time") + delta
			obstacle.set_meta("sine_time", sine_time)
			
			var amplitude = obstacle.get_meta("sine_amplitude")
			var frequency = obstacle.get_meta("sine_frequency")
			var slope = obstacle.get_meta("sine_slope")
			var initial_y = obstacle.get_meta("initial_y")
			
			# Calculate sine wave position
			var sine_offset = sin(sine_time * frequency) * amplitude
			
			# Add slope component (gradual rise/fall over time)
			var slope_offset = slope * sine_time * 20  # Scale slope effect
			
			# Set position relative to initial center positionAdd commentMore actions
			var target_y = initial_y + sine_offset + slope_offset
			obstacle.position.y = target_y
			
			# Maintain horizontal velocity only
			var current_velocity = obstacle.linear_velocity
			obstacle.linear_velocity = Vector2(current_velocity.x, 0)

func end_minigame():
	if current_state == MinigameState.FINISHED or current_state == MinigameState.RESULTS:
		return
		
	print("AvoidTheObstacles: Ending Minigame")
	obstacle_spawn_timer.stop()
	
	# Handle any players still active when time runs out
	for player_id in [0, 1]:
		if not player_finished.get(player_id, true):
			# Calculate final score for this player
			var survival_time = player_survival_times.get(player_id, 0.0)
			var survival_score = int(survival_time * 10)
			
			# No win bonus for time-out
			player_detailed_scores[player_id] = {
				"survival_time": survival_time,
				"survival_score": survival_score,
				"win_bonus": 0,
				"total": survival_score
			}
			
			# Mark as finished
			player_scores[player_id] = survival_score
			player_finished[player_id] = true
	
	# Let the base class handle results display and transitioning
	super.end_minigame()

# Override the display_results function to show team-based results
func display_results():
	# Base class will handle making the container visible
	
	# Get the results list before calling super (which will clear it)
	var results_list = $UI/ResultsContainer/VBoxContainer/ResultsList
	if results_list:
		# Clear existing results
		for child in results_list.get_children():
			child.queue_free()
	
	# Calculate team results first using base class implementation
	super.display_results()
	
	# Get team panels and labels
	var red_team_panel = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/RedTeamPanel
	var blue_team_panel = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/BlueTeamPanel
	var red_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/RedTeamPanel/RedTeamLabel
	var blue_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/BlueTeamPanel/BlueTeamLabel
	
	# Add game-specific info to team labels
	if red_team_label and blue_team_label:
		# Check who survived longer
		var red_eliminated = eliminated_players.has(0)
		var blue_eliminated = eliminated_players.has(1)
		var red_survival_time = player_survival_times.get(0, 0.0)
		var blue_survival_time = player_survival_times.get(1, 0.0)
		
		# Enhance the win/lose message with game details
		if not red_eliminated and blue_eliminated:
			red_team_label.text = "RED TEAM WINS\nLast one standing!"
			blue_team_label.text = "BLUE TEAM LOSES\nEliminated by obstacles!"
		elif not blue_eliminated and red_eliminated:
			blue_team_label.text = "BLUE TEAM WINS\nLast one standing!"
			red_team_label.text = "RED TEAM LOSES\nEliminated by obstacles!"
		else:
			# Both eliminated or both survived (time ran out)
			if red_survival_time > blue_survival_time:
				red_team_label.text = "RED TEAM WINS\nSurvived longer!"
				blue_team_label.text = "BLUE TEAM LOSES\nEliminated earlier!"
			else:
				blue_team_label.text = "BLUE TEAM WINS\nSurvived longer!"
				red_team_label.text = "RED TEAM LOSES\nEliminated earlier!"
	
	# Add detailed player score breakdowns to results list
	if results_list:
		# Get sorted player ranking
		var ranking = get_player_ranking()
		
		# Add player results with detailed breakdown
		for player_data in ranking:
			var player_id = player_data.player_id
			var team = player_teams.get(player_id, "red")
			
			# Create VBox for this player's results
			var player_results = VBoxContainer.new()
			player_results.add_theme_constant_override("separation", 5)
			
			# Player header
			var player_header = Label.new()
			player_header.text = "Player " + str(player_id + 1) + " (" + team.capitalize() + " Team)"
			player_header.add_theme_font_size_override("font_size", 18)
			player_header.add_theme_color_override("font_color", team_colors[team])
			player_results.add_child(player_header)
			
			# Score breakdown
			if player_detailed_scores.has(player_id):
				var score_data = player_detailed_scores[player_id]
				
				# Survival time
				var survival_time_label = Label.new()
				var seconds = int(score_data.survival_time)
				var milliseconds = int((score_data.survival_time - seconds) * 100)
				survival_time_label.text = "Survived: " + str(seconds) + "." + str(milliseconds).pad_zeros(2) + " seconds"
				player_results.add_child(survival_time_label)
				
				# Survival score
				var survival_score_label = Label.new()
				survival_score_label.text = "+ " + str(score_data.survival_score) + " points (time survived)"
				player_results.add_child(survival_score_label)
				
				# Win bonus if applicable
				if score_data.win_bonus > 0:
					var bonus_label = Label.new()
					bonus_label.text = "+ " + str(score_data.win_bonus) + " points (last survivor bonus)"
					bonus_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
					player_results.add_child(bonus_label)
				
				# Total
				var total_label = Label.new()
				total_label.text = "Total: " + str(score_data.total) + " points"
				total_label.add_theme_font_size_override("font_size", 16)
				total_label.add_theme_color_override("font_color", Color(1, 1, 1))
				player_results.add_child(total_label)
			
			# Add to results list
			results_list.add_child(player_results)
			
			# Add spacer
			var spacer = HSeparator.new()
			results_list.add_child(spacer)
	
	# Animate the results panels
	if red_team_panel and blue_team_panel:
		# Create a single tween for both panels to ensure proper sequencing
		var tween = create_tween()
		
		# First, make panels pulse by scaling
		tween.tween_property(red_team_panel, "modulate", Color(1.2, 1.2, 1.2, 1), 0.5)
		tween.parallel().tween_property(blue_team_panel, "modulate", Color(1.2, 1.2, 1.2, 1), 0.5)
		
		# Then back to normal
		tween.tween_property(red_team_panel, "modulate", Color(1, 1, 1, 1), 0.5)
		tween.parallel().tween_property(blue_team_panel, "modulate", Color(1, 1, 1, 1), 0.5)
