require 'gosu'
require 'states'
require 'util'

class Banana
  include States
  attr_accessor :animation_states, :direction, :animation_state, :window, :y_pos, :jumping, :estimated_x_pos, :points
  states :jumping_up, :jumping_down, :on_ground
  
  def initialize(window)
    self.animation_states = [1,2,3]
    self.direction = :left
    self.animation_state = animation_states.first
    self.window = window
    self.y_pos = 400
    self.jumping = false
    self.state = :on_ground
    self.estimated_x_pos = 400
    self.points = 0
  end
  
  # protocol: images
  
  def image
    @cache ||= cache_images
    @cache["#{direction.to_s}-#{animation_state.to_s}"]
  end
  
  def cache_images
    @cache = {}
    [:left, :right].each do |dir|
      animation_states.each do |anim_state|
        @cache["#{dir.to_s}-#{anim_state}"] = Gosu::Image.new window, "sprites/#{dir.to_s}-banana-#{anim_state.to_s}.png", true
      end
    end
    @cache
  end
  
  def layer
    10
  end
  
  # protocol: general movement
  
  def turn(direction)
    self.direction = direction
  end
  
  def turn_left
    self.direction = :left
  end
  
  def turn_right
    self.direction = :right
  end
  
  def forward
    animation_state < animation_states.length ? self.animation_state += 1 : self.animation_state = 1
  end
  
  def update_estimate_x_position(amount)
    self.estimated_x_pos += amount
  end
  
  # protocol: jumping
  
  def jump!
    self.jumping = true
    changes :from => [:on_ground], :to => :jumping_up if on_ground?
  end
  
  def stop_jumping!
    self.jumping = false
  end
  
  def hit_power_up!(power_up)
    self.points += power_up.points
  end
  
  def jumping?
    jumping
  end
  
  def max_jump_height
    @max_jump_height ||= 300
  end
  
  def ground_position
    400
  end
  
  def on_ground?
    state == :on_ground
  end
  
  def jumping_up?
    state == :jumping_up
  end
  
  def jumping_down?
    state == :jumping_down
  end
  
  def change_to_on_ground_if_finished_jumping
    if jumping_down? and @y_pos > ground_position
      changes :from => [:jumping_down], :to => :on_ground
      self.jumping = false
    end
  end
  
  def velocity
    changes :from => [:jumping_up], :to => :jumping_down if jumping_up? and @y_pos < max_jump_height
    change_to_on_ground_if_finished_jumping
    if jumping_up?
      -5
    elsif jumping_down?
      5
    else
      0
    end
  end
  
  def jump_position
    @y_pos += velocity
    @y_pos
  end
  
  def y_pos
    if jumping?
      jump_position
    else
      @y_pos = 400
      @y_pos
    end
  end
  
  # protocol: collision
  
  def rect
    Rect.new :x1 => estimated_x_pos, :y1 => y_pos, :x2 => estimated_x_pos + 100, :y2 => y_pos + 163
  end
  
  def collides_with?(watching_rect)
    rect.collide?(watching_rect)
  end
end

class PowerUp
  attr_accessor :rect, :name, :hit, :window, :points
  
  def initialize(window, options)
    self.rect = Rect.new options
    self.name = options[:name]
    self.hit = false
    self.window = window
    self.points = options[:points]
    self.points ||= 20
  end
  
  def hit?
    hit
  end
  
  def hit!
    rect.y1 -= 20 unless hit
    self.hit = true
  end
  
  def image
    hit? ? hit_image : available_image
  end
  
  def available_image
    @available_image ||= Gosu::Image.new window, "sprites/power-up.png", true
  end
  
  def hit_image
    @hit_image ||= Gosu::Image.new window, "sprites/power-up-hit.png", true
  end
  
  def layer
    10
  end
end

class Background
  attr_accessor :position, :window
  
  def initialize(window)
    self.position = 0
    self.window = window
  end
  
  def image
    @image ||= Gosu::Image.new window, "sprites/background.png", true
  end
  
  # Returns true if the user has been able to move.
  def move(distance)
    self.position -= distance
    ensure_bounds
  end
  
  def layer; 1; end
  
  # Returns true if the user has been able to move.
  def ensure_bounds
    if self.position > min_position
      self.position = min_position
      false
    elsif self.position < max_position
      self.position = max_position
      false
    else
      true
    end
  end
  
  def min_position; 0; end
  
  def max_position; -1000; end
  
end

module PowerUps
  
  def power_ups
    start = 500
    @power_ups ||= 5.times.to_a.collect do |x|
      PowerUp.new self, :name => "Coin #{x}", :x1 => (200 * x) + start, :y1 => 350, :x2 => (200 * x) + 20 + start, :y2 => 380
    end
  end
end

class App < Gosu::Window
  include PowerUps
  def initialize
    super(800, 600, false)
    self.caption = 'Banana Platforma'
  end
  
  def banana
    @banana ||= Banana.new self
  end
  
  def background
    @background ||= Background.new self
  end
  
  def draw
    draw_background
    draw_banana
    draw_power_ups
    draw_points
  end
  
  def update
    input
    collide
    draw
    sleep 1/20.0
  end
  
  def move(direction, amount)
    banana.turn direction
    banana.forward
    banana.update_estimate_x_position amount if background.move amount
  end
  
  def input
    if button_down? Gosu::Button::KbLeft or button_down? Gosu::Button::GpLeft
      move :left, -15
    elsif button_down? Gosu::Button::KbRight or button_down? Gosu::Button::GpRight
      move :right, 15
    elsif button_down? Gosu::Button::KbUp or button_down? Gosu::Button::GpUp
      banana.jump! unless banana.jumping?
    end
  end
  
  def collide
    power_ups.each do |power_up|
      if banana.collides_with? power_up.rect
        banana.hit_power_up!(power_up) unless power_up.hit?
        power_up.hit!
      end
    end
  end
  
  # protocol: helpers
  
  def draw_banana
    banana.image.draw 400, banana.y_pos, banana.layer
  end
  
  def draw_power_ups
    power_ups.each do |power_up|
      power_up.image.draw background.position + power_up.rect.x1, power_up.rect.y1, power_up.layer
    end
  end
  
  def draw_background
    background.image.draw background.position, 0, background.layer
  end
  
  def draw_points
    font.draw banana.points, 10, 10, 20, 1.0, 1.0, 0xFF000000
  end
  
  def font
    @font ||= Gosu::Font.new(self, Gosu::default_font_name, 60)
  end
end

app = App.new
app.show