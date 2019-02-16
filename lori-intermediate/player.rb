DIRS ||= {forward: :backward, backward: :forward, left: :right, right: :left}

class Player
  def initialize
    @state = :think
    @target = nil
    @last_path = nil
  end

  def play_turn(warrior)
    @warrior = warrior
    detect_environment

    loop do
      if (d,_ = @target)
        puts "* Target: #{d}"
      end
      break unless send("do_#{@state}") == :next_state
    end
  end

  def do_think
    puts "* State :think"

    @target = nil

    if @bombs.length > 0
      @state = :bomb
    elsif (enemy = (find(:enemy?) || find_bound_enemy))
      @target = enemy
      @state = :attack
    elsif captive = find_captive
      @target = captive
      @state = :free_captive
    elsif @warrior.health < 14 && @enemies.length > 0
      @state = :heal
    else
      @state = :navigate
    end

    :next_state
  end

  def do_bomb
    puts "* State :bomb"

    @target = nil

    if captive = find_captive
      @target = captive
      @state = :free_captive
    elsif @warrior.health < 5 && @enemies.length > 0
      @state = :heal
    else
      @state = :navigate
    end

    :next_state
  end

  def do_navigate
    puts "* State :navigate"
    @state = :think

    path = nil

    if bomb = @bombs.first
      if (desired_path = path_to @warrior.direction_of bomb)
        path = desired_path
      else
        @target = pick @warrior.direction_of bomb
        @state = :attack
        return :next_state
      end
    elsif interest = @interests.first
      path = path_to @warrior.direction_of interest
    else
      path = @warrior.direction_of_stairs
    end

    @warrior.walk! path
    @last_path = path
  end

  def do_attack
    puts "* State :attack"
    dir, enemy = @target
    if dir.nil?
      @state = :think
      return :next_state
    elsif @warrior.health < 5
      @state = :heal
      return :next_state
    elsif (other_dir, _ = select(:enemy?).reject {|d,e| d == dir }.first)
      @warrior.bind!(other_dir)
      return
    elsif enemy_line(dir) && detonation_safe
      @warrior.detonate! dir
      return
    end

    @warrior.attack! dir
  end

  def do_free_captive
    puts "* State :free_captive"
    @state = :think

    dir, _ = @target
    if dir.nil?
      return :next_state
    end

    @warrior.rescue! dir
  end

  def do_heal
    puts "* State :heal"
    if @bombs.length > 0 && @warrior.health >= 15
      @state = :think
      return :next_state
    elsif @warrior.health >= 19
      @state = :think
      return :next_state
    elsif (dir, _ = find(:enemy?))
      @warrior.bind!(dir)
      return
    end

    @warrior.rest!
  end

  def select(kind)
    @nearby.select {|d,o| o.send kind }
  end

  def find(kind)
    select(kind).first
  end

  def detonation_safe
    @bombs.all? {|b| @warrior.distance_of(b) > 2}
  end

  def enemy_line(dir)
    @visible[dir].select(&:enemy?).length > 1
  end

  def find_captive
    select(:captive?).reject{|_,c| c.to_s != "Captive" }.first
  end

  def find_bound_enemy
    select(:captive?).reject{|_,c| c.to_s == "Captive" }.first
  end

  def pick(dir)
    o = @warrior.feel dir
    [dir, o]
  end

  def detect_environment
    @visible = DIRS.keys.map {|d| [d, @warrior.look(d)]}.to_h
    @nearby = DIRS.keys.map {|d| [d, @warrior.feel(d)] }.to_h
    @enemies = @warrior.listen.select(&:enemy?)
    @interests = @warrior.listen.reject(&:stairs?)
    @bombs = @warrior.listen.select(&:ticking?)

    if @target && (d,_ = @target)
      @target = nil if @warrior.feel(d).empty?
    end
  end

  def path_to(dir)
    paths = ([dir]+DIRS.keys).reject do |d|
      o = @warrior.feel d
      d == DIRS[dir] || d == DIRS[@last_path] || o.stairs? || !o.empty?
    end
    paths.first
  end
end
