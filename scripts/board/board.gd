extends Node2D
class_name GameBoard

# Game state
enum BoardState {IDLE, DICE_ROLL, PLAYER_MOVING, SPACE_EVENT}
var current_state: BoardState = BoardState.IDLE

# Board elements
var spaces: Dictionary = {}  # space_id: BoardSpace
var players: Dictionary = {}  # player_id: PlayerNode

# Current turn variables
var current_player_id: int = -1
var dice_result: int = 0
var moves_remaining: int = 0
var current_space: BoardSpace = null
var destination_space: BoardSpace = null
var possible_paths: Array = []

# UI References
@onready var turn_label = $UI/TopPanel/HBoxContainer/TurnLabel
@onready var current_player_label = $UI/TopPanel/HBoxContainer/CurrentPlayerLabel
@onready var coins_label = $UI/TopPanel/HBoxContainer/PlayerStatsContainer/CoinsLabel
@onready var stars_label = $UI/TopPanel/HBoxContainer/PlayerStatsContainer/StarsLabel
@onready var roll_dice_button = $UI/BottomPanel/HBoxContainer/RollDiceButton
@onready var dice_value_label = $UI/BottomPanel/HBoxContainer/DiceValueLabel
@onready var dice_panel = $UI/DicePanel
@onready var dice_value_large = $UI/DicePanel/VBoxContainer/DiceValueLarge

# Signals
signal player_turn_ended
signal player_landed_on_space(player_id, space_id)
signal dice_rolled(result)

func _ready():
	print("Board scene loaded")
	
	# Register all spaces
	for space_node in get_tree().get_nodes_in_group("board_spaces"):
		if space_node is BoardSpace:
			spaces[space_node.space_id] = space_node
	
	print("Found " + str(spaces.size()) + " board spaces")
	
	connect_spaces()
	setup_players()
	
	# Connect UI signals
	if roll_dice_button:
		roll_dice_button.pressed.connect(_on_roll_dice_button_pressed)
		print("Roll dice button connected")
	else:
		push_error("Roll dice button not found!")
	
	# Start the first player's turn
	start_first_turn()

# Connect spaces based on their next_space_ids
func connect_spaces():
	for space_id in spaces:
		var space = spaces[space_id]
		space.next_spaces.clear()
		
		for next_id in space.next_space_ids:
			if spaces.has(next_id):
				space.next_spaces.append(spaces[next_id])
			else:
				push_error("Invalid next space ID: " + str(next_id))

# Setup player nodes on the board
func setup_players():
	players.clear()
	
	# Find start space
	var start_space = null
	for space_id in spaces:
		if spaces[space_id].space_type == BoardSpace.SpaceType.START:
			start_space = spaces[space_id]
			break
	
	if not start_space:
		push_error("No start space found on the board")
		return
	else:
		print("Start space found at position " + str(start_space.global_position))
	
	# Make sure GameManager has players
	if GameManager.players.size() == 0:
		push_error("No players in GameManager!")
		# Create default players for testing
		GameManager.start_new_game(4, 10)
	
	print("Setting up " + str(GameManager.players.size()) + " players")
	
	# Create player nodes for each player in GameManager
	for player_data in GameManager.players:
		# Create player node (visual representation)
		var player_scene = load("res://scenes/board/player_token.tscn")
		if player_scene:
			var player_instance = player_scene.instantiate()
			add_child(player_instance)
			
			# Set properties
			player_instance.player_id = player_data.player_id
			player_instance.player_name = player_data.name
			
			# Position at start space
			player_instance.global_position = start_space.global_position
			print("Positioned player " + str(player_data.player_id) + " at " + str(start_space.global_position))
			
			# Force visual update
			player_instance.setup_visuals()
			
			# Store reference
			players[player_data.player_id] = player_instance
			
			# Update player data
			player_data.current_space = start_space.space_id
			player_data.position = start_space.global_position
		else:
			push_error("Failed to load player scene")

# Start the first turn
func start_first_turn():
	current_player_id = GameManager.current_player_index
	print("Starting first turn with player " + str(current_player_id))
	start_player_turn(current_player_id)
	update_ui()

# Start a player's turn
func start_player_turn(player_id: int):
	current_player_id = player_id
	current_state = BoardState.DICE_ROLL
	
	# Get current space
	var player_data = GameManager.get_current_player()
	if spaces.has(player_data.current_space):
		current_space = spaces[player_data.current_space]
	else:
		push_error("Invalid player space ID: " + str(player_data.current_space))
		# Default to start space
		for space_id in spaces:
			if spaces[space_id].space_type == BoardSpace.SpaceType.START:
				current_space = spaces[space_id]
				break
	
	print("Player " + str(player_id) + " turn started at space " + str(current_space.space_id))
	
	# Enable dice roll button
	if roll_dice_button:
		roll_dice_button.disabled = false
		print("Dice roll button enabled")
	
	# Update UI
	update_ui()

# Roll the dice
func roll_dice():
	if current_state != BoardState.DICE_ROLL:
		return
	
	print("Rolling dice")
	
	# Disable dice roll button
	roll_dice_button.disabled = true
	
	# Generate random dice roll (1-6)
	dice_result = 1 + randi() % 6
	moves_remaining = dice_result
	
	print("Rolled a " + str(dice_result))
	
	# Show dice panel with animation
	if dice_panel and dice_value_large:
		dice_panel.visible = true
		dice_value_large.text = str(dice_result)
	
	emit_signal("dice_rolled", dice_result)
	
	# Update dice label
	if dice_value_label:
		dice_value_label.text = "Dice: " + str(dice_result)
	
	# Start player movement after a delay
	var tween = create_tween()
	tween.tween_interval(1.5)
	await tween.finished
	
	if dice_panel:
		dice_panel.visible = false
	
	current_state = BoardState.PLAYER_MOVING
	move_player()

# Move the player along the board
func move_player():
	if current_state != BoardState.PLAYER_MOVING or moves_remaining <= 0:
		handle_space_event()
		return
	
	# Calculate next space
	var next_space = current_space.get_random_next_space()
	if not next_space:
		push_error("No next space available")
		handle_space_event()
		return
	
	print("Moving player to space " + str(next_space.space_id))
	
	# Update player position
	var player_token = players[current_player_id]
	var tween = create_tween()
	tween.tween_property(player_token, "global_position", next_space.global_position, 0.5)
	
	await tween.finished
	
	# Make player jump for visual effect
	if player_token.has_method("jump"):
		player_token.jump()
	
	# Update current space
	current_space = next_space
	
	# Update player data
	var player_data = GameManager.get_current_player()
	player_data.current_space = current_space.space_id
	player_data.position = current_space.global_position
	
	moves_remaining -= 1
	
	print("Moves remaining: " + str(moves_remaining))
	
	# Continue movement
	if moves_remaining > 0:
		await get_tree().create_timer(0.2).timeout
		move_player()
	else:
		handle_space_event()

# Handle the event on the space where player landed
func handle_space_event():
	current_state = BoardState.SPACE_EVENT
	
	print("Player landed on space " + str(current_space.space_id) + " of type " + str(current_space.space_type))
	
	emit_signal("player_landed_on_space", current_player_id, current_space.space_id)
	
	# Trigger space effect
	current_space.on_player_landed(current_player_id)
	
	# Update UI to show any changes in coins/stars
	update_ui()
	
	# Wait for space event to complete
	await get_tree().create_timer(1.0).timeout
	
	end_player_turn()

# End the current player's turn
func end_player_turn():
	current_state = BoardState.IDLE
	emit_signal("player_turn_ended")
	
	print("Ending turn for player " + str(current_player_id))
	
	# Update GameManager
	GameManager.next_player_turn()
	
	print("Next player: " + str(GameManager.current_player_index) + ", Turn: " + str(GameManager.current_turn))
	
	# Check if game state changed (e.g., to minigame)
	if GameManager.current_state == GameManager.GameState.MINIGAME:
		print("Triggering minigame")
		# Game manager will handle switching to minigame
		await get_tree().create_timer(0.5).timeout
		MinigameManager.start_minigame()
	else:
		# Continue with next player
		current_player_id = GameManager.current_player_index
		start_player_turn(current_player_id)

# Handle dice roll button press
func _on_roll_dice_button_pressed():
	print("Roll dice button pressed")
	if current_state == BoardState.DICE_ROLL:
		roll_dice()

# Update UI elements with current game state
func update_ui():
	if !is_inside_tree():
		return
		
	# Make sure UI references are valid
	if !turn_label or !current_player_label or !coins_label or !stars_label:
		push_error("UI references are invalid!")
		return
	
	# Update turn label
	turn_label.text = "Turn: " + str(GameManager.current_turn) + "/" + str(GameManager.total_turns)
	
	# Update current player label
	var player_data = GameManager.get_current_player()
	current_player_label.text = "Current Player: " + player_data.name
	
	# Update stats
	coins_label.text = "Coins: " + str(player_data.coins)
	stars_label.text = "Stars: " + str(player_data.stars)
	
	print("UI updated - Turn: " + str(GameManager.current_turn) + "/" + str(GameManager.total_turns) + 
	      ", Player: " + player_data.name + ", Coins: " + str(player_data.coins) + 
	      ", Stars: " + str(player_data.stars)) 