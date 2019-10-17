extends KinematicBody2D

const ACCELERATION = 200
const ACCELERATION_AIR = 1
const GRAVITY = 2000

const FRICTION = 0.2
const FRICTION_AIR = 0.1

const SPEED_NORMAL = 400
const SPEED_SPRINT = 600
const SPEED_CLIMB = 200

const MAX_JUMP_FORCE = 1000
const JUMP_CHARGE_RATE = 30
const JUMP_CHARGE_DEADZONE = JUMP_CHARGE_RATE * 10
const JUMP_VELOCITY_ACCELERATION = 0.2

const JUMP_VELOCITY_MAXIMUM = 10
const JUMP_VELOCITY_MINIMUM = 3

enum STATES { WAIT, CROUCH, WALK, SPRINT, JUMP, CLIMB }
var state = STATES.WAIT

var _velocity = Vector2.ZERO
var _jump_velocity = Vector2.ZERO
var _jump_force = 0
var _jump_direction = 1
var _climb_started = false
var _climb_force = -ACCELERATION

var _gravity_direction = Vector2.DOWN

onready var _sprite:AnimatedSprite = $Sprite
onready var _jump_preview:Line2D = $Line2D
onready var _collision:CollisionShape2D = $CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready():
    set_state(STATES.WALK)
    reset_jump_velocity()


func _physics_process(delta):
    var on_floor = is_on_floor()
    var on_wall = is_on_wall()
    
    var is_moving_right = Input.is_action_pressed("right")
    var is_moving_left = Input.is_action_pressed("left")
    var is_sprinting = Input.is_action_pressed("sprint")
    
    var is_charging_jump = Input.is_action_pressed("jump")
    var is_jumping = Input.is_action_just_released("jump")

    var direction = 1 if is_moving_right else -1 if is_moving_left else 0
    if direction != 0: _jump_direction = direction
        
    if on_floor or on_wall:
        
        if is_jumping: jump(direction)
        elif is_charging_jump: charge_jump(direction, on_wall)
        else: move(direction, is_sprinting)
                
        # Flip sprite based on movement direction
        if not on_wall:
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
    if not on_wall:
        _gravity_direction = Vector2.DOWN
        _climb_started = false
    elif not is_jumping:
        climb(direction, is_charging_jump)

    #_velocity += _gravity_direction * GRAVITY * delta
    _velocity.y += GRAVITY * delta
    _velocity = move_and_slide(_velocity, Vector2.UP)

        
func charge_jump(direction, on_wall):
    # Update jump force (cumulative)
    # The jump forve will be applied to the jump velocity.
    _jump_force = min(_jump_force + JUMP_CHARGE_RATE, MAX_JUMP_FORCE)
    
    if _jump_force > JUMP_CHARGE_DEADZONE:
        if direction != 0:
            # Increase horizontal velocity
            _jump_velocity.x = min(
                _jump_velocity.x + 0.2,
                JUMP_VELOCITY_MAXIMUM)
        else:
            # Reduce horizontal velocity
            _jump_velocity.x = max(
                _jump_velocity.x - 0.2,
                0)
    
        # Slowly build y velocity, always
        _jump_velocity.y = min(
            _jump_velocity.y + 0.1,
            JUMP_VELOCITY_MAXIMUM)

        # Slow down and crouch...
        _velocity.x = lerp(_velocity.x, 0, FRICTION)
        if abs(_velocity.x) < 200 and not on_wall:
            set_state(STATES.CROUCH)
    
    _jump_preview.points = [
        Vector2.ZERO,
        (Vector2(
            _jump_velocity.x * _jump_direction,
            _jump_velocity.y * -1).normalized() * _jump_force) /10]


func jump(direction):
    set_state(STATES.JUMP)

    # Get the clamped jump force with x velocity to boost it.
    var launch_force = max(_jump_force, JUMP_CHARGE_DEADZONE) + abs(_velocity.x / 2)
    var launch_velocity = _jump_velocity
    
    # Adjust jump to the charged direction at time of release.
    launch_velocity.x *= _jump_direction
    
    # Make sure the y velocity is always upward (negative).
    launch_velocity.y = -abs(launch_velocity.y)
    
    # Normalize the velocity to blend the directions and avoid
    # abuse of additive diagonal velocity.
    launch_velocity = launch_velocity.normalized()
    
    # Multiply the normalized velocity to get the distance of
    # the charged jump force.
    launch_velocity *= launch_force
    
    # Add in current x velocity to get momentum bonus.
    launch_velocity.x += _velocity.x
       
    _velocity = launch_velocity
    
    # Reset jump forces
    reset_jump_velocity()


func reset_jump_velocity():
    _climb_force = 0
    _jump_preview.clear_points()
    _jump_force = 0
    _jump_velocity = Vector2(
        JUMP_VELOCITY_MINIMUM * 1.5,
        JUMP_VELOCITY_MINIMUM)


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


func climb(direction, is_charging_jump):
    set_state(STATES.CLIMB)
    
    if not _climb_started:
        _climb_started = true
        _climb_force = abs(min(min(_velocity.y, 0) + abs(_velocity.x  / 2), 1000))
    
    _climb_force = max(_climb_force - 10, -ACCELERATION)
    
    # Check if the player has collided with a surface.
    # Use the opposite of that surface's normal as the new gravity.
    var collision = move_and_collide(_velocity, true, true, true)
    if collision != null:
         _gravity_direction = -collision.normal
    
    if not is_charging_jump:
        # Add a small amount of acceleration when climbing in either direction.
        if direction == 1: _velocity.y -= ACCELERATION * _gravity_direction.x
        if direction == -1: _velocity.y += ACCELERATION * _gravity_direction.x
    
        # Clamp climbing velocity within maximum speed range
        _velocity.y = min(_velocity.y, SPEED_CLIMB)
        _velocity.y = max(_velocity.y, -SPEED_CLIMB)
        
        _velocity.y -= _climb_force
    

func set_state(new_state):
    if new_state == state: return
    
    disable_collisions()
    
    state = new_state
    match(new_state):
        STATES.WAIT:
            _sprite.play('walk')
            $WalkCollision.disabled = false
        STATES.CROUCH:
            _sprite.play('crouch')
            $CrouchCollision.disabled = false
        STATES.WALK:
            _sprite.play('walk')
            $WalkCollision.disabled = false
        STATES.SPRINT:
            _sprite.play('walk')
            $WalkCollision.disabled = false
        STATES.JUMP:
            if _jump_direction == 1: _sprite.flip_h = false
            elif _jump_direction == -1: _sprite.flip_h = true
            
            if _jump_velocity.x > _jump_velocity.y:
                _sprite.play('jump_horizontal')
                $JumpHorizontalCollision.disabled = false
            else:
                _sprite.play('jump_vertical')
                $JumpVerticalCollision.disabled = false
        STATES.CLIMB:
            _sprite.play('climb')
            $ClimbCollision.disabled = false


func disable_collisions():
    for child in get_children():
        if child is CollisionShape2D:
            child.disabled = true