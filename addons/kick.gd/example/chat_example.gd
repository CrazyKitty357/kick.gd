extends Node
@onready var kick_chat: KickChat = $KickChat
@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer

func _ready() -> void:
	kick_chat.connect_to_chat("crazykitty")



func _on_kick_chat_chat_message_received(message_type: String, message_data: Dictionary) -> void:
	print("%s\n%s\n\n" % [message_type, message_data])
	if message_type == "App\\Events\\ChatMessageEvent":
		_add_to_chatbox(message_data)
		
		## Here you can add custom logic for commands
		if message_data["content"].containsn("!test"):
			test_command()
	
	## You can add your point redeems here, (make sure they don't have the same name)
	if message_type == "RewardRedeemedEvent":
		if message_data["reward_title"] == "test":
			test_redeem(message_data["username"])
	

func _add_to_chatbox(message_data: Dictionary):
	var message_box = RichTextLabel.new()
	message_box.bbcode_enabled = true
	message_box.fit_content = true
	var color = message_data["sender"]["identity"]["color"]
	var text = "[color=" + color + "]" + message_data["sender"]["username"] + "[/color]" + ": " + message_data["content"]
	if message_data["content"].containsn("!test"):
		pass
	else:
		message_box.text = text
		$ScrollContainer/VBoxContainer.add_child(message_box)
		var bottom = $ScrollContainer.get_v_scroll_bar().max_value
		$ScrollContainer.set_v_scroll(bottom)

func test_command():
	print("test command successful!")

func test_redeem(username: String):
	print("%s has used the test redeem!" % username)
