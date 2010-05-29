class Player
  def initialize
    @directions = {:left => :right, :right => :left, :forward => :backward, :backward => :forward}
    @actions = [:bomb!, :bind!, :heal!, :fight!, :rescue!, :seek!, :leave!]
    @target = nil
  end
  
  def play_turn(warrior)
    @max_health ||= warrior.health
    @warrior = warrior
    
    scan
    @actions.any? {|a| self.send a} # Primitive state machine
  end
  
  private
    # Gather information about the environment.
    def scan
      if (!@target.nil?) && @warrior.feel(@target).empty?
        @target = nil 
        @combat = nil
      end
      
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
    end
    
    # Mez a mob to prevent it from doing damage.
    def bind!
      unbound = @enemies.reject {|k,v| v.captive? || @warrior.direction_of(v) == @target}
      return false if unbound.empty?
      @warrior.bind!(unbound.keys.first)
    end
    
    # Rescue captives with bombs ASAP.
    def bomb!
      bombs = @interests.select {|i| i.ticking?}
      return false if bombs.empty?
      
      direction, square = @captives.select {|k,v| v.ticking?}.first
      unless direction.nil?
        @warrior.rescue!(direction)
      else       
        bomb_direction = @warrior.direction_of bombs.first
        desired = path_to bomb_direction
        if desired.nil?
          @target = bomb_direction
          bind! or fight!
        else
          @warrior.walk! desired
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
      @target ||= @enemies.keys.first
      @combat = true
      @warrior.attack! @target
    end
      
    # Optimized for score vs survivability
    #   - only heal in combat
    #   - keep health between 1/6th and 1/2rd
    def heal!
      if @combat
        if ((!@target.nil?) && @warrior.health <= (@max_health / 6))
          @warrior.bind!(@target)
          @target = nil
          true
        elsif @target.nil? && @warrior.health < (@max_health / 2)
          @warrior.rest!
        end
      end
    end
    
    # Find areas of interest (mobs, captives)
    def seek!
      return false if @interests.empty?
      @warrior.walk! path_to(@warrior.direction_of @interests.first)
    end
    
    # Leave the current level
    def leave!
      @warrior.walk! @warrior.direction_of_stairs
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
