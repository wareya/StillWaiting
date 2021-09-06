extends Area


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


var heal = 6
var spent = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    if spent:
        return
    rotation_degrees.y += delta*30
    global_transform.origin.y = sin(rotation.y*3)*0.1
    
    for _object in get_overlapping_bodies():
        var player : Node = _object
        if player.is_in_group("Player") and player.hp < player.max_hp:
            spent = true
            player.hp = min(player.hp + heal, player.max_hp)
            $FirstAidKit.visible = false
            $CollisionShape.disabled = true
            $Particles.emitting = false
            #queue_free()
            break
    pass
