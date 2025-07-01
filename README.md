# kick.gd

a port of [kick](https://kick.com)'s webhooks in godot.

## How to use

1. make a node in a new scene (ideally called KickChat)
2. drag the KickChat.gd found in the example onto the newly created node
3. on `func _ready():` do `kick_chat.connect_to_chat("yourchannelname")`
4. you can read the code / open the project on godot 4.4.1 or newer to learn how this all works and how to add more functionallity to make it work with your own projects, which is something that I recommend.