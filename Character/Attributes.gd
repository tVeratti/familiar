extends Object
class_name Attributes

# Declare member variables here. Examples:
var current_xp = 0
var current_level = 1


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func xp_added():
	self.current_xp += 5
	check_level()

func check_level():
	if self.current_xp >= 100:
		self.current_level += 1
		self.current_xp = (self.current_xp-100)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
