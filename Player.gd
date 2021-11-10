extends QuakelikeBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.

var has_compass = false
var rng = RandomNumberGenerator.new()

var blend = 0.15
func _ready():
    make_anim_loop("Run")
    make_anim_loop("Walk")
    make_anim_loop("Idle")
    animator.playback_default_blend_time = blend
    animator.play("Idle")
    rng.randomize()
    pass # Replace with function body.

var accel = 75
var max_speed = 4
var velocity = Vector3()
var gravity = -9.8*2
var jumpvel = 7
var lookdir = Vector3()

func reject_floor(vec : Vector3) -> Vector3:
    return velocity - velocity.project(Vector3.DOWN)

func reject(vec : Vector3, vec2 : Vector3) -> Vector3:
    return velocity - velocity.project(vec2)

var state = "control"
onready var animator : AnimationPlayer = $Warrior.get_node("AnimationPlayer")

func make_anim_loop(anim : String):
    var idle_anim : Animation = animator.get_animation(anim)
    idle_anim.loop = true

func randomize_angle():
    #print("randomizing angle")
    var angle = rng.randf()*PI*2
    $Warrior.rotation.y = angle
    lookdir.x = -sin(angle)
    lookdir.z = -cos(angle)
    #print(lookdir)
    $CameraHolder.rotation.y = angle

func play_attack_anim(animator : AnimationPlayer):
    #var ff = 4.0
    animator.play("Sword_Attack", 0.05, 1.5)
    animator.seek(0.15)
    
    yield(get_tree().create_timer(0.3), "timeout")
    if state == "attacking" and hp > 0 and animator.current_animation == "Sword_Attack":
        for target in $Hitcast.get_overlapping_bodies():
            #print("got a target: " + str(target))
            target.apply_damage(self, 5)
            pass
    #animator.playback_speed = ff
    #while animator.current_animation_position < 0.25 and animator.current_animation == "Sword_Attack" and animator.is_playing():
    #    yield(get_tree(), "idle_frame")
    #print(animator.playback_speed)
    #if animator.current_animation == "Sword_Attack":
    #    animator.playback_speed = 2.0
    pass

var actually_running = false

var hp = 32
var max_hp = 32

var disable_all_forces = false

func apply_damage(source : Node, dmg):
    if hp > 0 and state != "flinch":
        state = "flinch"
        animator.play("RecieveHit_Attacking", -1, 1.5)
        animator.seek(0.0)
        hp -= dmg
        hp = max(0, hp)
    if hp <= 0:
        if state != "dead":
            animator.play("Death")
            state = "dead"
            yield(get_tree().create_timer(1.0), "timeout")
            collision_layer = 0
            #$Hitcast/Collider.disabled = true
            disable_all_forces = true
            if animator.is_playing():
                yield(animator, "animation_finished")
        pass

func get_origin():
    return $Origin.global_transform.origin

var camsnap_time = 0.0
var camsnap_dir = 0.0

var autocam_enabled = true
func disable_autocam():
    autocam_enabled = false
func enable_autocam():
    autocam_enabled = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
var first_frame = true
var base_origin = Vector3()
var tip_origin = Vector3()
func _process(delta):
    if first_frame:
        #print("mapping down from " + str(global_transform.origin.y) + "...")
        custom_move_and_slide(0.5, Vector3.DOWN*0.25)
        #print(floor_collision)
    #print(global_transform.origin.y)
    first_frame = false
    
    if delta <= 0.0 or SaveData.gamestate == "paused":
        # no remorse
        return
    
    if state == "dead" and !animator.is_playing():
        SaveData.trigger_death_sequence()
        pass
    
    var wishdir : Vector3 = Vector3(0, 0, 0)
    if Input.is_action_pressed("ui_right"):
        wishdir += Vector3.RIGHT
    if Input.is_action_pressed("ui_left"):
        wishdir += Vector3.LEFT
    if Input.is_action_pressed("ui_up"):
        wishdir += Vector3.FORWARD
    if Input.is_action_pressed("ui_down"):
        wishdir += Vector3.BACK
    
    #wishdir += Vector3.RIGHT   * Input.get_action_strength("stick_right")
    #wishdir += Vector3.LEFT    * Input.get_action_strength("stick_left")
    #wishdir += Vector3.FORWARD * Input.get_action_strength("stick_up")
    #wishdir += Vector3.BACK    * Input.get_action_strength("stick_down")
    var asdf = Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down", 0.15)
    wishdir += Vector3(asdf.x, 0.0, asdf.y)
    
    if wishdir.length_squared() > 1:
        wishdir = wishdir.normalized()
    
    var raw_wishdir = wishdir
    
    wishdir = wishdir.rotated(Vector3.UP, $CameraHolder.rotation.y)
    
    var just_jumped = false
    if Input.is_action_just_pressed("jump") and is_on_floor() and state == "control":
        velocity.y = jumpvel
        just_jumped = true
        floor_collision = null
    
    var wishmod = 1.0
    if Input.is_action_just_pressed("attack") and state == "control":
        play_attack_anim(animator)
        state = "attacking"
    
    if state == "flinch":
        if !animator.is_playing():
            state = "control"
        wishmod = 0.0
    
    if state == "attacking":
        if !animator.is_playing():
            state = "control"
        wishmod = 0.1
    elif !is_on_floor():
        wishmod = 0.5
    
    if state == "dead":
        wishmod = 0.0
    
    var newvel = velocity
    if is_on_floor():
        newvel.x *= pow(0.0001, delta)
        newvel.z *= pow(0.0001, delta)
        if wishdir.length_squared() == 0.0:
            newvel.x *= pow(0.0001, delta)
            newvel.z *= pow(0.0001, delta)
    
    newvel += wishdir*delta*accel*wishmod
    if !is_on_floor():
        newvel.y += gravity*delta
    else:
        newvel.y += gravity*delta*0.01
    var force = newvel - velocity
    velocity += force/2
    if reject_floor(velocity).length_squared() > max_speed*max_speed:
        var v = reject_floor(velocity).normalized()
        velocity.x = v.x*max_speed
        velocity.z = v.z*max_speed
    
    
    var oldvel = velocity
    var oldpos = global_transform.origin
    
    if velocity.length_squared() > 0.0:
        velocity = custom_move_and_slide(delta, velocity)
    #    if just_jumped:
    #        velocity = move_and_slide(velocity, Vector3.UP, true, 4, PI*0.51, true)
    #    else:
    #        #velocity = move_and_slide(velocity, Vector3.UP, true, 4, PI*0.51, true)
    #        velocity = move_and_slide_with_snap(velocity, Vector3.DOWN*0.1, Vector3.UP, true, 4, PI*0.51, true)
    #        #velocity = move_and_slide_with_snap(velocity, Vector3.UP*0.1, Vector3.UP, true, 4, PI*0.51, true)
    
    var motion_delta = global_transform.origin - oldpos
    var actual_speed = motion_delta.length()/delta
    var not_moving = false
    if is_on_floor():
        if false:#actual_speed < 0.1:
            global_transform.origin = oldpos
            velocity = oldvel
            velocity.y = 0
            not_moving = true
    
    velocity += force/2
    
    #print(velocity)
    #print(is_on_floor())
    #if !is_on_floor():
    #    print(is_on_floor())
    #    print(velocity)
    
    #if reject_floor(velocity).length_squared() > max_speed*max_speed:
    #    var v = reject_floor(velocity).normalized()
    #    velocity.x = v.x*max_speed
    #    velocity.z = v.z*max_speed
    
    var hvel = Vector3(velocity.x, 0, velocity.z)
    var lookvec = hvel.normalized() + wishdir
    #print(wishdir.length())
    if wishdir.length() > 0.85:
        lookvec = wishdir
    
    #print(actual_speed)
    if hvel.length() > 0.2 and lookvec.length() > 0.2:
        if state == "control":
            if actual_speed < 0.2:
                lookdir = lerp(lookdir.normalized(), lookvec.normalized(), 1.0 - pow(0.01, delta))
            elif actual_speed < 0.4:
                lookdir = lerp(lookdir.normalized(), lookvec.normalized(), 1.0 - pow(0.000001, delta))
            elif actual_speed < 3.8 or wishdir.length() <= 0.85:
                lookdir = lerp(lookdir.normalized(), lookvec.normalized(), 1.0 - pow(0.0000000001, delta))
            else:
                lookdir = lookvec
            #lookdir = lookvec
        elif state == "attacking":
            if Input.is_action_just_pressed("attack") and animator.current_animation_position <= 0.2:
                lookdir = lookvec
            else:
                lookdir = lerp(lookdir.normalized(), lookvec.normalized(), 1.0 - pow(0.01, delta))
            pass
    $Warrior.rotation.y = atan2(lookdir.x, lookdir.z)
    
    var skip = blend*0.0010
    animator.playback_speed = 1.0
    if state == "control":
        if is_on_floor():
            if hvel.length() > 0.01 and !not_moving:
                if hvel.length() > max_speed/2:
                    if animator.current_animation == "Walk":
                        var old_position = animator.current_animation_position
                        animator.play("Run")
                        animator.seek(old_position)
                    elif animator.current_animation != "Run":
                        animator.play("Run")
                        #animator.advance(skip)
                    elif !actually_running:
                        animator.play("Run")
                    actually_running = true
                    #print("setting actually running")
                    animator.playback_speed = hvel.length()/max_speed
                else:
                    if animator.current_animation == "Run":
                        var old_position = animator.current_animation_position
                        animator.play("Walk")
                        animator.seek(old_position)
                    elif animator.current_animation != "Walk":
                        animator.play("Walk")
                        #animator.advance(skip)
                    animator.playback_speed = max(hvel.length()/1.5, 0.5)
            else:
                if animator.current_animation != "Idle":
                    animator.play("Idle")
                    #animator.advance(skip)
        else:
            var jump_animspeed = 0.2
            if actually_running:
                #print("skip mode")
                var old_pos = animator.current_animation_position
                animator.play("Run", blend, jump_animspeed)
                if animator.current_animation_position < 0.4 or animator.current_animation_position > 1.8:
                    animator.seek(0.35)
                else:
                    animator.seek(1.8)
            elif animator.current_animation != "Run":
                #print("skip mode 2")
                animator.play("Run", blend, jump_animspeed)
                animator.seek(0.35)
            actually_running = false
    
    var autocam_speed = 90
    if !not_moving and autocam_enabled:
        #var autocam_amount = -wishmod*delta*raw_wishdir.x*autocam_speed*(0.5+raw_wishdir.z/2)
        var autocam_amount = -wishmod*delta*raw_wishdir.x*autocam_speed
        var camdist = $CameraHolder.rotation_degrees.x+80.0
        camdist /= 100.0
        #print(camdist)
        autocam_amount *= camdist+1
        $CameraHolder.rotation_degrees.y += autocam_amount
        
        #if raw_wishdir.z < 0:
        #    $CameraHolder.rotation_degrees.y -= wishmod*delta*raw_wishdir.x*(1.0-raw_wishdir.z*raw_wishdir.z)*autocam_speed
        #else:
        #    $CameraHolder.rotation_degrees.y -= wishmod*delta*(1-pow(1-abs(raw_wishdir.x), 2))*sign(raw_wishdir.x)*autocam_speed
    var snap_speed = 5
    if Input.is_action_just_pressed("camsnap"):
        camsnap_time = 1
        camsnap_dir = $Warrior.rotation_degrees.y+180
    if camsnap_time > 0:
        if Input.get_action_strength("camera_right") > 0.5 or \
           Input.get_action_strength("camera_left") > 0.5 or \
           Input.get_action_strength("camera_up") > 0.5 or \
           Input.get_action_strength("camera_down") > 0.5:
            camsnap_time = 0
        
        camsnap_time -= delta
        var dir = camsnap_dir - $CameraHolder.rotation_degrees.y
        while dir > 180:
            dir -= 360
        while dir < -180:
            dir += 360
        $CameraHolder.rotation_degrees.y += dir*delta*snap_speed
        pass
    
    $Hitcast.rotation = $Warrior.rotation
    
    #print(velocity.length())
    #print(reject_floor(velocity).length())
    #var camera_lookdir = lookdir.rotated(Vector3.UP, -$CameraHolder.rotation.y)
    #camera_lookdir = camera_lookdir.rotated(Vector3.UP, deg2rad(180))
    #camera_lookdir = rad2deg(atan2(camera_lookdir.x, camera_lookdir.z))+180
    
    #if camera_lookdir < 90:
    #    $Sprite.frame = 0
    #    $Sprite.flip_h = false
    #elif camera_lookdir < 180:
    #    $Sprite.frame = 1
    #    $Sprite.flip_h = false
    #elif camera_lookdir < 270:
    #    $Sprite.frame = 1
    #    $Sprite.flip_h = true
    #else:
    #    $Sprite.frame = 0
    #    $Sprite.flip_h = true
    
    
    var bone : BoneAttachment
    var skeleton : Skeleton = $Warrior.find_node("Skeleton")
    var sword_transform = skeleton.get_bone_global_pose(skeleton.find_bone("Weapon.R"))
    $SwordHelper.transform = $Warrior.transform*sword_transform
    
    attempt_spawn_sword_mesh()
    
    #print(sword_transform)
    #if skeleton:
    #    for _child in skeleton.get_children():
    #        if not _child is BoneAttachment:
    #            continue
    #        var child : BoneAttachment = _child
    #        if child.bone_name 
    #        print(child)
    #    pass
    pass
    
func attempt_spawn_sword_mesh():
    var new_base_origin = $SwordHelper/Base.global_transform.origin
    var new_tip_origin  = $SwordHelper/Tip .global_transform.origin
    
    if state == "attacking" and animator.current_animation_position > 0.32 and animator.current_animation_position < 0.53:
        var mesh = SelfDestroyingMesh.new()
        mesh.data = [new_tip_origin, new_base_origin, base_origin, tip_origin]
        get_parent().add_child(mesh)
        mesh.cast_shadow = false
        mesh.material_override = SpatialMaterial.new()
        mesh.material_override.vertex_color_use_as_albedo = true
        mesh.material_override.params_cull_mode = SpatialMaterial.CULL_DISABLED
        mesh.material_override.flags_unshaded = true
        mesh.material_override.flags_vertex_lighting = true
        mesh.material_override.flags_transparent = true
        mesh.material_override.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
    
    base_origin = new_base_origin
    tip_origin  = new_tip_origin

class SelfDestroyingMesh extends ImmediateGeometry:
    var data
    var life = 1.0
    var opacity = 0.5
    func _process(delta):
        clear()
        var start_life = life
        life -= delta*4
        if life < 0:
            queue_free()
        else:
            begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
            set_color(Color(1.0, 1.0, 0.5, opacity*start_life*start_life))
            add_vertex(data[0])
            add_vertex(data[1])
            set_color(Color(1.0, 1.0, 0.5, opacity*life*life))
            add_vertex(data[3])
            add_vertex(data[2])
            #add_vertex(Vector3(0, 0, 0))
            #add_vertex(Vector3(0, 1, 0))
            #add_vertex(Vector3(1, 0, 0))
            #add_vertex(Vector3(1, 1, 0))
            end()
    
