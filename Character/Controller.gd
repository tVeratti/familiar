extends KinematicBody2D

const ACCELERATION = 200
const ACCELERATION_AIR = 1
const GRAVITY = 2000

const FRICTION = 0.2
const FRICTION_AIR = 0.1

const SPEED_NORMAL = 400
const SPEED_SPRINT = 600
const SPEED_CLIMB = 700

const MAX_JUMP_FORCE = 1000
const JUMP_CHARGE_RATE = 30
const JUMP_CHARGE_DEADZONE = JUMP_CHARGE_RATE * 10
const JUMP_VELOCITY_ACCELERATION = 0.2

const JUMP_VELOCITY_MAXIMUM = 10
const JUMP_VELOCITY_MINIMUM = 3

enum STATES { WAIT, CROUCH, WALK, SPRINT, JUMP, CLIMB }
var _state = STATES.WAIT

var _velocity = Vector2.ZERO
var _jump_velocity = Vector2.ZERO
var _jump_force = 0
var _jump_direction = 1
var _climb_started = false
var _climb_force = -ACCELERATION
var _climb_boost = true
var _climb_animate = true

var _gravity_direction = Vector2.DOWN

onready var _sprite:AnimatedSprite = $Sprite
onready var _jump_preview:Line2D = $Line2D
onready var _collision:CollisionShape2D = $CollisionShape2D

onready var _climbTimer:Timer = $ClimbTimer
onready var _animationTimer:Timer = $AnimationTimer

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
        
    if on_floor:
        if is_jumping: jump(direction)
        elif is_charging_jump: charge_jump(direction, on_wall)                
        else: move(direction, is_sprinting)
        
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
    if on_floor:
        _climb_started = false
    elif on_wall and not is_jumping:
        climb(direction, is_charging_jump)
    else:
        _gravity_direction = Vector2.DOWN

    _velocity += _gravity_direction * GRAVITY * delta
    #_velocity.y += GRAVITY * delta
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
       
    # Check if the player has collided with a surface.
    # Use the opposite of that surface's normal as the new gravity.
    var collision = move_and_collide(_velocity, true, true, true)
    if collision != null:
         _gravity_direction = -collision.normal
    
    if _climb_boost and direction != 0:
        _sprite.play('climb_boost')
        
        _animationTimer.start(0.4)
        _climbTimer.start(0.5)
        _climb_boost = false

        # Add a small amount of acceleration when climbing in either direction.
        _velocity.y -= SPEED_CLIMB
         
    else:
        _velocity.y = lerp(_velocity.y, 0, 0.15)
        
        if not _climb_animate:
            _climb_animate = true
            _sprite.play('climb')

    # Clamp climbing velocity within maximum speed range
    _velocity.y = min(_velocity.y, SPEED_CLIMB)
    _velocity.y = max(_velocity.y, -SPEED_CLIMB)
    

func set_state(new_state):
    if new_state == _state: return
    
    disable_collisions()
    
    _state = new_state
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


func _on_ClimbTimer_timeout():
    _climb_boost = true


func _on_AnimationTimer_timeout():
    _climb_animate = false
