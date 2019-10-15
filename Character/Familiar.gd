extends KinematicBody2D

const ACCELERATION = 200
const ACCELERATION_AIR = 1
const GRAVITY = 2000

const FRICTION = 0.2
const FRICTION_AIR = 0.1

const SPEED_NORMAL = 400
const SPEED_SPRINT = 600

const MAX_JUMP_FORCE = 1000
const JUMP_CHARGE_RATE = 30
const JUMP_CHARGE_DEADZONE = JUMP_CHARGE_RATE * 5
const JUMP_VELOCITY_ACCELERATION = 0.2

const JUMP_VELOCITY_MAXIMUM = 10
const JUMP_VELOCITY_MINIMUM = 3

enum STATES { WAIT, CROUCH, WALK, SPRINT, JUMP, CLIMB }
var state = STATES.WAIT

var _velocity = Vector2.ZERO
var _jump_force = 0
var _jump_velocity = Vector2.ZERO
var _jump_direction = 0

onready var _sprite:AnimatedSprite = $Sprite
onready var _jump_preview:Line2D = $Line2D

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.

func _physics_process(delta):
    var on_floor = is_on_floor()
    var on_wall = is_on_wall()
    
    var is_moving_right = Input.is_action_pressed("right")
    var is_moving_left = Input.is_action_pressed("left")
    var is_sprinting = Input.is_action_pressed("sprint")
    
    var is_charging_jump = Input.is_action_pressed("jump")
    var is_jumping = Input.is_action_just_released("jump")

    var direction = 1 if is_moving_right else -1 if is_moving_left else 0
        
    if on_floor:
        if is_jumping: jump(direction)
        elif is_charging_jump: charge_jump(direction)
        else: move(direction, is_sprinting)
        
        # Flip sprite based on movement direction
        if is_moving_right: _sprite.flip_h = false
        elif is_moving_left: _sprite.flip_h = true
    
    else:
        if is_moving_right:
            _velocity.x += ACCELERATION_AIR
        elif is_moving_left:
            _velocity.x -= ACCELERATION_AIR
        else:
            _velocity.x = lerp(_velocity.x, 0, FRICTION_AIR)
    
    # Move the kinematic body
    # if not on_wall or _velocity.y >= -1:
    #     _gravity_direction = Vector2.DOWN
    # else:
    #     var collision = move_and_collide(_velocity, true, true, true)
    #     if collision != null:
    #         _gravity_direction = -collision.normal

    #     if is_moving_right: _velocity.y -= ACCELERATION * _gravity_direction.x
    #     if is_moving_left: _velocity.y += ACCELERATION * _gravity_direction.x
    #     else: _velocity.y = lerp(_velocity.y, 0, FRICTION * 2)

    #     _velocity.y = min(_velocity.y, SPEED_CLIMB)
    #     _velocity.y = max(_velocity.y, -SPEED_CLIMB)

    #     _sprite.play("grip")
    
    _velocity.y += GRAVITY * delta
    _velocity = move_and_slide(_velocity, Vector2.UP)

        
func charge_jump(direction):
    # Update jump force (cumulative)
    # The jump forve will be applied to the jump velocity.
    _jump_force = min(_jump_force + JUMP_CHARGE_RATE, MAX_JUMP_FORCE)
    
    if _jump_force > JUMP_CHARGE_DEADZONE:
        if direction != 0:
            _jump_direction = direction
            # Increase horizontal velocity
            _jump_velocity.x = min(
                _jump_velocity.x + 0.2,
                JUMP_VELOCITY_MAXIMUM)
        else:
            # Reduce horizontal velocity
            _jump_velocity.x = max(
                _jump_velocity.x - 0.2,
                JUMP_VELOCITY_MINIMUM)
        
        if _jump_velocity.x <= JUMP_VELOCITY_MINIMUM:
            _jump_direction = 0
    
        # Slowly build y velocity, always
        _jump_velocity.y = min(
            _jump_velocity.y + 0.1,
            JUMP_VELOCITY_MAXIMUM)

        # Slow down and crouch...
        _velocity.x = lerp(_velocity.x, 0, FRICTION)
        if abs(_velocity.x) < 200: set_state(STATES.CROUCH)
    
    _jump_preview.points = [
        Vector2.ZERO,
        (Vector2(
            _jump_velocity.x * _jump_direction,
            _jump_velocity.y * -1).normalized() * _jump_force) /10]


func jump(direction):
    set_state(STATES.JUMP)

    # Apply direction to jump velocity
    _jump_velocity.x *= _jump_direction
    
    _jump_velocity = _jump_velocity.normalized()
    _jump_velocity *= _jump_force
    
    _velocity = Vector2(
        _velocity.x + _jump_velocity.x,
        -abs(_jump_velocity.y))
    
    # Reset jump forces
    _jump_force = 0
    _jump_velocity = Vector2.ZERO


func move(direction, is_sprinting):
    set_state(STATES.SPRINT if is_sprinting else STATES.WALK)

    if direction != 0:
        _velocity.x += direction * ACCELERATION
    else:
        _velocity.x = lerp(_velocity.x, 0, FRICTION)
    
    # Clamp _velocity values
    var max_speed = SPEED_SPRINT if is_sprinting else SPEED_NORMAL
    _velocity.x = min(_velocity.x, max_speed)
    _velocity.x = max(_velocity.x, -max_speed)


func set_state(new_state):
    #var prev_state = state
    state = new_state
    match(new_state):
        STATES.WAIT:
            _sprite.play('walk')
        STATES.CROUCH:
            _sprite.play('crouch')
        STATES.WALK:
            _sprite.play('walk')
        STATES.SPRINT:
            _sprite.play('sprint')
        STATES.JUMP:
            _sprite.play('jump')
        STATES.CLIMB:
            _sprite.play('climb')