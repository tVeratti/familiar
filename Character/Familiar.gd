extends KinematicBody2D

const AIR_BRAKE_ACCELERATION = 10
const ACCELERATION = 200
const ACCELERATION_AIR = 1
const GRAVITY = 2000

const FRICTION = 0.2
const AIR_FRICTION_NORMAL = 0.01
const AIR_FRICTION_BRAKE = 0.05

const SPEED_NORMAL = 400
const SPEED_SPRINT = 600
const SPEED_CLIMB = 200

const MAX_JUMP_FORCE = 900
const JUMP_CHARGE_RATE = 20
const JUMP_CHARGE_DEADZONE = 200

enum STATES { WAIT, WALK, SPRINT, JUMP, CLIMB }
var state = STATES.WAIT

var _velocity = Vector2.ZERO
var _gravity_direction = Vector2.DOWN
var _jump_direction = 0
var _jump_force = 0
var _initial_jump_force = 0
var _is_climbing = false

onready var _sprite:AnimatedSprite = $Sprite

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.

func _physics_process(delta):
    var is_on_floor = is_on_floor()
    var is_on_wall = is_on_wall()
    
    var is_moving_right = Input.is_action_pressed("right")
    var is_moving_left = Input.is_action_pressed("left")
    var is_sprinting = Input.is_action_pressed("sprint")
    
    var is_charging_jump = Input.is_action_pressed("jump")
    var is_jumping = Input.is_action_just_released("jump")
        
    if is_on_floor or is_on_wall:
        _is_climbing = false
        if is_charging_jump:
            _jump_force = min(_jump_force + JUMP_CHARGE_RATE, MAX_JUMP_FORCE)
            if _jump_force > JUMP_CHARGE_DEADZONE:
                _velocity.x = lerp(_velocity.x, 0, FRICTION)
                if abs(_velocity.x) < 200: _sprite.play("charge_jump")
            
            if is_moving_right: _sprite.flip_h = false
            elif is_moving_left: _sprite.flip_h = true
        else:
            if not is_jumping:
                _sprite.play("default")
                _initial_jump_force = 0
            if is_moving_right:
                _velocity.x += ACCELERATION
                _sprite.flip_h = false
            elif is_moving_left:
                _velocity.x -= ACCELERATION
                _sprite.flip_h = true
            else:
                _velocity.x = lerp(_velocity.x, 0, FRICTION)
            
        # Begin jumping if grounded
        if is_jumping:
            _jump_direction = 1 if is_moving_right else -1 if is_moving_left else 0
            _velocity.y = -(_jump_force + abs(_velocity.x / 2))
            _velocity.x += ACCELERATION * _jump_direction
            _initial_jump_force = _jump_force
            _jump_force = 0
    else:
        # Jumping in open space
        _is_climbing = false
        if _initial_jump_force > 500: _sprite.play("jump_high")
        else: _sprite.play("jump_far")
        
        if is_moving_right:
            _velocity.x += ACCELERATION_AIR
        elif is_moving_left:
            _velocity.x -= ACCELERATION_AIR
        else:
            _velocity.x = lerp(_velocity.x, 0, 0.05)
    
    # Move the kinematic body
#    if not is_on_wall or _velocity.y >= -1:
#        _gravity_direction = Vector2.DOWN
#    else:
#        var collision = move_and_collide(_velocity, true, true, true)
#        if collision != null:
#            _gravity_direction = -collision.normal
#
#        if is_moving_right: _velocity.y -= ACCELERATION * _gravity_direction.x
#        if is_moving_left: _velocity.y += ACCELERATION * _gravity_direction.x
#        else: _velocity.y = lerp(_velocity.y, 0, FRICTION * 2)
#
#        _velocity.y = min(_velocity.y, SPEED_CLIMB)
#        _velocity.y = max(_velocity.y, -SPEED_CLIMB)
#
#        _sprite.play("grip")
        
    # Clamp _velocity values
    var max_speed = SPEED_SPRINT if is_sprinting else SPEED_NORMAL
    _velocity.x = min(_velocity.x, max_speed)
    _velocity.x = max(_velocity.x, -max_speed)
    
    _velocity.y += GRAVITY * delta
    _velocity = move_and_slide(_velocity, Vector2.UP)

        
