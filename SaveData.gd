extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


var gamestate = "playing"

func reset_overlays():
    $DeathOverlay.modulate.a = 0.0
    $VictoryOverlay.modulate.a = 0.0
    $HUD.modulate.a = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
    reset_overlays()
    get_tree()

var player = null
func cache_player():
    var players = get_tree().get_nodes_in_group("Player")
    if players.size() > 0:
        player = players[0]

func _process(delta):
    var players = get_tree().get_nodes_in_group("Player")
    if players.size() > 0:
        player = players[0]
        $HUD.visible = true
        $HUD/HPBar.value = player.hp
        $HUD/HPBar.max_value = player.max_hp
        $HUD/HPBar/Text.bbcode_text = "[center]" + str(player.hp) + "/" + str(player.max_hp) + "[/center]"
    else:
        $HUD.visible = false
    
    pass

func check_victory_sequence():
    cache_player()
    if $VictoryOverlay.modulate.a == 0.0:
        var living_enemies = 0
        for enemy in get_tree().get_nodes_in_group("Enemy"):
            if enemy.hp > 0:
                living_enemies += 1
        if living_enemies == 0 and player and player.hp > 0:
            $OverlayAnimator.play("Victory")
            yield($OverlayAnimator, "animation_finished")
            yield(get_tree().create_timer(2.0), "timeout")
            get_tree().reload_current_scene()
            reset_overlays()

func trigger_death_sequence():
    if $DeathOverlay.modulate.a == 0.0:
        $OverlayAnimator.play("Death")
        yield($OverlayAnimator, "animation_finished")
        yield(get_tree().create_timer(2.0), "timeout")
        get_tree().reload_current_scene()
        reset_overlays()
    pass
