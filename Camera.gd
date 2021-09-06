extends ClippedCamera


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    
    pass # Replace with function body.

var mouselook_speed = -0.022*2.5
var mouse_motion = Vector2()

onready var holder = get_parent()

func _input(event):
    # Mouse in viewport coordinates.
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == 2:
            if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                holder.get_parent().enable_autocam()
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                holder.get_parent().disable_autocam()
    elif event is InputEventMouseMotion:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            mouse_motion += event.relative

var rotate_speed = 360
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    var y = holder.rotation_degrees.y
    var x = holder.rotation_degrees.x
    y += Input.get_action_strength("camera_right")*rotate_speed*delta
    y -= Input.get_action_strength("camera_left")*rotate_speed*delta
    x += Input.get_action_strength("camera_up")*rotate_speed*delta
    x -= Input.get_action_strength("camera_down")*rotate_speed*delta
    x += mouse_motion.y*mouselook_speed
    y += mouse_motion.x*mouselook_speed
    mouse_motion = Vector2()
    x = clamp(x, -80, 20)
    holder.rotation_degrees.y = y
    holder.rotation_degrees.x = x
    #if Input.get_action_strength("camera_right") == 0 and Input.get_action_strength("camera_left") == 0:
    #    if $LeftPush.get_overlapping_bodies().size() > 0:
    #        holder.rotate_y(-deg2rad(rotate_speed)*delta*0.1)
    #    if $RightPush.get_overlapping_bodies().size() > 0:
    #        holder.rotate_y( deg2rad(rotate_speed)*delta*0.1)
    #print("----")
    #print(holder.rotation_degrees.z)
    #print(holder.rotation_degrees.y)
    #print(holder.rotation_degrees.x)
    #if holder.rotation_degrees.x > 20:
    #    holder.rotation_degrees.x = 20
    #if holder.rotation_degrees.x < -80:
    #    holder.rotation_degrees.x = -80
    var distance = holder.rotation_degrees.x+80.0
    distance /= 100.0
    transform.origin.z = lerp(1.0, 5.0, 1.0-distance)
    look_at(holder.global_transform.origin, Vector3.UP)
    pass
