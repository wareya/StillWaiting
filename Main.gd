extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var levelgen = preload("res://Levelgen.tscn").instance()

# Called when the node enters the scene tree for the first time.
func _ready():
    $GridMap.clear()
    add_child(levelgen)
    levelgen.gen_level($GridMap)
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    pass
