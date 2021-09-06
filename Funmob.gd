extends QuakelikeBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var state = "idle"
# Called when the node enters the scene tree for the first time.
func _ready():
    animator.playback_default_blend_time = 0.15
    animator.get_animation("Walk").loop = true
    animator.get_animation("Run").loop = true
    var idle_anim : Animation = animator.get_animation("Idle")
    idle_anim.loop = true
    animator.play("Idle")
    state = "idle"
    rng.randomize()
    pass # Replace with function body.

onready var animator : AnimationPlayer = $Holder/Leela.get_node("AnimationPlayer")

# Called every frame. 'delta' is the elapsed time since the previous frame.
var distance_sunken = 0
var alertness_time = 0
var chase_target = null

var velocity = Vector3()
var accel = 6

var attack_damage = 4

var hp = 16
var hp_max = 16

func play_attack_anim():
    animator.play("SwordSlash", -1, 0.75)
    state = "attack"
    yield(get_tree().create_timer(0.5), "timeout")
    if state == "attack" and hp > 0 and animator.current_animation == "SwordSlash":
        for target in $Holder/Hitcast.get_overlapping_bodies():
            target.apply_damage(self, attack_damage)
            if target == chase_target and target.hp <= 0:
                chase_target = null

var idle_timer = INF
var idle_time = [4, 8]
var wander_range = [1, 4]
var spawn_location = Vector3(INF, INF, INF)
var wander_target = Vector3()
var wander_time = 0

func check_alertness():
    var dist_to_spawn = spawn_location.distance_to(global_transform.origin)
    for player in get_tree().get_nodes_in_group("Player"):
        if player.hp <= 0:
            continue
        $Finder.look_at(player.get_origin(), Vector3.UP)
        if $Finder.global_transform.basis.z.dot($Holder.global_transform.basis.z.normalized()) < 0.5:
            #print("backwards")
            continue
        
        var dist = global_transform.origin.distance_to(player.global_transform.origin)
        if dist > 10 or (dist > 5 and dist_to_spawn > 10):
            continue
        
        var target : Node = $Finder.get_collider()
        #print(target)
        if state != "alert":
            if target == player:
                state = "alert"
                alertness_time = 0
                chase_target = player
                animator.play("Yes")
                #print("yes")
        elif alertness_time > 1.4:
            if target == player:
                state = "chase"
            else:
                state = "wander"

func new_wander_target():
    state = "wander"
    var dir = rng.randf_range(0, PI*2)
    var dist = rng.randf_range(wander_range[0], wander_range[1])+1
    wander_target = spawn_location + Vector3(cos(dir), 0, sin(dir))*dist
    wander_time = 0

var short_idle = false
var wander_cutoff = -1

var rng = RandomNumberGenerator.new()

func randomize_angle():
    $Holder.rotation.y = rng.randf()*PI*2

var first_frame = true
func _process(delta):
    if first_frame:
        custom_move_and_slide(1.0, Vector3.DOWN*0.25)
    first_frame = false
    
    if delta <= 0.0 or SaveData.gamestate == "paused":
        # no remorse
        return
    
    if spawn_location == Vector3(INF, INF, INF):
        spawn_location = global_transform.origin
    
    $BBViewport/Stuffholder/Bar.value = hp
    $BBViewport/Stuffholder/Bar.max_value = hp_max
    $Billboard.pixel_size = 2.0/720.0*tan(deg2rad(70.0/2.0))
    
    if state == "sink":
        var sink_by = 0.1*delta
        transform.origin.y -= sink_by
        $Billboard.modulate.a = 1.0-distance_sunken*2
        distance_sunken += sink_by
        if distance_sunken > 2:
            queue_free()
        return
    if state == "idle":
        #print("idling")
        #print(idle_time)
        if animator.current_animation != "Idle":
            idle_timer = INF
            animator.play("Idle")
        check_alertness()
        #print("idle timer: " + str(idle_timer))
        if idle_timer == INF:
            if short_idle:
                idle_timer = 1
            else:
                idle_timer = rng.randf_range(idle_time[0], idle_time[1])
            short_idle = false
        if idle_timer != INF:
            idle_timer -= delta
        if idle_timer <= 0:
            idle_timer = INF
            new_wander_target()
        #print(idle_timer)
    
    if state == "alert" or state == "chase":
        var oldbasis = $Holder.global_transform
        $Holder.look_at(chase_target.get_origin(), Vector3.UP)
        $Holder.rotation.x = 0
        $Holder.rotation.z = 0
        var newbasis = $Holder.global_transform
        newbasis = oldbasis.interpolate_with(newbasis, 1.0 - pow(0.001, delta))
        $Holder.global_transform = newbasis
    
    if state == "wander":
        var oldbasis = $Holder.global_transform
        $Holder.look_at(wander_target, Vector3.UP)
        $Holder.rotation.x = 0
        $Holder.rotation.z = 0
        var newbasis = $Holder.global_transform
        newbasis = oldbasis.interpolate_with(newbasis, 1.0 - pow(0.001, delta))
        $Holder.global_transform = newbasis
    
    if state == "alert":
        alertness_time += delta
        check_alertness()
    
    var oldvel = velocity
    
    if state == "wander":
        var wanderdist = global_transform.origin.distance_to(wander_target)
        #print(wanderdist)
        var walk_dir = -$Holder.global_transform.basis.z
        walk_dir.y = 0
        walk_dir = walk_dir.normalized()
        var origin_delta = (wander_target-global_transform.origin)
        origin_delta.y = 0
        origin_delta = origin_delta.normalized()
        var dot = walk_dir.dot(origin_delta)
        if wanderdist > 1:# and !is_on_wall():
            wander_time += delta
            if !animator.current_animation == "Walk":
                animator.play("Walk")
            #print("asdf")
            if dot > 0.9:
                accel = 20
                velocity += walk_dir*accel*delta
        else:
            state = "idle"
        if is_on_wall():
            if wander_cutoff < 0:
                wander_cutoff = 0.0
            wander_cutoff += delta
            #if rng.randf() < 0.25:
            #    print("wanderdist and dot " + str(wanderdist) + " " + str(wander_time) + " " + str(dot))
            #    pass
            if wander_time > 0.0 and wander_time < 0.25:
                short_idle = true
                #print("short idle")
            if wander_cutoff > 0.5:
                state = "idle"
        else:
            wander_cutoff = -1
        check_alertness()
    
    if state == "chase":
        var dist = global_transform.origin.distance_to(chase_target.global_transform.origin)
        var dist_to_spawn = spawn_location.distance_to(global_transform.origin)
        if dist > 10 or (dist > 5 and dist_to_spawn > 10):
            state = "wander"
        elif dist > 1:
            if !animator.current_animation == "Run":
                animator.play("Run")
            #print("asdf")
            var walk_dir = -$Holder.global_transform.basis.z
            walk_dir.y = 0
            walk_dir = walk_dir.normalized()
            accel = 20
            velocity += walk_dir*accel*delta
        else:
            if !animator.current_animation == "Walk":
                animator.play("Walk")
            var their_angle = global_transform.origin.direction_to(chase_target.global_transform.origin)
            their_angle.y = 0
            their_angle = their_angle.normalized()
            var my_angle = -$Holder.global_transform.basis.z
            my_angle.y = 0
            my_angle = my_angle.normalized()
            var dot = their_angle.dot(my_angle)
            #print("---dot:")
            #print(dot)
            if dot > 0.9:
                play_attack_anim()
    
    if state == "attack":
        if !animator.is_playing():
            if chase_target != null:
                state = "chase"
            else:
                state = "idle"
    
    if state == "flinch":
        if !animator.is_playing():
            state = "chase"
    
    velocity *= pow(0.0001, delta)
    
    custom_move_and_slide(delta, velocity)



func apply_damage(source : Node, damage):
    if damage > 0 and hp > 0:
        if state == "idle" or state == "wander":
            state = "chase"
        chase_target = source
        hp -= damage
        hp = max(hp, 0)
        if rng.randf() < 0.5:
            state = "flinch"
            animator.play("HitRecieve_1")
    if hp <= 0:
        if state != "dead":
            state = "dead"
            animator.play("Death")
            yield(get_tree().create_timer(1.0), "timeout")
            $Collider.disabled = true
            $Blocker/Collider.disabled = true
            if animator.is_playing():
                yield(animator, "animation_finished")
            state = "sink"
            SaveData.check_victory_sequence()
