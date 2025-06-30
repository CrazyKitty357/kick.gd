class_name KickChat
extends Node

## Emitted when the WebSocket connection is successfully established.
signal connection_established

## Emitted when the WebSocket connection is closed.
signal connection_closed(code: int, reason: String)

## Emitted if there is an error during connection.
signal connection_error

## Emitted when a new chat message is received. The payload is the parsed message data.
signal chat_message_received(message_data: Dictionary)
signal chat_message_type(message_type: String)

## Emitted when the client successfully subscribes to a Pusher channel. Useful for debugging.
signal subscribed_to_channel(channel_name: String)

# The direct URL to Kick's Pusher application
const KICK_PUSHER_URL = "wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=8.4.0&flash=false"

var chatroom_id = 0

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	CLOSING
}

var _ws_peer: WebSocketPeer
var _state: ConnectionState = ConnectionState.DISCONNECTED


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if not _ws_peer:
		return

	_ws_peer.poll()
	var new_ws_state = _ws_peer.get_ready_state()

	if new_ws_state == WebSocketPeer.STATE_OPEN:
		if _state == ConnectionState.CONNECTING:
			_state = ConnectionState.CONNECTED
			print("KickChat: WebSocket connection established.")
			connection_established.emit()
			_subscribe_to_channels(chatroom_id)


		while _ws_peer.get_available_packet_count() > 0:
			var packet = _ws_peer.get_packet().get_string_from_utf8()
			_handle_incoming_message(packet)

	elif new_ws_state == WebSocketPeer.STATE_CLOSING:
		_state = ConnectionState.CLOSING

	elif new_ws_state == WebSocketPeer.STATE_CLOSED:
		if _state != ConnectionState.DISCONNECTED:
			var code = _ws_peer.get_close_code()
			var reason = _ws_peer.get_close_reason()
			print("KickChat: WebSocket connection closed. Code: %d, Reason: %s" % [code, reason])
			_cleanup()
			connection_closed.emit(code, reason)

func connect_to_chat(username: String = ""):
	if username == "":
		printerr("KickChat: Please enter a username.")
		return

	var url = "https://kick.com/api/v2/channels/" + username + "/chatroom"
	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(_on_chat_http_completed)
	http.request(url)

func _connect_to_chat(id: int = 0) -> void:
	if id > 0:
		chatroom_id = id

	if chatroom_id <= 0:
		printerr("KickChat: Cannot connect without a valid chatroom_id.")
		return

	if _state != ConnectionState.DISCONNECTED:
		push_warning("KickChat: Already connected or connecting. Please disconnect first.")
		return

	print("KickChat: Connecting to chatroom %d..." % chatroom_id)
	_state = ConnectionState.CONNECTING
	_ws_peer = WebSocketPeer.new()
	var err = _ws_peer.connect_to_url(KICK_PUSHER_URL)
	if err != OK:
		printerr("KickChat: Failed to initiate WebSocket connection. Error: %s" % err)
		_cleanup()
		connection_error.emit()


## Closes the WebSocket connection cleanly.
func disconnect_ws() -> void:
	if _ws_peer:
		_ws_peer.close(1000, "User requested disconnect.")
		_state = ConnectionState.CLOSING


## Internal function to parse messages from the WebSocket.
func _handle_incoming_message(message_str: String) -> void:
	var json = JSON.parse_string(message_str)
	if not json:
		push_warning("KickChat: Received non-JSON message: " + message_str)
		return

	var event_type = json.get("event")
	#print(json)
	#print(event_type)

	match event_type:
		"pusher:ping":
			_ws_peer.send_text('{"event":"pusher:pong","data":{}}')

		"pusher_internal:subscription_succeeded":
			var channel_name = json.get("channel", "")
			print("KickChat: Successfully subscribed to channel '%s'" % channel_name)
			subscribed_to_channel.emit(channel_name)

		"App\\Events\\ChatMessageEvent":
			var inner_data_str = json.get("data", "{}")
			var message_payload = JSON.parse_string(inner_data_str)
			if message_payload:
				chat_message_received.emit(event_type, message_payload)

		"RewardRedeemedEvent":
			var raw_data = json.get("data", "")
			if typeof(raw_data) == TYPE_STRING:
				var parsed_data = JSON.parse_string(raw_data)
				if parsed_data:
					chat_message_received.emit(event_type, parsed_data)



		## You can add more 'match' cases here to handle other events like
		## "App\\Events\\SubscriptionEvent", "App\\Events\\GiftedSubscriptionsEvent", etc.
		## The link below shows all of the routes if you want to add any more
		## https://gist.github.com/Digital39999/ffe7df2bfc08797c2ba19d42e8f739a0
		## You can obviously open the inspect element at whatever channel then filter by websocket to get the data directly from kick.


## Sends the subscription requests to Pusher after connection is established.
func _subscribe_to_channels(id: int) -> void:
	# this usually handles the chat
	var channel_v2 = "chatrooms.%d.v2" % id
	var payload_v2 = {
		"event": "pusher:subscribe",
		"data": { "auth": "", "channel": channel_v2 }
	}
	_ws_peer.send_text(JSON.stringify(payload_v2))

	# this is for mostly everything else (redeems, subscriptions, polls, etc.)
	var channel = "chatroom_%d" % id
	var payload = {
		"event": "pusher:subscribe",
		"data": { "auth": "", "channel": channel }
	}
	_ws_peer.send_text(JSON.stringify(payload))



## Resets the state and peer object.
func _cleanup() -> void:
	_ws_peer = null
	_state = ConnectionState.DISCONNECTED

func _on_chat_http_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			# print(json)
			_connect_to_chat(json["id"])
		else:
			print("could not JSON")
	else:
		print("There was an error with the HTTP request. Code: %d" % response_code)
