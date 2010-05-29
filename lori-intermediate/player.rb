require 'pp'

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
    @actions.any? {|a| self.send a}
  end
  
  private
    def scan
      unless @target.nil?
        @target = nil if @warrior.feel(@target).empty?
      end
      
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
      @interests = @warrior.listen.reject { |i| i.stairs? }
    end
    
    def bind!
      unbound = @enemies.reject {|k,v| v.captive? || @warrior.direction_of(v) == @target}
      
      return false if @enemies.empty?
      return false if unbound.empty?
      
      @warrior.bind!(unbound.keys.first)
      true
    end
    
    def bomb!
      @bombs = @interests.select {|i| i.ticking?}
      return false if @bombs.empty?
      captive = @captives.keys.select {|c| @warrior.feel(c).ticking?}.first
      unless captive.nil?
        @warrior.rescue!(captive)
        return true
      end 
      
      bomb_direction = @warrior.direction_of @bombs.first
      desired = path_to bomb_direction
      if desired.nil?
        @target = bomb_direction
        bind! or fight!
      else
        @warrior.walk! desired
      end
      true
    end
    
    def rescue!
      return false if @captives.empty?
      
      captive = @captives.keys.first
      @warrior.rescue!(captive)
      true
    end
    
    def fight!
      return false if @enemies.empty?
      @target ||= @enemies.keys.first
      @warrior.attack! @target
      true
    end
    
    def heal!
      if ((!@target.nil?) && @warrior.health <= (@max_health / 2))
        @warrior.bind!(@target)
        @target = nil
        return true
      elsif @target.nil? && @warrior.health < @max_health
        @warrior.rest!
        return true
      end
      false
    end
    
    def seek!
      return false if @interests.empty?
      direction = path_to(@warrior.direction_of @interests.first)
      @warrior.walk! direction
      true
    end
    
    def leave!
      @warrior.walk! @warrior.direction_of_stairs
    end
    
    def path_to(direction, wanted = nil)
      unwanted = [:stairs?, :wall?, :enemy?, :captive?].reject {|u| u == wanted}

      options = [direction]+@directions.keys
      direction = (options.reject {|d| d == @directions[direction] || 
                   unwanted.any? {|u| @warrior.feel(d).send u }}).first
      direction
    end

end
