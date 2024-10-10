extends Node

# The Twitch WebSocket URL
@export var websocket_url = "wss://irc-ws.chat.twitch.tv:443"

# WebSocketPeer instance
var socket = WebSocketPeer.new()

# Twitch credentials
var twitch_oauth_token = "oauth:your_access_token" # Replace with your OAuth token (https://twitchtokengenerator.com/)
var twitch_username = "your_twitch_username"  # Your Twitch username (in lowercase)
var twitch_channel = "twitch_channel_name"  # The Twitch channel you want to connect to (in lowercase)

var authenticated = false  # Ensure authentication is sent only once

func _ready():
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Unable to connect to Twitch chat")
		set_process(false)
	else:
		print("Connecting to Twitch chat...")

func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not authenticated:
			_authenticate_to_twitch()

		# Process incoming messages
		while socket.get_available_packet_count():
			_on_message_received(socket.get_packet())
	elif state == WebSocketPeer.STATE_CLOSING:
		pass  # Keep polling until the connection closes properly
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		_on_closed(code, reason)

func _authenticate_to_twitch():
	# Send the Twitch OAuth token, username, and join channel
	print("Authenticating to Twitch...")
	socket.send_text("PASS " + twitch_oauth_token)
	socket.send_text("NICK " + twitch_username)
	socket.send_text("JOIN #" + twitch_channel)
	authenticated = true

func _on_message_received(packet: PackedByteArray):
	var message = packet.get_string_from_utf8()
	print("WebSocket message received: %s" % message)

	# Handle PING messages from Twitch
	if message.find("PING") >= 0:
		print("Received PING, sending PONG")
		socket.send_text("PONG :tmi.twitch.tv")
	
	# Parse and display chat messages
	if message.find("PRIVMSG") >= 0:
		var message_data = parse_twitch_message(message)
		if message_data.has("username") and message_data.has("message"):
			print("Message from %s: %s" % [message_data["username"], message_data["message"]])
		else:
			# print("Parsed message data is missing expected keys: ", message_data)  # Debugging line
			pass

func parse_twitch_message(message: String) -> Dictionary:
	var result = {}
	var message_parts = message.split(":", false, 2)
	if message_parts.size() == 3:
		var meta_data = message_parts[1].split(" ")
		result["username"] = meta_data[0].split("!")[0]
		result["message"] = message_parts[2]
	return result

func _on_closed(code, reason):
	print("WebSocket closed with code: %d, reason: %s" % [code, reason])
	set_process(false)  # Stop further processing when closed

func _send_message(message: String):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(message)
