class Player
  def initialize
    @directions = {:left => :right, :right => :left, :forward => :backward, :backward => :forward}
    
    # State machines
    @clear_level = [:crowd_control!, :heal!, :attack!, :rescue_captive!, :navigate!]
    @disarm_bomb = [:rescue_captive!, :navigate!, :crowd_control!, :attack!]
  end
  
  def play_turn(warrior)
    setup(warrior)
    unless @bombs.empty?
      run @disarm_bomb
    else
      run @clear_level
    end
  end
  
  private
    # Setup the environment for the level
    def setup(warrior)
      @warrior = warrior
      @max_health ||= @warrior.health
      @interests = @warrior.listen.reject { |i| i.stairs? }
      @bombs = @interests.select {|i| i.ticking?}
      setup_local
      @target = @warrior.direction_of @bombs.first unless @bombs.empty?
    end
    
    # Figure out whats directly local around the AI
    def setup_local
      @enemies = {}
      @captives = {}
      @directions.keys.each do |d| 
        square = @warrior.feel(d)
        if (square.captive? && square.to_s != "Captive") || square.enemy?
          @enemies[d] = square
        elsif square.captive?
          @captives[d] = square
        end
      end
      @target = @enemies.keys.first
      @combat = !@enemies.empty?
    end
    
    # Bind local mobs except the target.
    def crowd_control!
      unbound = @enemies.reject {|k,v| v.captive? || @warrior.direction_of(v) == @target}
      @warrior.bind! unbound.keys.first unless unbound.empty?
    end
    
    # Save a local captive
    def rescue_captive!
      unless @bombs.empty?
        direction, square = @captives.select {|k,v| v.ticking?}.first
        @warrior.rescue! direction if direction
      else
        @warrior.rescue! @captives.keys.first unless @captives.empty?
      end
    end
    
    # Fight the chosen target
    def attack!
      @warrior.attack! @target if @target
    end
      
    # Optimized heal for high score
    #   - only activates during combat
    #   - heals inbetween active targets
    #   - pauses combat if health is too low
    #   - don't heal past about half health (statistically best for score)
    def heal!
      health_limit = @max_health / 2
      health_limit = @max_health / 1.9  if @interests.reject {|i| i.character == "C"}.count > 1
      if @combat
        if !@warrior.feel(@target).captive? && @warrior.health <= (@max_health / 7)
          @warrior.bind!(@target)
        elsif @warrior.feel(@target).captive? && @warrior.health < health_limit
          @warrior.rest!
        end
      end
    end
    
    # Find areas of interest (bombs, mobs, captives, stairs)
    def navigate!
      unless @bombs.empty?
        desired_direction = path_to @warrior.direction_of @bombs.first
        @warrior.walk! desired_direction if desired_direction
      else
        unless @interests.empty?
          @warrior.walk! path_to @warrior.direction_of @interests.first
        else
          @warrior.walk! @warrior.direction_of_stairs
        end
      end
    end
    
    # Pathing algorithm.
    #   - avoids obstructions
    #   - doesn't double back
    #   - not very smart otherwise ;)
    def path_to(direction)
      unwanted = [:stairs?, :wall?, :enemy?, :captive?]
      ([direction]+@directions.keys).reject do |d| 
        d == @directions[direction] || unwanted.any? {|u| @warrior.feel(d).send u}
      end.first
    end
    
    # Run a state machine.
    #   - steps through each state until true is returned.
    def run(machine)
      machine.any? {|a| self.send a}
    end
end
