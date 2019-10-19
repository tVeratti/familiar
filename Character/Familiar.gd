extends Node2D

# Declare member variables here. Examples:
var _attributes
onready var _controller = $Controller

# Called when the node enters the scene tree for the first time.
func _ready():
	_attributes = Attributes.new()
	print("current xp: " + str(_attributes.current_xp))
	print("current lvl: " + str(_attributes.current_level))

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _input(event):
	if Input.is_action_pressed("cheatz"):
		self._attributes.xp_added()
		print("current xp: " + str(_attributes.current_xp))
		print("current lvl: " + str(_attributes.current_level))
		