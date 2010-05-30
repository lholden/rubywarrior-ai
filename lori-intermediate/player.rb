class Player
  def initialize
    @directions = {:left => :right, :right => :left, :forward => :backward, :backward => :forward}
    @actions = [:scan, :bomb!, :bind!, :heal!, :fight!, :rescue!, :navigate!]
    @target = nil
  end
  
  def play_turn(warrior)
    @max_health ||= warrior.health
    @warrior = warrior

    # Primitive state machine
    @actions.any? {|a| self.send a} 
  end
  
  private
    # Gather information about the environment.
    def scan
      @interests = @warrior.listen.reject { |i| i.stairs? }
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
      false
    end
    
    # Mez a mob to prevent it from doing damage.
    def bind!
      unbound = @enemies.reject {|k,v| v.captive? || @warrior.direction_of(v) == @target}
      return false if unbound.empty?
      @warrior.bind! unbound.keys.first
    end
    
    # Deal with bombs as quickly as possible.
    def bomb!
      bombs = @interests.select {|i| i.ticking?}
      return false if bombs.empty?
      
      direction, square = @captives.select {|k,v| v.ticking?}.first
      if direction
        @warrior.rescue!(direction)
      else       
        bomb_direction = @warrior.direction_of bombs.first
        desired = path_to bomb_direction
        if desired
          @warrior.walk! desired
        else
          @target = bomb_direction
          bind! or fight!
        end
      end
    end
    
    # Save a captive
    def rescue!
      return false if @captives.empty?
      @warrior.rescue! @captives.keys.first
    end
    
    # Attack any local targets
    def fight!
      return false if @enemies.empty?
      @warrior.attack! @target
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
    
    # Find areas of interest (mobs, captives, stairs)
    def navigate!
      unless @interests.empty?
        @warrior.walk! path_to(@warrior.direction_of @interests.first)
      else
        @warrior.walk! @warrior.direction_of_stairs
      end
    end
    
    # Simple pathing algorithm, returned the most relavent unblocked path.
    def path_to(direction)
      unwanted = [:stairs?, :wall?, :enemy?, :captive?]
      directions = ([direction]+@directions.keys).reject do |d| 
        d == @directions[direction] || unwanted.any? {|u| @warrior.feel(d).send u }
      end
      directions.first
    end
end
