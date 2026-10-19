#==============================================================================
# PokeRPGLink — second-screen companion bridge for Pokémon Rejuvenation
# v1.0.0  ·  made for Leymo's AYN Thor
#
# Drop this file into the game's mod folder:
#   V14+  : <game folder>/patch/Mods/PokeRPGLink.rb   (create "Mods" if missing)
#   V13.5 : <game folder>/Data/Mods/PokeRPGLink.rb
#
# What it does
#   * Every few frames it writes PokeRPGLink/state.json in the game folder:
#     battle info, the area's wild Pokémon, party, bag, map position.
#   * It reads one-line command files the companion app drops into
#     PokeRPGLink/cmd/ and turns them into game actions (touch Fight/Bag/Switch/
#     Run, pick a move, save, use an item, fly, reorder moves, held items...).
#   * It never touches your save file format. Delete this file and the
#     PokeRPGLink folder to remove it completely.
#
# Everything is wrapped in rescue blocks: if a Rejuvenation update renames
# something, that one feature turns off and the error goes to
# PokeRPGLink/log.txt — the game itself keeps running.
#==============================================================================

module PokeRPGLink
  unless const_defined?(:VERSION)
    VERSION      = "1.0.4"
    STATE_EVERY  = 8     # frames between state refreshes (~7.5x per second)
    CMD_EVERY    = 3     # frames between command-folder checks
  end

  @frame        = 0
  @last_state   = nil
  @field_queue  = []   # actions that must run on the overworld at a safe moment
  @battle_queue = []   # touch choices waiting for the battle menu
  @toasts       = []   # short messages shown on the companion
  @toast_id     = 0
  @menu         = :none
  @menu_index   = 0
  @battle       = nil
  @cooldown     = 0
  @in_switch    = false
  @auto_switchin= false
  @icon_cache   = {}
  @log_lines    = 0
  @hooks_ok     = []
  @hooks_failed = []

  @pending_target = nil
  @target_pick  = nil

  class << self
    attr_accessor :battle, :menu, :menu_index, :in_switch, :auto_switchin
    attr_reader :battle_queue, :field_queue, :hooks_ok, :hooks_failed
  end

  #--------------------------------------------------------------------------
  # Paths & logging
  #--------------------------------------------------------------------------
  def self.dir
    return @dir if @dir
    d = File.join(Dir.pwd, "PokeRPGLink")
    begin
      Dir.mkdir(d) unless File.directory?(d)
      cmd = File.join(d, "cmd")
      Dir.mkdir(cmd) unless File.directory?(cmd)
    rescue
    end
    @dir = d
  end

  def self.log(msg)
    return if @log_lines > 400
    @log_lines += 1
    begin
      File.open(File.join(dir, "log.txt"), "ab") { |f| f.write("[#{Time.now.strftime('%H:%M:%S')}] #{msg}\n") }
    rescue
    end
  end

  def self.err(tag, e)
    bt = (e.backtrace || [])[0, 4].join(" | ")
    log("#{tag}: #{e.class}: #{e.message} @ #{bt}")
  end

  def self.toast(text, kind = "info")
    @toast_id += 1
    @toasts << { "id" => @toast_id, "text" => text.to_s, "kind" => kind }
    @toasts.shift while @toasts.length > 6
    @last_state = nil # force a refresh
  end

  #--------------------------------------------------------------------------
  # Tiny JSON writer (mkxp-z ships without the json extension)
  #--------------------------------------------------------------------------
  JSON_ESC = { '"' => '\\"', "\\" => "\\\\", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t" }

  def self.json(o, out = +"")
    case o
    when Hash
      out << "{"
      first = true
      o.each do |k, v|
        out << "," unless first
        first = false
        json(k.to_s, out)
        out << ":"
        json(v, out)
      end
      out << "}"
    when Array
      out << "["
      o.each_with_index { |v, i| out << "," if i > 0; json(v, out) }
      out << "]"
    when String, Symbol
      s = o.to_s
      s = s.dup.force_encoding("UTF-8")
      s = s.scrub("?") unless s.valid_encoding?
      out << '"' << s.gsub(/["\\\x00-\x1f]/) { |c| JSON_ESC[c] || format("\\u%04x", c.ord) } << '"'
    when Integer
      out << o.to_s
    when Float
      out << (o.finite? ? o.round(3).to_s : "0")
    when true  then out << "true"
    when false then out << "false"
    when nil   then out << "null"
    else
      json(o.to_s, out)
    end
    out
  end

  def self.write_file(name, text)
    path = File.join(dir, name)
    tmp  = path + ".tmp"
    File.open(tmp, "wb") { |f| f.write(text) }
    begin
      File.rename(tmp, path)
    rescue
      File.open(path, "wb") { |f| f.write(text) }
      File.delete(tmp) rescue nil
    end
  end

  #--------------------------------------------------------------------------
  # Main tick — called once per Input.update
  #--------------------------------------------------------------------------
  def self.tick
    @frame += 1
    @cooldown -= 1 if @cooldown > 0
    if @frame % CMD_EVERY == 0
      begin
        poll_commands
      rescue => e
        err("poll", e)
      end
    end
    (icon_jobs_tick rescue nil) if @frame % 2 == 0
    if @frame % 90 == 0   # heartbeat: the panel knows the game is running even when nothing changes
      (write_file("alive.txt", @frame.to_s) rescue nil)
    end
    if @frame % STATE_EVERY == 0
      begin
        s = json(build_state)
        if s != @last_state
          write_file("state.json", s)
          @last_state = s
        end
      rescue => e
        err("state", e)
      end
    end
  end

  #--------------------------------------------------------------------------
  # Commands from the companion
  #--------------------------------------------------------------------------
  def self.poll_commands
    cdir = File.join(dir, "cmd")
    return unless File.directory?(cdir)
    names = Dir.children(cdir).select { |n| n.end_with?(".cmd") }.sort
    names.first(8).each do |n|
      p = File.join(cdir, n)
      line = (File.open(p, "rb") { |f| f.read } rescue "").to_s.strip
      File.delete(p) rescue nil
      next if line.empty?
      # taps older than a few seconds (the game was busy or paused) are dropped, not replayed
      sent = n[/\A(\d{13,15})/, 1].to_i
      next if sent > 1_000_000_000_000 && (Time.now.to_f * 1000).to_i - sent > 4000
      begin
        handle(line.split(/\s+/))
      rescue => e
        err("cmd #{line}", e)
        toast("Couldn't do that: #{short_error(e)}", "error")
      end
    end
  end

  def self.sym(s)
    s.to_s.upcase.to_sym
  end

  # One battle action at a time: after a move / switch / item / run is chosen, further
  # battle taps are ignored until the game asks for the next choice (new command menu).
  def self.mark_busy; @battle_busy = @frame; end
  def self.turn_ready; @battle_busy = nil; end

  def self.battle_busy?
    return false unless @battle_busy
    return false if @in_switch      # the game itself is asking for a Pokémon (e.g. after a faint)
    if @frame - @battle_busy > 360 && @menu != :none   # the game is asking again (e.g. the choice failed)
      @battle_busy = nil
      return false
    end
    true
  end

  BATTLE_VERBS = %w[bcmd bmove bitem bball bswitch]

  def self.handle(a)
    verb = a[0].to_s.downcase
    return if BATTLE_VERBS.include?(verb) && @battle && battle_busy?
    case verb
    when "btn"
      PokeRPGInput.press(a[1])
    when "hold"
      PokeRPGInput.hold(a[1], (a[2] || 12).to_i)
    when "bcmd"   # 0 Fight, 1 Bag, 2 Pokémon, 3 Run
      return toast("Not in a battle menu right now") unless @battle
      @battle_queue = [{ :t => :cmd, :idx => a[1].to_i }]
    when "bmove"  # bmove <slot> [special] [t=<battler index>]
      return toast("Not in a battle menu right now") unless @battle
      special = a[2..].any? { |x| x == "special" || %w[mega z ultra giga].include?(x) }
      tgt = a[2..].map { |x| x[/\At=(\d+)\z/, 1] }.compact.first
      @battle_queue = [{ :t => :move, :idx => a[1].to_i, :special => special, :target => tgt && tgt.to_i }]
    when "bitem"   # bitem <ITEM> [target] [move]  — use an item from the panel's bag in battle
      return toast("Not in a battle menu right now") unless @battle
      @battle_queue = [{ :t => :item, :item => sym(a[1]), :target => (a[2] ? a[2].to_i : nil),
                         :move => (a[3] ? a[3].to_i : nil), :at => @frame }]
    when "bball"   # throw the quick-ball (or a specific ball)
      return toast("Not in a battle menu right now") unless @battle
      ball = a[1] ? sym(a[1]) : quick_ball
      return toast("You don't have any Poké Balls", "error") unless ball && bag_qty(ball) > 0
      @battle_queue = [{ :t => :item, :item => ball, :ball => true, :target => (a[2] ? a[2].to_i : nil), :at => @frame }]
    when "btarget" # pick a target while the game is asking for one
      @target_pick = a[1].to_i if @menu == :target
    when "bswitch" # party index
      return toast("Not in a battle right now") unless @battle
      @battle_queue = [{ :t => :switch, :pi => a[1].to_i }]
    when "bcancel"
      @battle_queue.clear
    when "save", "openparty", "openbag", "opendex", "openmap", "useitem", "useon",
         "giveitem", "takeitem", "swapmove", "swapparty", "fly"
      if @battle
        toast("That can't be done during a battle")
      else
        @field_queue << a
        @field_queue.shift while @field_queue.length > 4
      end
    when "req"
      case a[1].to_s
      when "dex" then write_file("dex.json", json(build_dex))
      when "map" then write_file("map.json", json(build_townmap))
      end
    when "ping"
      toast("PokeRPGLink #{VERSION} connected")
    when "ext"
      blk = @ext_commands[a[1].to_s]
      return toast("No extension handles \"#{a[1]}\"", "error") unless blk
      blk.call(a[2..] || [])
    end
  end

  #--------------------------------------------------------------------------
  # Battle-side hooks (called from the aliased scene methods)
  #--------------------------------------------------------------------------
  # Logical battle commands (0 Fight, 1 Bag, 2 Pokémon, 3 Run) → the game's menu index.
  def self.cmd_slot(i); i; end

  # The battle menu's own labels in logical order, from pbCommandMenuEx's texts.
  def self.command_texts(t)
    t.is_a?(Array) && t.length > 1 ? t[1..4].map(&:to_s) : nil
  end

  def self.battle_frame(scene, cw)
    # Essentials-style target cursor: the window index is the battler index
    if @menu == :target && @target_pick && cw && @cooldown <= 0 && PokeRPGInput.idle?
      t = @target_pick
      @target_pick = nil
      if valid_targets(@battle, @target_for, @target_kind).include?(t)
        set_index(cw, t)
        PokeRPGInput.press("C")
        @cooldown = 6
      else
        toast("Can't target that one")
      end
      return
    end
    return if @battle_queue.empty? || cw.nil? || @cooldown > 0
    return unless PokeRPGInput.idle?
    q = @battle_queue.first
    case @menu
    when :command
      case q[:t]
      when :cmd
        set_index(cw, cmd_slot(q[:idx]))
        PokeRPGInput.press("C")
        @battle_queue.shift
        mark_busy if q[:idx] == 3
      when :move
        set_index(cw, cmd_slot(0))    # open Fight, keep the move queued
        PokeRPGInput.press("C")
      when :switch
        set_index(cw, cmd_slot(2))    # open Pokémon, keep the switch queued
        PokeRPGInput.press("C")
      when :item
        set_index(cw, cmd_slot(1))    # "Bag": the game calls pbItemMenu, which takes our choice
        PokeRPGInput.press("C")
      end
      @cooldown = 6
    when :fight
      case q[:t]
      when :move
        ok = set_index(cw, q[:idx])
        if ok == false
          @battle_queue.shift
          toast("That move slot is empty")
          return
        end
        if q[:special] && !q[:special_done]
          q[:special_done] = true
          PokeRPGInput.press(special_button)   # mega / Z / ultra / giga toggle
          @cooldown = 6
          return
        end
        PokeRPGInput.press("C")
        @battle_queue.shift
        mark_busy
        @pending_target = [q[:target], @frame + 240]   # target may be nil: still marks "chosen on the panel"
        @cooldown = 6
      else
        PokeRPGInput.press("B")          # back out to the command menu first
        @cooldown = 6
      end
    end
  end

  # --- target selection (double battles) ---------------------------------
  def self.valid_targets(bt, index, kind)
    me = bt.battlers[index]
    alive = ->(i) { b = bt.battlers[i]; b && !(b.isFainted? rescue b.hp.to_i <= 0) }
    case kind
    when :ally   # user or partner (UserOrPartner, Acupressure)
      [index, index ^ 2].select { |i| alive.(i) }
    else         # any other battler
      (0...4).select { |i| i != index && alive.(i) && me }
    end
  end

  # Called when the game opens its target cursor. Returns a target or nil.
  def self.take_pending_target(bt, index, kind)
    pt = @pending_target
    @pending_target = nil
    return nil unless pt && pt[1] >= @frame
    valid_targets(bt, index, kind).include?(pt[0]) ? pt[0] : nil
  end

  def self.target_frame(scene)
    return unless @menu == :target && @target_pick
    t = @target_pick
    @target_pick = nil
    if valid_targets(@battle, @target_for, @target_kind).include?(t)
      throw :pokerpglink_target, t
    else
      toast("Can't target that one")
    end
  end

  def self.begin_target(index, kind)
    @menu = :target
    @target_for = index
    @target_kind = kind
    @target_pick = nil
  end

  def self.peek_pending_target
    pt = @pending_target
    @pending_target = nil
    pt && pt[1] >= @frame ? pt : nil
  end

  def self.target_info
    return nil unless @menu == :target && @battle
    { "for" => @target_for, "valid" => valid_targets(@battle, @target_for, @target_kind) }
  end

  def self.set_index(cw, i)
    if cw.respond_to?(:setIndex)
      return cw.setIndex(i)
    elsif cw.respond_to?(:index=)
      cw.index = i
      return true
    end
    nil
  end

  # ---- items from the panel's bag ------------------------------------------
  def self.take_item_choice
    q = @battle_queue.first
    return nil unless q && q[:t] == :item
    @battle_queue.shift
    return nil if q[:at] && @frame - q[:at] > 900   # stale (the bag never opened)
    mark_busy
    q
  end

  def self.bag; $PokemonBag; end

  def self.bag_qty(item)
    (bag.pbQuantity(item) rescue 0).to_i
  end

  # Rebornverse version of the game's own pbItemMenu checks, minus the screens.
  def self.panel_item_menu(scene, battle, index, q, _rest, _blk)
    item = q[:item]
    no = [nil, -1]
    return (toast("You don't have that item", "error"); no) if bag_qty(item) <= 0
    usetype = ($cache.items[item].checkFlag?(:noUseInBattle) ? 0 : pbGetPocket(item)) rescue 0
    return (toast("#{item_name(item)} can't be used in battle", "error"); no) if usetype == 0
    if ($game_switches[:No_Items_Password] rescue false) && [1, 2, 5, 7].include?(usetype)
      return (toast("The 'No Items' password is on", "error"); no)
    end
    if usetype != 3 && usetype != 7
      pkmnid = q[:target]
      return (toast("Pick a Pokémon for that item", "error"); no) if pkmnid.nil?
      return (toast("#{item_name(item)} can't be used on a Pokémon here", "error"); no) unless ItemHandlers.hasBattleUseOnPokemon(item)
      ok = (scene.pbCanUseBattleItem(pkmnid, item, HeadlessPartyScene.new) rescue true)
      return (toast("It won't have any effect.", "error"); no) unless ok
      ret = [item, pkmnid]
    else
      return (toast("#{item_name(item)} can't be used right now", "error"); no) unless ItemHandlers.hasBattleUseOnBattler(item)
      ret = [item, index]
    end
    (pbConsumeItemInBattle($PokemonBag, item) rescue nil)
    ret
  end

  # ---- Poké Balls -----------------------------------------------------------
  def self.ball?(item)
    (pbIsPokeBall?(item) rescue false) ? true : false
  end

  def self.remember_ball(ball)
    id = ball.respond_to?(:id) ? ball.id : ball
    @last_ball = id
    write_file("lastball.txt", id.to_s)
  end

  def self.last_ball
    @last_ball ||= begin
      t = (File.read(File.join(dir, "lastball.txt")) rescue "").strip
      t.empty? ? nil : t.to_sym
    end
  end

  def self.owned_balls
    out = []
    begin
      (bag.pockets || []).each do |items|
        (items || []).each do |it|
          it = it[0] if it.is_a?(Array)
          next if it.nil? || out.include?(it) || !ball?(it)
          q = bag_qty(it)
          out << [it, q] if q > 0
        end
      end
    rescue => e
      err("balls", e)
    end
    out
  end

  # The last ball you threw if you still have one; otherwise your most plentiful ball,
  # keeping the Master Ball (and other one-of-a-kind balls) as a last resort.
  def self.quick_ball
    balls = owned_balls
    return nil if balls.empty?
    lb = last_ball
    return lb if lb && balls.any? { |b, _| b.to_s == lb.to_s }
    precious = balls.select { |b, q| b.to_s =~ /MASTER|PARK|BEAST|ORIGIN|STRANGE/i }
    pool = balls - precious
    pool = balls if pool.empty?
    pool.max_by { |_, q| q }[0]
  end

  def self.ball_info
    balls = owned_balls
    qb = quick_ball
    { "quick" => (qb ? { "id" => qb.to_s, "name" => item_name(qb), "qty" => bag_qty(qb), "icon" => item_icon(qb),
                         "last" => (last_ball && last_ball.to_s == qb.to_s) ? true : false } : nil),
      "all" => balls.map { |b, q| { "id" => b.to_s, "name" => item_name(b), "qty" => q, "icon" => item_icon(b) } } }
  end

  # ---- item kinds for the panel ----------------------------------------------
  # battle: "pokemon" (pick a party member), "move" (pick a member + move), "battler"
  #         (acts on the Pokémon choosing), "ball", "self" (no target) or nil (not usable)
  # field:  "pokemon", "field" or nil
  def self.item_kinds(it)
    battle = nil
    field = nil
    begin
      d = $cache.items[it]
      unless d.checkFlag?(:noUseInBattle)
        pocket = pbGetPocket(it)
        if ball?(it) then battle = "ball"
        elsif pocket == 3 || pocket == 7 then battle = (ItemHandlers.hasBattleUseOnBattler(it) ? "battler" : nil)
        elsif ItemHandlers.hasBattleUseOnPokemon(it) then battle = "pokemon"
        elsif ItemHandlers.hasBattleUseOnBattler(it) then battle = "battler"
        end
      end
      if (pbIsTM?(it) rescue false) || !(ItemHandlers::UseOnPokemon[it].nil? rescue true)
        field = "pokemon"
      elsif !(ItemHandlers::UseFromBag[it].nil? rescue true) || !(ItemHandlers::UseInField[it].nil? rescue true)
        field = "field"
      end
    rescue
    end
    [battle, field]
  end

  def self.take_switch
    q = @battle_queue.first
    return nil unless q && q[:t] == :switch
    @battle_queue.shift
    mark_busy
    q[:pi]
  end

  # Which button toggles Mega/Z in the fight menu, and how party slots map to
  # the battle party screen's order. Adapters override these.
  def self.special_button; "X"; end

  def self.display_index(pi)
    order = (@battle.partyorder rescue nil) || (0...6).to_a
    order.index(pi) || pi
  end

  def self.trainer; $Trainer; end

  def self.essentials?
    defined?(GameData) && defined?(GameData::Species) ? true : false
  end

  def self.party_screen_frame(scene)
    return unless @in_switch && @battle && @cooldown <= 0 && PokeRPGInput.idle?
    q = @battle_queue.first
    return unless q && q[:t] == :switch
    disp = display_index(q[:pi])
    @battle_queue.shift
    mark_busy
    scene.pbSelect(disp) if scene.respond_to?(:pbSelect)
    @auto_switchin = true
    PokeRPGInput.press("C")
    @cooldown = 6
  end

  #--------------------------------------------------------------------------
  # Overworld actions — only run when the player is standing still with no
  # message box, event or menu open.
  #--------------------------------------------------------------------------
  def self.map_idle?
    return false unless $scene.is_a?(Scene_Map)
    return false if $game_temp.nil? || $game_player.nil?
    return false if $game_temp.message_window_showing
    return false if ($game_temp.player_transferring rescue false)
    return false if ($game_temp.transition_processing rescue false)
    return false if ($game_temp.menu_calling rescue false)
    return false if ($game_temp.in_menu rescue false)
    return false if $game_player.moving?
    return false if (pbMapInterpreterRunning? rescue false)
    true
  end

  def self.map_frame
    return if @field_queue.empty? || !map_idle? || !PokeRPGInput.idle?
    a = @field_queue.shift
    begin
      run_field(a)
    rescue => e
      err("field #{a.join(' ')}", e)
      toast("Couldn't do that: #{short_error(e)}", "error")
    end
    @last_state = nil
  end

  def self.run_field(a)
    case a[0].to_s.downcase
    when "save"         then do_save
    when "openparty"    then do_open_party
    when "openbag"      then do_open_bag
    when "opendex"      then do_open_dex
    when "openmap"      then pbShowMap(-1, false)
    when "useitem"      then do_use_item(sym(a[1]))
    when "useon"        then do_use_item_on(sym(a[1]), a[2].to_i, (a[3] ? a[3].to_i : nil))
    when "giveitem"     then do_give_item(a[1].to_i, sym(a[2]))
    when "takeitem"     then do_take_item(a[1].to_i)
    when "swapmove"     then do_swap_move(a[1].to_i, a[2].to_i, a[3].to_i)
    when "swapparty"    then do_swap_party(a[1].to_i, a[2].to_i)
    when "fly"          then do_fly(a[1].to_i, a[2].to_i, (a[3] ? a[3].to_i : nil))
    end
  end

  def self.switch_on?(name)
    $game_switches[name] rescue false
  end

  def self.do_save
    if $game_system && $game_system.save_disabled
      return toast("Saving is disabled right now", "error")
    end
    if switch_on?(:Disable_Quicksave)
      return toast("Saving is disabled right now", "error")
    end
    begin; $game_switches[:Mid_quicksave] = true; rescue; end
    begin; $game_switches[:Stop_Icycle_Falling] = true; rescue; end
    $game_map.events.values.each { |ev| ev.minilock rescue nil }
    $PokemonTemp.begunNewGame = false rescue nil
    ok = pbSave
    $game_map.events.values.each { |ev| ev.unlock rescue nil }
    begin; $game_switches[:Mid_quicksave] = false; rescue; end
    begin; $game_switches[:Stop_Icycle_Falling] = false; rescue; end
    if ok
      pbSEPlay("save") rescue nil
      toast("Game saved ✓", "ok")
    else
      toast("Save failed!", "error")
    end
  end

  def self.do_open_party
    sscene = PokemonScreen_Scene.new
    sscreen = PokemonScreen.new(sscene, $Trainer.party)
    hidden = nil
    pbFadeOutIn(99999) { hidden = sscreen.pbPokemonScreen }
    Kernel.pbUseHiddenMove(hidden[0], hidden[1]) if hidden
  end

  def self.do_open_bag
    item = nil
    scene = PokemonBag_Scene.new
    screen = PokemonBagScreen.new(scene, $PokemonBag)
    pbFadeOutIn(99999) { item = screen.pbStartScreen }
    Kernel.pbUseKeyItemInField(item) if item
  end

  def self.do_open_dex
    pbFadeOutIn(99999) {
      scene = PokemonPokedexScene.new
      screen = PokemonPokedex.new(scene)
      screen.pbStartScreen
    }
  end

  def self.do_use_item(item)
    return toast("You don't have that item", "error") if $PokemonBag.pbQuantity(item) <= 0
    ret = pbUseItem($PokemonBag, item)
    Kernel.pbUseKeyItemInField(item) if ret == 2
  end

  # Use an item on a party member chosen on the panel (no party screen on top).
  def self.do_use_item_on(item, pi, move = nil)
    pkmn = trainer.party[pi]
    return toast("No Pokémon in that slot", "error") unless pkmn
    return toast("You don't have that item", "error") if bag_qty(item) <= 0
    return toast("Eggs can't use items", "error") if (pkmn.isEgg? rescue false)
    scene = HeadlessPartyScene.new
    if defined?(ItemHandlers::MultipleAtOnce) && ItemHandlers::MultipleAtOnce.include?(item)
      ret, used = ItemHandlers::UseOnPokemon.trigger(item, pkmn, scene, 1)
      bag.pbDeleteItem(item, (used || 1)) if ret
    else
      ret = pbUseItemOnPokemon(item, pkmn, scene)
    end
    toast("It won't have any effect.", "error") unless ret
  end

  # Minimal scene so we can reuse the game's own give/take logic headlessly.
  class HeadlessPartyScene
    def pbDisplay(t, *_)
      PokeRPGLink.toast(t.to_s.gsub(/\\[a-zA-Z]+\[[^\]]*\]/, "").gsub(/\\[a-zA-Z]+/, "").delete("\x01"), "ok")
    end
    def pbConfirm(*_);     true; end
    def scene;             self; end      # v21 asks scene.scene.pbChooseNumber
    def pbChooseNumber(*_); 1; end        # use one at a time from the panel
    def pbUpdate(*_);      end
    def pbRefresh(*_);     end
    def pbHardRefresh(*_); end
    def method_missing(*_); nil; end
    def respond_to_missing?(*_); true; end
  end

  def self.party_screen
    PokemonScreen.new(HeadlessPartyScene.new, $Trainer.party)
  end

  def self.do_give_item(pi, item)
    pkmn = $Trainer.party[pi]
    return toast("No Pokémon in that slot", "error") unless pkmn
    return toast("You don't have that item", "error") if $PokemonBag.pbQuantity(item) <= 0
    return toast("Give mail from the in-game Bag instead", "error") if (pbIsMail?(item) rescue false)
    party_screen.pbGiveItem(item, pkmn, pi)
  end

  def self.do_take_item(pi)
    pkmn = $Trainer.party[pi]
    return toast("No Pokémon in that slot", "error") unless pkmn
    return toast("Remove mail from the in-game party screen", "error") if pkmn.mail
    party_screen.pbTakeItem(pkmn)
  end

  def self.do_swap_move(pi, i, j)
    pkmn = $Trainer.party[pi]
    return unless pkmn && pkmn.moves[i] && pkmn.moves[j] && i != j
    pkmn.moves[i], pkmn.moves[j] = pkmn.moves[j], pkmn.moves[i]
    if pkmn.respond_to?(:zmoves) && pkmn.zmoves && pkmn.zmoves[i] && pkmn.zmoves[j]
      pkmn.zmoves[i], pkmn.zmoves[j] = pkmn.zmoves[j], pkmn.zmoves[i]
    end
    toast("#{pkmn.name}: moves reordered", "ok")
  end

  def self.do_swap_party(i, j)
    pt = $Trainer.party
    return unless pt[i] && pt[j] && i != j
    pt[i], pt[j] = pt[j], pt[i]
    toast("Party order changed", "ok")
  end

  #--------------------------------------------------------------------------
  # Town map — two layouts exist in the Rebornverse:
  #   :scroll  (Rejuvenation) town_map = { region_id => {:name,:filename}, [x,y] => TownMapData }
  #   :classic (Reborn, Desolation) town_map[region] = [name, filename, [[x,y,name,poi,map,mx,my],...]]
  #--------------------------------------------------------------------------
  def self.townmap_data
    tm = $cache.town_map
    regions = []
    points = []
    if tm.is_a?(Hash) && tm.keys.any? { |k| k.is_a?(Array) }
      tm.each do |k, v|
        if k.is_a?(Integer) && v.is_a?(Hash)
          regions << { "id" => k, "name" => v[:name].to_s, "offset" => 8,
                       "image" => resolve_file("Graphics/Pictures/RegionMap/#{v[:filename]}") ||
                                  resolve_file("Graphics/Pictures/#{v[:filename]}") }
        elsif k.is_a?(Array)
          fd = (v.flyData rescue nil)
          points << { "x" => k[0], "y" => k[1], "name" => (v.name rescue "").to_s, "poi" => (v.poi rescue "").to_s,
                      "region" => (v.region rescue 0), "flyData" => (fd && !fd.empty? ? fd : nil) }
        end
      end
      return { "style" => "scroll", "regions" => regions, "points" => points }
    end
    list = tm.is_a?(Hash) ? tm.to_a : (tm || []).each_with_index.map { |v, i| [i, v] }
    list.each do |rid, v|
      next unless v.is_a?(Array) && v[1]
      regions << { "id" => rid, "name" => v[0].to_s, "offset" => 0,
                   "image" => resolve_file("Graphics/Pictures/#{v[1]}") }
      (v[2] || []).each do |loc|
        next unless loc.is_a?(Array)
        fd = (loc[4] && loc[5] && loc[6]) ? [loc[4], loc[5], loc[6]] : nil
        points << { "x" => loc[0], "y" => loc[1], "name" => loc[2].to_s, "poi" => loc[3].to_s,
                    "region" => rid, "flyData" => fd }
      end
    end
    { "style" => "classic", "regions" => regions, "points" => points }
  end

  def self.player_mappos
    md = $cache.mapdata[$game_map.map_id] rescue nil
    return nil unless md
    mp = (md.MapPosition rescue nil)
    mp = (pbUnpackMapHash rescue nil) if mp.is_a?(Hash)
    return nil unless mp.is_a?(Array) && mp.length >= 3
    pos = mp[0, 3].dup
    begin
      ms = md.MapSize
      if ms && ms[0] && ms[0] > 0 && !(defined?(Rejuv) && Rejuv)
        sqw = ms[0]
        sqh = (ms[1].length * 1.0 / ms[0]).ceil
        pos[1] += ($game_player.x * sqw / $game_map.width).floor if sqw > 1
        pos[2] += ($game_player.y * sqh / $game_map.height).floor if sqh > 1
      end
    rescue
    end
    pos
  end

  def self.fly_spot(x, y, region = nil)
    begin
      if PokemonRegionMapScene.method_defined?(:getFlySpot)
        sc = PokemonRegionMapScene.new(0, true, nil)   # applies the game's own story overrides
        r = sc.getFlySpot([x, y])
        return r if r
      end
    rescue
    end
    pt = townmap_data["points"].find { |q| q["x"] == x && q["y"] == y && (region.nil? || q["region"] == region) }
    pt && pt["flyData"]
  end

  def self.do_fly(x, y, region = nil)
    spot = fly_spot(x, y, region)
    return toast("You can't fly there", "error") unless spot && spot.length >= 3
    return toast("You haven't visited there yet", "error") unless $PokemonGlobal.visitedMaps[spot[0]]
    user = $Trainer.party.find { |p| !p.isEgg? && p.moves.any? { |m| m && m.move == :FLY } }
    user ||= $Trainer.party.find { |p| !p.isEgg? && (p.SpeciesCompatible?(:FLY) rescue false) }
    return toast("Nobody in your party can Fly", "error") unless user
    return unless Kernel.pbCanUseHiddenMove?(user, :FLY)
    $PokemonTemp.flydata = spot
    Kernel.pbUseHiddenMove(user, :FLY)
  end

  #--------------------------------------------------------------------------
  # Name / data helpers
  #--------------------------------------------------------------------------
  # Error text for the panel: one line, no giant object dumps.
  def self.short_error(e)
    m = e.message.to_s.gsub(/#<([A-Za-z:]+)[^>]*>?/m) { "a #{$1}" }.gsub(/\s+/, " ")
    m = m[0, 140] + "…" if m.length > 140
    m
  end

  # Species data. Rejuvenation 14 wraps it per form (MonWrapper → @pokemonData
  # {"Normal Form" => MonData, …}); older Rebornverse builds store MonData directly.
  def self.mondata(sym, form = nil)
    d = ($cache.pkmn[sym] rescue nil)
    return nil unless d
    pd = (d.instance_variable_get(:@pokemonData) rescue nil)
    return d unless pd.is_a?(Hash) && !pd.empty?
    (form.is_a?(String) && pd[form]) || pd["Normal Form"] || pd.values.first
  end

  def self.mon_name(sym)
    (mondata(sym).name rescue nil) || sym.to_s.capitalize
  end

  def self.type_name(t)
    return nil if t.nil?
    ($cache.types[t].name rescue nil) || (getTypeName(t) rescue nil) || t.to_s.capitalize
  end

  def self.item_name(i)
    return nil if i.nil?
    (getItemName(i) rescue nil) || ($cache.items[i].name rescue nil) || i.to_s
  end

  def self.item_desc(i)
    ($cache.items[i].desc rescue nil) || ""
  end

  def self.abil(a)
    return nil if a.nil?
    d = $cache.abil[a] rescue nil
    { "id" => a.to_s,
      "name" => ((d.fullName rescue nil) || (d.name rescue nil) || (getAbilityName(a) rescue nil) || a.to_s),
      "desc" => ((d.fullDesc rescue nil) || (d.desc rescue nil) || "") }
  end

  def self.status_s(s)
    return nil if s.nil? || s == 0 || s == :NONE
    return s.to_s.upcase if s.is_a?(Symbol)
    { 1 => "SLEEP", 2 => "POISON", 3 => "BURN", 4 => "PARALYSIS", 5 => "FROZEN" }[s] || s.to_s
  end

  def self.cat_s(c)
    return "status" if c.nil?
    return c.to_s.downcase if c.is_a?(Symbol) || c.is_a?(String)
    ["physical", "special", "status"][c] || "status"
  end

  def self.move_info(sym, pp = nil, maxpp = nil)
    d = $cache.moves[sym] rescue nil
    { "id" => sym.to_s,
      "name" => ((d.name rescue nil) || (getMoveName(sym) rescue nil) || sym.to_s),
      "type" => (d.type rescue nil).to_s,
      "typeName" => type_name((d.type rescue nil)),
      "cat" => cat_s((d.category rescue nil)),
      "pow" => (d.basedamage rescue 0).to_i,
      "acc" => (d.accuracy rescue 0).to_i,
      "pri" => (d.priority rescue 0).to_i,
      "pp" => pp, "maxpp" => maxpp || (d.maxpp rescue nil),
      "desc" => (d.desc rescue "").to_s }
  end

  def self.resolve_file(path)
    return nil if path.nil? || path.to_s.empty?
    p = path.to_s
    return @icon_cache[p] if @icon_cache.key?(p)
    found = nil
    [p, p + ".png", p + ".PNG", p + ".gif"].each do |c|
      if File.file?(c)
        found = c
        break
      end
    end
    @icon_cache[p] = found
  end

  def self.species_icon(sym, form = 0, shiny = false, female = false, pkmn = nil)
    key = "si:#{sym}:#{form}:#{shiny}:#{female}"
    return @icon_cache[key] if @icon_cache.key?(key)
    @icon_cache[key] = custom_icon(sym, form, shiny) || game_icon(sym, form, shiny, female, pkmn)
  end

  # For the Pokédex: only what's instant (custom pack, loose files, icons already in the
  # cache). Everything else is drawn into the cache a few per frame in the background,
  # so opening the Pokédex never freezes the game; the panel picks them up as they appear.
  def self.quick_icon(sym)
    key = "si:#{sym}:0:false:false"
    return @icon_cache[key] if @icon_cache.key?(key)
    c = custom_icon(sym, 0, false)
    return c if c
    cached = "PokeRPGLink/cache/icon_#{sym}_0.png"
    return cached if File.file?(cached)
    dex = (mondata(sym).dexnum rescue nil)
    names = ["icon#{sym}", "icon#{sym.to_s.downcase}"]
    names += [format("icon%03d", dex.to_i), "icon#{dex}"] if dex
    names.each do |n|
      f = resolve_file("Graphics/Icons/#{n}")
      return f if f
    end
    (@icon_jobs ||= []) << sym
    nil
  end

  def self.icon_jobs_tick
    return if @icon_jobs.nil? || @icon_jobs.empty? || @battle
    2.times do
      sym = @icon_jobs.shift
      break unless sym
      (species_icon(sym) rescue nil)
    end
  end

  # The icon the game itself draws (its party screen icon). Tries the game's own
  # lookup first, then the usual file names by species and dex number.
  def self.game_icon(sym, form, shiny, female, pkmn)
    path = nil
    path = (pbPokemonIconFile(pkmn) rescue nil) if pkmn
    path = nil if path.to_s =~ /icon0+(\.png)?\z/i          # the "?" placeholder
    path ||= (pbCheckPokemonIconFiles([sym, female, shiny, form, false], false) rescue nil)
    path = nil if path.to_s =~ /icon0+(\.png)?\z/i
    unless path
      dex = (mondata(sym).dexnum rescue nil)
      dex = sym if sym.is_a?(Integer)
      bases = [sym.to_s, sym.to_s.downcase]
      bases += [format("%03d", dex.to_i), dex.to_s] if dex
      tries = []
      bases.each do |b|
        tries << "#{b}#{shiny ? 's' : ''}_#{form}" if form.to_i > 0
        tries << "#{b}s" if shiny
        tries << b
      end
      tries.uniq.each do |n|
        ["Graphics/Icons/icon#{n}", "Graphics/Pokemon/Icons/#{n}", "Graphics/Icons/#{n}"].each do |c|
          path ||= (pbResolveBitmap(c) rescue nil) || resolve_file(c)
        end
        break if path
      end
    end
    out = path ? image_file(path, "icon_#{sym}_#{form}#{shiny ? 's' : ''}", true) : nil
    unless @icon_logged
      @icon_logged = true
      log("icon lookup #{sym}: game path=#{path.inspect} loose=#{(path && resolve_file(path)).inspect} result=#{out.inspect} cwd=#{Dir.pwd}") rescue nil
    end
    out
  end

  # A picture as a loose file the panel can show. Games that keep their graphics
  # inside an archive only hand them to the game, so we draw the game's own bitmap
  # into PokeRPGLink/cache/ once (first frame only for icon strips).
  def self.image_file(path, key, first_frame = false)
    loose = resolve_file(path)
    return loose if loose
    name = key.to_s.gsub(/[^A-Za-z0-9_.-]/, "_") + ".png"
    out = "PokeRPGLink/cache/#{name}"            # relative to the game folder, like every other image path
    return out if File.file?(out)
    shared = false
    bmp = (Bitmap.new(path) rescue nil)
    unless bmp
      bmp = (RPG::Cache.load_bitmap("", path) rescue nil)
      shared = true
    end
    return nil unless bmp
    begin
      w = bmp.width
      h = bmp.height
      w = [h, w].min if first_frame && w >= 2 * h       # 2-frame icon strips
      Dir.mkdir("PokeRPGLink") unless File.directory?("PokeRPGLink")
      Dir.mkdir("PokeRPGLink/cache") unless File.directory?("PokeRPGLink/cache")
      write_png(out, bmp, w, h)
      out
    rescue => e
      err("image #{path}", e)
      nil
    ensure
      (bmp.dispose rescue nil) unless shared
    end
  end

  def self.write_png(file, bmp, w, h)
    require "zlib"
    raw = String.new(capacity: (w * 4 + 1) * h, encoding: Encoding::BINARY) rescue (raw = "".b)
    h.times do |y|
      raw << "\x00"
      w.times do |x|
        c = bmp.get_pixel(x, y)
        raw << [c.red.to_i, c.green.to_i, c.blue.to_i, c.alpha.to_i].pack("C4")
      end
    end
    chunk = lambda do |type, data|
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
    png = "\x89PNG\r\n\x1a\n".b
    png << chunk.call("IHDR", [w, h, 8, 6, 0, 0, 0].pack("NNCCCCC"))
    png << chunk.call("IDAT", Zlib::Deflate.deflate(raw))
    png << chunk.call("IEND", "")
    File.open(file + ".tmp", "wb") { |f| f.write(png) }
    File.rename(file + ".tmp", file)
  end

  # Your own icon pack wins over the game's: put PNGs in <game>/PokeRPGLink/icons/
  # named by species (PIKACHU.png), dex number (025.png or 25.png), with
  # optional _<form> and/or s (shiny) variants: PIKACHU_1.png, PIKACHUs.png.
  def self.custom_icon(sym, form = 0, shiny = false)
    dex = (mondata(sym).dexnum rescue nil)
    names = [sym.to_s, sym.to_s.downcase, sym.to_s.capitalize]
    names += [format("%03d", dex), dex.to_s, format("%04d", dex)] if dex
    tries = []
    names.each do |n|
      tries << "#{n}s_#{form}" << "#{n}_#{form}s" if shiny && form.to_i > 0
      tries << "#{n}_#{form}" if form.to_i > 0
      tries << "#{n}s" if shiny
      tries << n
    end
    tries.each do |n|
      f = resolve_file("PokeRPGLink/icons/#{n}")
      return f if f
    end
    nil
  end

  def self.species_sprite(sym)
    key = "sp:#{sym}"
    return @icon_cache[key] if @icon_cache.key?(key)
    dex = (mondata(sym).dexnum rescue nil)
    p = nil
    p = resolve_file(sprintf("Graphics/Battlers/%03d", dex)) if dex
    @icon_cache[key] = p
  end

  def self.item_icon(i)
    key = "it:#{i}"
    return @icon_cache[key] if @icon_cache.key?(key)
    @icon_cache[key] = (image_file(pbItemIconFile(i), "item_#{i}") rescue nil)
  end

  def self.dex_flags(sym)
    e = ($Trainer.pokedex.dexList[sym] rescue nil)
    return [false, false] unless e
    [e[:seen?] ? true : false, e[:owned?] ? true : false]
  end

  STAT_KEYS = %w[hp atk def spa spd spe]

  def self.stat_array(arr)
    return nil unless arr.is_a?(Array)
    ids = [0, 1, 2, 3, 4, 5]
    begin
      ids = [PBStats::HP, PBStats::ATTACK, PBStats::DEFENSE, PBStats::SPATK, PBStats::SPDEF, PBStats::SPEED]
    rescue
    end
    h = {}
    STAT_KEYS.each_with_index { |k, n| h[k] = arr[ids[n]].to_i }
    h
  end

  def self.nature_info(n)
    return nil if n.nil?
    d = ($cache.natures[n] rescue nil)
    name = (d.name rescue nil) || (getNatureName(n) rescue nil) || n.to_s.capitalize
    up = (d.incStat rescue nil)
    dn = (d.decStat rescue nil)
    lab = { 1 => "Atk", 2 => "Def", 3 => "SpA", 4 => "SpD", 5 => "Spe" }
    { "name" => name.to_s, "up" => lab[up], "down" => lab[dn] }
  end

  def self.gender_s(p)
    g = (p.gender rescue 2)
    { 0 => "M", 1 => "F" }[g]
  end

  def self.pokemon_info(p, idx, extra = {})
    return nil if p.nil?
    if (p.isEgg? rescue false)
      return { "slot" => idx, "egg" => true, "name" => "Egg",
               "icon" => resolve_file("Graphics/Icons/iconEgg") }.merge(extra)
    end
    sp = p.species
    t1 = (p.type1 rescue nil)
    t2 = (p.type2 rescue nil)
    t2 = nil if t2 == t1
    moves = (p.moves || []).each_with_index.map { |m, i|
      next nil if m.nil? || m.move.nil?
      move_info(m.move, m.pp, (m.totalpp rescue nil)).merge("slot" => i)
    }.compact
    exp_now = (p.exp rescue 0).to_i
    nextexp = nil
    begin
      lvl = p.level
      cur = PBExperience.pbGetStartExperience(lvl, p.growthrate)
      nxt = PBExperience.pbGetStartExperience(lvl + 1, p.growthrate)
      nextexp = { "now" => exp_now - cur, "need" => nxt - cur }
    rescue
    end
    {
      "slot" => idx,
      "species" => sp.to_s,
      "speciesName" => mon_name(sp),
      "name" => p.name.to_s,
      "dex" => (mondata(sp).dexnum rescue 0).to_i,
      "form" => (p.form rescue 0).to_i,
      "formName" => (p.getFormName rescue nil),
      "level" => p.level.to_i,
      "hp" => p.hp.to_i, "maxhp" => p.totalhp.to_i,
      "status" => status_s(p.status),
      "types" => [t1, t2].compact.map(&:to_s),
      "typeNames" => [t1, t2].compact.map { |t| type_name(t) },
      "ability" => abil(p.ability),
      "nature" => nature_info(p.nature),
      "item" => (p.item ? { "id" => p.item.to_s, "name" => item_name(p.item), "desc" => item_desc(p.item), "icon" => item_icon(p.item) } : nil),
      "stats" => { "hp" => p.totalhp.to_i, "atk" => p.attack.to_i, "def" => p.defense.to_i,
                   "spa" => p.spatk.to_i, "spd" => p.spdef.to_i, "spe" => p.speed.to_i },
      "base" => stat_array((mondata(sp).BaseStats rescue nil)),
      "ivs" => stat_array(p.iv), "evs" => stat_array(p.ev),
      "moves" => moves,
      "shiny" => (p.isShiny? rescue false),
      "gender" => gender_s(p),
      "happiness" => (p.happiness rescue nil),
      "exp" => nextexp,
      "ot" => (p.ot rescue nil),
      "ball" => (p.ballused rescue nil).to_s,
      "mail" => (p.mail ? true : false),
      "icon" => species_icon(sp, (p.form rescue 0), (p.isShiny? rescue false), (p.isFemale? rescue false), p),
      "sprite" => species_sprite(sp)
    }.merge(extra)
  end

  #--------------------------------------------------------------------------
  # Type effectiveness (plain type chart; the battle may still add modifiers)
  #--------------------------------------------------------------------------
  def self.type_mult(atk, defs)
    return 1.0 if atk.nil?
    m = 1.0
    defs.compact.uniq.each do |d|
      td = $cache.types[d] rescue nil
      next unless td
      if (td.immune || []).include?(atk)
        m *= 0
      elsif (td.weak || []).include?(atk)
        m *= 2
      elsif (td.resist || []).include?(atk)
        m *= 0.5
      end
    end
    m
  end

  def self.field_hash(effect)
    return nil unless defined?(FIELDEFFECTS)
    FIELDEFFECTS[effect] rescue nil
  end

  # Rejuvenation fields can add a second type to some moves (e.g. Surf also Electric)
  def self.field_extra_type(effect, move)
    f = field_hash(effect)
    return nil unless f
    (f[:typeMods] || {}).each { |t, list| return t if list.include?(move) }
    nil
  end

  def self.field_accuracy(effect, move)
    f = field_hash(effect)
    return nil unless f
    (f[:accuracyMods] || {}).each { |pct, list| return pct if list.include?(move) }
    nil
  end

  def self.field_mult(effect, move, type)
    f = field_hash(effect)
    return 1.0 unless f
    m = 1.0
    (f[:damageMods] || {}).each { |mult, list| m *= mult if list.include?(move) }
    (f[:typeBoosts] || {}).each { |mult, list| m *= mult if list.include?(type) }
    m
  end

  def self.fmt_mult(m)
    f = m.to_f
    f % 1 == 0 ? f.to_i.to_s : f.to_s
  end

  def self.field_summary(effect)
    f = field_hash(effect)
    return nil unless f
    boosts = []
    (f[:typeBoosts] || {}).each { |mult, list| list.each { |t| boosts << "#{type_name(t)} ×#{fmt_mult(mult)}" } }
    moves = []
    (f[:damageMods] || {}).each { |mult, list|
      next if list.empty?
      lab = mult == 0 ? "fail" : "×#{fmt_mult(mult)}"
      moves << "#{list.first(8).map { |mv| (getMoveName(mv) rescue mv.to_s) }.join(', ')}#{list.length > 8 ? '…' : ''} #{lab}"
    }
    changes = []
    (f[:fieldChange] || {}).each { |to, list|
      nm = ($cache.FEData[to].name rescue nil) || to.to_s
      nm = "no field" if nm.to_s.empty?
      changes << "#{list.first(6).map { |mv| (getMoveName(mv) rescue mv.to_s) }.join(', ')} → #{nm}"
    }
    adds = []
    (f[:typeMods] || {}).each { |t, list|
      next if list.empty?
      adds << "#{list.first(6).map { |mv| (getMoveName(mv) rescue mv.to_s) }.join(', ')}#{list.length > 6 ? '…' : ''} also #{type_name(t)}"
    }
    acc = []
    (f[:accuracyMods] || {}).each { |pct, list|
      next if list.empty?
      acc << "#{list.first(6).map { |mv| (getMoveName(mv) rescue mv.to_s) }.join(', ')} #{pct}% accuracy"
    }
    { "boosts" => boosts, "moves" => moves, "changes" => changes, "typeAdds" => adds, "accuracy" => acc,
      "mimicry" => (f[:mimicry] ? type_name(f[:mimicry]) : nil),
      "naturePower" => (f[:naturePower] ? (getMoveName(f[:naturePower]) rescue f[:naturePower].to_s) : nil) }
  end

  def self.game_info
    @game_info ||= begin
      fam = if defined?(Rejuv) && Rejuv then "rejuvenation"
            elsif defined?(Desolation) && Desolation then "desolation"
            elsif defined?(Reborn) && Reborn then "reborn"
            else "unknown" end
      { "title" => (defined?(GAMETITLE) ? GAMETITLE.to_s : "Pokémon fangame"),
        "version" => (defined?(GAMEVERSION) ? GAMEVERSION.to_s : ""), "family" => fam }
    end
  end

  #--------------------------------------------------------------------------
  # State builders
  #--------------------------------------------------------------------------
  def self.build_state
    st = { "v" => VERSION, "frame" => @frame, "toasts" => @toasts, "game" => game_info,
           "hooks" => { "ok" => @hooks_ok, "failed" => @hooks_failed } }
    if !trainer || !$game_map
      st["mode"] = "title"
      return st
    end
    st["mode"] = @battle ? "battle" : "map"
    st["player"] = {
      "name" => trainer.name.to_s,
      "money" => (trainer.money rescue 0).to_i,
      "badges" => (trainer.numbadges rescue 0).to_i,
      "seen" => (trainer.pokedex.seenCount rescue nil),
      "owned" => (trainer.pokedex.ownedCount rescue nil)
    }
    st["queue"] = @field_queue.map { |a| a[0] } + @battle_queue.map { |q| q[:t].to_s }
    st["map"] = build_map rescue (err("map", $!); nil)
    st["party"] = trainer.party.each_with_index.map { |p, i| pokemon_info(p, i) } rescue (err("party", $!); [])
    st["bag"] = build_bag rescue (err("bag", $!); [])
    st["battle"] = (@battle ? (build_battle rescue (err("battle", $!); nil)) : nil)
    st["busy"] = true if @battle && battle_busy?
    st["diag"] = { "icon" => ((st["party"] || [])[0] || {})["icon"], "jobs" => (@icon_jobs || []).length }
    decorate(st) rescue err("decorate", $!)
    st
  end

  # Engine-neutral extras: Shadow Pokémon heart gauge, Rejuvenation boss shields,
  # and the battle menu's real button labels (the 4th is "Call" vs Shadow foes).
  def self.shadow_info(p)
    return nil if p.nil?
    shadow = (p.isShadow? rescue nil)
    shadow = (p.shadowPokemon? rescue false) if shadow.nil?
    return nil unless shadow
    stage = (p.heartStage rescue nil) || (p.heart_stage rescue nil)
    { "stage" => stage.to_i, "max" => 5 }
  end

  #--------------------------------------------------------------------------
  # Catch-all: battle messages, every active effect, and community extensions
  #--------------------------------------------------------------------------
  @battle_log = []
  @log_id = 0
  @ext_state = {}
  @ext_commands = {}
  @watches = []

  def self.clean_text(t)
    t.to_s.gsub(/\\[a-zA-Z]+\[[^\]]*\]/, "").gsub(/\\[a-zA-Z]+/, "").gsub(/<\/?[a-z]+[^>]*>/i, "")
     .delete("\x01").gsub(/\s+/, " ").strip
  end

  # every line the battle prints — this is how mechanics nobody coded for still reach the panel
  def self.log_message(msg)
    t = clean_text(msg)
    return if t.empty? || (@battle_log.last && @battle_log.last["text"] == t)
    @log_id += 1
    @battle_log << { "id" => @log_id, "text" => t }
    @battle_log.shift while @battle_log.length > 40
  end

  def self.clear_battle_log; @battle_log.clear; end

  EFFECT_NOISE = /(Count|Counter|Turns?|Fainted|Used|Index|Target|Rate|Initial|Original|Hits|Times|Prev|Damage|Moves|User|Source|Player|Party)\z|\A(Last|Choice|Pickup|Gem|Parental|Move(Next|Index)|TwoTurn|Bide|Counter|MirrorCoat|Destiny|Instruct|Round|Snatch|Quash|Protect(Rate|Negation)|Fling|Tracker|Type3|Illusion|Transform|Participant|Usage|Prankster|Rage$|Skip|Damage|Hyper|Endure|Flinch|Helping|Roost|Powder|Smack)/

  # Rebornverse: battler effects are a Hash keyed by readable symbols
  def self.other_effects(b)
    out = []
    (b.effects || {}).each do |k, v|
      next if WATCH_EFFECTS.include?(k) || k.to_s =~ EFFECT_NOISE
      out << k.to_s if v == true || (v.is_a?(Integer) && v > 0)
    end
    out.first(16)
  rescue
    []
  end

  # ---- extension API (see EXTENDING.md) ----
  # PokeRPGLink.add_state("karma") { |state| $game_variables[42] }   -> state.ext.karma
  def self.add_state(key, &blk); @ext_state[key.to_s] = blk; end
  # PokeRPGLink.add_command("heal") { |args| ... }                    -> skin sends "ext heal ..."
  def self.add_command(verb, &blk); @ext_commands[verb.to_s] = blk; end
  # PokeRPGLink.watch_variable(42, "Karma") / watch_switch(150, "Got Surf")  -> shown on the Save tab
  def self.watch_variable(id, label); @watches << [:var, id, label.to_s]; end
  def self.watch_switch(id, label); @watches << [:sw, id, label.to_s]; end

  def self.ext_payload
    out = {}
    @ext_state.each do |k, blk|
      begin
        out[k] = blk.call(@last_built_state)
      rescue => e
        err("ext #{k}", e)
      end
    end
    watch = @watches.map do |kind, id, label|
      v = (kind == :var ? ($game_variables[id] rescue nil) : ($game_switches[id] rescue nil))
      v = v.to_s unless v.nil? || v.is_a?(Numeric) || v == true || v == false
      { "label" => label, "value" => v, "kind" => kind.to_s }
    end
    [out, watch]
  end

  def self.load_extensions
    Dir[File.join(dir, "extensions", "*.rb")].sort.each do |f|
      begin
        load f
        log("extension loaded: #{File.basename(f)}")
      rescue Exception => e
        err("extension #{File.basename(f)}", e)
      end
    end
  rescue => e
    err("extensions", e)
  end

  def self.decorate(st)
    @last_built_state = st
    unless @icon_diag
      @icon_diag = true
      p0 = (st["party"] || []).compact.first
      log("icon check: pwd=#{Dir.pwd} first party icon=#{p0 && p0['icon'].inspect} species=#{p0 && p0['species']}") rescue nil
    end
    ext, watch = ext_payload
    st["ext"] = ext unless ext.empty?
    st["watch"] = watch unless watch.empty?
    objs = (trainer.party rescue []) || []
    (st["party"] || []).each_with_index do |h, i|
      sh = shadow_info(objs[i])
      h["shadow"] = sh if sh && h
    end
    b = st["battle"]
    return unless b && @battle
    b["commands"] = @command_labels if @command_labels
    b["balls"] = (ball_info rescue nil)
    b["log"] = @battle_log.last(14)
    (b["battlers"] || []).each do |h|
      obj = (@battle.battlers[h["index"]] rescue nil)
      next unless obj
      sh = shadow_info((obj.pokemon rescue nil))
      h["shadow"] = sh if sh
      oe = other_effects(obj) - (h["effects"] || [])
      h["otherEffects"] = oe unless oe.empty?
      if (obj.isbossmon rescue false)
        h["boss"] = { "shields" => (obj.shieldCount rescue nil) || ((obj.pokemon.shieldCount rescue nil)) }
      end
    end
    pobjs = ((@battle.pbParty(0) rescue nil) || [])
    (b["party"] || []).each do |h|
      sh = shadow_info(pobjs[h["slot"]])
      h["shadow"] = sh if sh
    end
  end

  def self.command_labels=(v); @command_labels = v; end

  def self.time_period
    t = pbGetTimeNow
    return "morning" if (PBDayNight.isMorning?(t) rescue false)
    return "night" if (PBDayNight.isNight?(t) rescue false)
    return "evening" if (PBDayNight.isEvening?(t) rescue false)
    "day"
  rescue
    "day"
  end

  ENC_KIND = {
    0 => ["grass", "any"], 1 => ["cave", "any"], 2 => ["surf", "any"], 3 => ["rocksmash", "any"],
    4 => ["oldrod", "any"], 5 => ["goodrod", "any"], 6 => ["superrod", "any"], 7 => ["headbutt", "any"],
    8 => ["grass", "morning"], 9 => ["grass", "day"], 10 => ["grass", "night"], 11 => ["bugcontest", "any"]
  }

  def self.build_map
    id = $game_map.map_id
    md = $cache.mapdata[id] rescue nil
    period = time_period
    groups = []
    enc = nil
    if $PokemonEncounters
      enc = ($PokemonEncounters.enctypes rescue nil) || $PokemonEncounters.instance_variable_get(:@enctypes)
    end
    if (enc.nil? || enc.compact.empty?) && md
      enc = [md.Land, md.Cave, md.Water, md.RockSmash, md.OldRod, md.GoodRod, md.SuperRod,
             md.Headbutt, md.LandMorning, md.LandDay, md.LandNight] rescue []
    end
    (enc || []).each_with_index do |table, et|
      next unless table.is_a?(Hash) && !table.empty?
      kind, time = ENC_KIND[et] || ["other", "any"]
      list = []
      table.each do |sp, slots|
        slots = [slots] unless slots.is_a?(Array)
        chance = 0
        lmin = 999
        lmax = 0
        form = 0
        slots.each do |s|
          next unless s.is_a?(Array)
          chance += s[0].to_i
          lmin = [lmin, s[1].to_i].min
          lmax = [lmax, (s[2] || s[1]).to_i].max
          form = s[3].to_i if s[3].is_a?(Integer)
        end
        seen, owned = dex_flags(sp)
        list << { "species" => sp.to_s, "name" => mon_name(sp),
                  "dex" => (mondata(sp).dexnum rescue 0).to_i,
                  "chance" => chance, "min" => (lmin == 999 ? nil : lmin), "max" => lmax,
                  "seen" => seen, "owned" => owned,
                  "types" => [(mondata(sp).Type1 rescue nil), (mondata(sp).Type2 rescue nil)].compact.uniq.map(&:to_s),
                  "icon" => species_icon(sp, form) }
      end
      list.sort_by! { |e| -e["chance"] }
      groups << { "kind" => kind, "time" => time, "encType" => et, "list" => list }
    end
    pos = (player_mappos rescue nil)
    {
      "id" => id,
      "name" => (pbGetMapNameFromId(id) rescue $game_map.name rescue "").to_s,
      "outdoor" => (md.Outdoor ? true : false rescue false),
      "period" => period,
      "weather" => ($game_screen.weather_type rescue nil).to_s,
      "x" => $game_player.x, "y" => $game_player.y,
      "surfing" => ($PokemonGlobal.surfing ? true : false rescue false),
      "pos" => pos,
      "encounters" => groups
    }
  end

  def self.build_bag
    names = (pbPocketNames rescue ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Enhancements", "Battle Items", "Key Items"])
    pockets = []
    ($PokemonBag.pockets rescue []).each_with_index do |items, pi|
      next if pi == 0 || items.nil?
      list = []
      items.each do |it|
        next if it.nil?
        it = it[0] if it.is_a?(Array)
        q = ($PokemonBag.pbQuantity(it) rescue 1).to_i
        next if q <= 0
        bk, fk = item_kinds(it)
        list << { "id" => it.to_s, "name" => item_name(it), "qty" => q,
                  "desc" => item_desc(it), "icon" => item_icon(it), "battle" => bk, "field" => fk,
                  "key" => (pbIsKeyItem?(it) rescue false),
                  "mail" => (pbIsMail?(it) rescue false),
                  "important" => (pbIsImportantItem?(it) rescue false) }
      end
      pockets << { "pocket" => pi, "name" => names[pi].to_s, "items" => list }
    end
    pockets
  end

  WATCH_EFFECTS = [:Confusion, :Substitute, :LeechSeed, :Taunt, :Encore, :Torment, :Curse,
                   :Attract, :Disable, :Ingrain, :AquaRing, :Yawn, :PerishSong, :FocusEnergy,
                   :Charge, :MagnetRise, :Telekinesis, :Embargo, :HealBlock, :Nightmare,
                   :Trapping, :MeanLook, :Imprison, :Protect, :Minimize, :DefenseCurl,
                   :Stockpile, :Roost, :SmackDown, :Electrify, :LaserFocus, :ThroatChop]

  def self.battler_info(b, own, active_idx)
    return nil if b.nil? || (b.fainted rescue false) || (b.hp.to_i <= 0 && (b.pokemon.nil? rescue true))
    p = b.pokemon rescue nil
    sp = (b.species rescue nil)
    t1 = (b.type1 rescue nil)
    t2 = (b.type2 rescue nil)
    t3 = (b.effects[:Type3] rescue nil)
    types = [t1, t2, t3].compact.uniq
    stages = {}
    lab = { "atk" => :ATTACK, "def" => :DEFENSE, "spa" => :SPATK, "spd" => :SPDEF, "spe" => :SPEED, "acc" => :ACCURACY, "eva" => :EVASION }
    lab.each do |k, c|
      i = (PBStats.const_get(c) rescue nil)
      v = (b.stages[i] rescue 0).to_i if i
      stages[k] = v if v && v != 0
    end
    eff = []
    WATCH_EFFECTS.each do |k|
      v = (b.effects[k] rescue nil)
      next if v.nil? || v == false || v == 0 || v == -1 || (v.is_a?(Array) && v.empty?)
      eff << k.to_s
    end
    h = {
      "index" => b.index, "own" => own, "dex" => (mondata(sp).dexnum rescue 0).to_i,
      "species" => sp.to_s, "name" => b.name.to_s, "speciesName" => mon_name(sp),
      "level" => b.level.to_i,
      "hp" => b.hp.to_i, "maxhp" => b.totalhp.to_i,
      "status" => status_s(b.status),
      "types" => types.map(&:to_s), "typeNames" => types.map { |t| type_name(t) },
      "ability" => abil(b.ability),
      "stages" => stages, "effects" => eff,
      "active" => b.index == active_idx,
      "icon" => species_icon(sp, (b.form rescue 0), (p.isShiny? rescue false), (p.isFemale? rescue false), p),
      "sprite" => species_sprite(sp)
    }
    if own
      h["item"] = (b.item ? { "id" => b.item.to_s, "name" => item_name(b.item) } : nil)
      h["stats"] = { "atk" => b.attack.to_i, "def" => b.defense.to_i, "spa" => b.spatk.to_i,
                     "spd" => b.spdef.to_i, "spe" => b.speed.to_i } rescue nil
    else
      seen, owned = dex_flags(sp)
      h["owned"] = owned
      h["hpPct"] = (b.totalhp.to_i > 0 ? (100.0 * b.hp / b.totalhp).round : 0)
      h["base"] = stat_array((mondata(sp).BaseStats rescue nil))
    end
    h
  end

  def self.build_battle
    bt = @battle
    active = (@menu_index || 0)
    battlers = (bt.battlers rescue []).compact
    foes = battlers.select { |b| (b.index & 1) == 1 && !(b.fainted rescue false) && b.hp.to_i > 0 }
    own  = battlers.select { |b| (b.index & 1) == 0 && !(b.fainted rescue false) && b.hp.to_i > 0 }
    field = (bt.field.effect rescue nil)
    fdata = ($cache.FEData[field] rescue nil)
    weather = (bt.weather rescue nil)
    weather = nil if weather == 0
    out = {
      "turn" => (bt.turncount rescue 0).to_i,
      "menu" => @menu.to_s,
      "targeting" => target_info,
      "activeIndex" => active,
      "double" => (bt.doublebattle ? true : false rescue false),
      "trainer" => (bt.opponent ? true : false rescue false),
      "canRun" => !(bt.opponent rescue true) && !(bt.cantescape rescue false),
      "weather" => (weather ? { "id" => weather.to_s, "name" => nil, "turns" => (bt.weatherduration rescue -1).to_i } : nil),
      "field" => (field ? { "id" => field.to_s, "name" => (fdata.name rescue field.to_s).to_s,
                             "message" => [(fdata.message rescue nil)].flatten.compact.first.to_s,
                             "isField" => (bt.field.isFieldEffect? rescue true),
                             "duration" => (bt.field.duration rescue 0).to_i,
                             "under" => (bt.field.duration.to_i > 0 ? (($cache.FEData[bt.field.backup].name rescue nil)) : nil),
                             "info" => field_summary(field) } : nil),
      "global" => [], "sides" => [{}, {}],
      "battlers" => [],
      "moves" => [],
      "party" => []
    }
    begin
      (bt.state.effects || {}).each do |k, v|
        next if v.nil? || v == false || v == 0 || v == -1
        out["global"] << { "id" => k.to_s, "turns" => (v.is_a?(Integer) ? v : nil) }
      end
    rescue
    end
    begin
      out["global"] << { "id" => "TrickRoom", "turns" => bt.trickroom } if bt.trickroom.to_i > 0
    rescue
    end
    2.times do |s|
      begin
        (bt.sides[s].effects || {}).each do |k, v|
          next if v.nil? || v == false || v == 0
          out["sides"][s][k.to_s] = (v == true ? 1 : v)
        end
      rescue
      end
    end
    (own + foes).each { |b| h = battler_info(b, (b.index & 1) == 0, active); out["battlers"] << h if h }

    # Moves of the battler currently choosing
    me = (bt.battlers[active] rescue nil)
    if me && (me.index & 1) == 0
      (me.moves || []).each_with_index do |m, i|
        next if m.nil? || (m.move rescue nil).nil? || m.move == 0
        mv = move_info(m.move, (m.pp rescue nil), (m.totalpp rescue nil))
        mtype = (m.type rescue nil) || ($cache.moves[m.move].type rescue nil)
        mv["type"] = mtype.to_s
        mv["typeName"] = type_name(mtype)
        mv["slot"] = i
        stab = (me.type1 == mtype || me.type2 == mtype) rescue false
        mv["stab"] = stab
        mv["field"] = field_mult(field, m.move, mtype)
        xt = field_extra_type(field, m.move)
        mv["fieldType"] = xt ? type_name(xt) : nil
        fa = field_accuracy(field, m.move)
        mv["fieldAcc"] = fa
        others = (own + foes).reject { |o| o.index == me.index }
        mv["vs"] = others.map { |f|
          ftypes = [(f.type1 rescue nil), (f.type2 rescue nil), (f.effects[:Type3] rescue nil)]
          { "index" => f.index, "foe" => (f.index & 1) == 1,
            "mult" => (mv["cat"] == "status" ? nil : (type_mult(mtype, ftypes) * (xt ? type_mult(xt, ftypes) : 1)).round(3)) }
        }
        tsym = (me.pbTarget(m) rescue nil) || (m.target rescue nil)
        mv["target"] = tsym.to_s
        if (bt.doublebattle rescue false)
          kind = if m.move == :ACUPRESSURE || tsym == :UserOrPartner then :ally
                 elsif tsym == :SingleNonUser then :any end
          mv["pick"] = valid_targets(bt, me.index, kind) if kind
        end
        out["moves"] << mv
      end
      out["specials"] = {
        "mega" => (bt.pbCanMegaEvolve?(active) rescue false),
        "z" => (bt.pbCanZMove?(active) rescue false),
        "ultra" => (bt.pbCanUltraBurst?(active) rescue false)
      }
    end

    # Player party for the Switch tab, in the battle's display order
    begin
      party = bt.pbParty(0)
      order = (bt.partyorder rescue nil) || (0...party.length).to_a
      order.each do |pi|
        p = party[pi]
        next unless p
        inbattle = own.any? { |b| (b.pokemonIndex rescue -1) == pi }
        out["party"] << pokemon_info(p, pi, "inBattle" => inbattle)
      end
    rescue => e
      err("battle party", e)
    end
    out
  end

  #--------------------------------------------------------------------------
  # Static exports (written on request)
  #--------------------------------------------------------------------------
  def self.build_dex
    found = {}
    begin
      $cache.mapdata.each do |mid, md|
        next unless md
        nm = nil
        [[:Land, "grass"], [:LandMorning, "grass (morning)"], [:LandDay, "grass (day)"],
         [:LandNight, "grass (night)"], [:Cave, "cave"], [:Water, "surf"], [:RockSmash, "rock smash"],
         [:OldRod, "old rod"], [:GoodRod, "good rod"], [:SuperRod, "super rod"], [:Headbutt, "headbutt"]].each do |m, lab|
          t = (md.send(m) rescue nil)
          next unless t.is_a?(Hash)
          t.each_key do |sp|
            nm ||= (pbGetMapNameFromId(mid) rescue mid.to_s)
            (found[sp] ||= []) << "#{nm} · #{lab}"
          end
        end
      end
    rescue => e
      err("dex locations", e)
    end
    list = []
    $cache.pkmn.each do |sp, _raw|
      d = mondata(sp)
      next unless d
      seen, owned = dex_flags(sp)
      begin
      list << {
        "species" => sp.to_s, "name" => (d.name rescue sp.to_s).to_s, "dex" => (d.dexnum rescue 0).to_i,
        "types" => [(d.Type1 rescue nil), (d.Type2 rescue nil)].compact.uniq.map(&:to_s),
        "base" => (stat_array(d.BaseStats) rescue nil),
        "abilities" => ((d.Abilities || []) rescue []).compact.map { |a| abil(a) },
        "kind" => (d.kind rescue "").to_s, "entry" => (d.dexentry rescue "").to_s,
        "height" => (d.Height rescue nil), "weight" => (d.Weight rescue nil),
        "evos" => ((d.evolutions || []).map { |e| e.is_a?(Array) ? mon_name(e[0]) : nil }.compact rescue []),
        "seen" => seen, "owned" => owned,
        "where" => (found[sp] || []).uniq.first(12),
        "icon" => quick_icon(sp), "sprite" => species_sprite(sp)
      }
      rescue => e
        err("dex #{sp}", e)
      end
    end
    list.sort_by! { |e| e["dex"] }
    { "species" => list, "types" => ($cache.types.keys.map { |t| { "id" => t.to_s, "name" => type_name(t) } } rescue []) }
  end

  def self.build_townmap
    d = townmap_data
    points = d["points"].map do |pt|
      fd = pt["flyData"]
      fd = (fly_spot(pt["x"], pt["y"], pt["region"]) rescue fd) if fd
      pt.merge("fly" => fd ? true : false,
               "visited" => fd ? ($PokemonGlobal.visitedMaps[fd[0]] ? true : false) : false).tap { |h| h.delete("flyData") }
    end
    { "square" => 16, "style" => d["style"], "regions" => d["regions"], "points" => points,
      "player" => player_mappos,
      "canFly" => ($cache.mapdata[$game_map.map_id].Outdoor ? true : false rescue false) }
  end
end

#==============================================================================
# Virtual buttons — lets the touch screen press A/B/D-pad etc. without
# stealing focus from the real controller. Each press lasts one frame.
#==============================================================================
module PokeRPGInput
  @queue  = []
  @active = nil
  @held   = nil
  @held_frames = 0

  NAMES = { "A" => :C, "C" => :C, "RAW_A" => :A, "B" => :B, "X" => :X, "Y" => :Y, "Z" => :Z,
            "L" => :L, "R" => :R, "UP" => :UP, "DOWN" => :DOWN, "LEFT" => :LEFT, "RIGHT" => :RIGHT,
            "CTRL" => :CTRL, "ALT" => :ALT, "SHIFT" => :SHIFT, "AUX1" => :AUX1, "AUX2" => :AUX2 }

  def self.const(name)
    c = NAMES[name.to_s.upcase] || name.to_s.upcase.to_sym
    Input.const_get(c) rescue nil
  end

  def self.press(name)
    b = const(name)
    return unless b
    @queue << b << nil   # gap so two presses register as two
  end

  def self.hold(name, frames)
    b = const(name)
    return unless b
    @held = b
    @held_frames = [[frames.to_i, 1].max, 120].min
  end

  def self.idle?
    @queue.empty? && @active.nil?
  end

  def self.on_update
    @active = @queue.shift
    if @held_frames > 0
      @held_frames -= 1
      @held = nil if @held_frames == 0
    end
  end

  def self.active?(b)
    return false if b.nil?
    (@active && @active == b) || (@held && @held == b)
  end
end

#==============================================================================
# ADAPTER — Pokémon Essentials v19–v21 (Infinite Fusion, and fangames that ship
# their scripts as loose files in Data/Scripts). Only switched on when the game
# has GameData::Species; the Rebornverse code above stays as the default.
#==============================================================================
module PokeRPGLink
  module EssMethods
    def trainer; (defined?($player) && $player) || $Trainer; end
    def bag; $bag || $PokemonBag; end

    def game_info
      @game_info ||= begin
        title = (System.game_title rescue nil) || (defined?(Settings::GAME_TITLE) ? Settings::GAME_TITLE : nil)
        title ||= ($data_system.game_title rescue nil) if defined?($data_system)
        fam = defined?(PokeBattle_Scene) && !defined?(Battle::Scene) ? "essentials-v19" : "essentials-v21"
        fam = "infinite-fusion" if title.to_s =~ /infinite ?fusion/i
        ver = (defined?(Settings::GAME_VERSION) ? Settings::GAME_VERSION : nil) || (defined?(Essentials::VERSION) ? Essentials::VERSION : "")
        { "title" => (title || "Pokémon fangame").to_s, "version" => ver.to_s, "family" => fam }
      end
    end

    # ---- names & data -----------------------------------------------------
    def gd(klass, id)
      return nil if id.nil?
      return id unless id.is_a?(Symbol) || id.is_a?(String) || id.is_a?(Integer)
      GameData.const_get(klass).try_get(id) rescue (GameData.const_get(klass).get(id) rescue nil)
    end

    def mon_name(sym)
      (gd(:Species, sym).name rescue nil) || sym.to_s.capitalize
    end

    def type_name(t)
      return nil if t.nil?
      (gd(:Type, t).name rescue nil) || t.to_s.capitalize
    end

    def item_name(i)
      return nil if i.nil?
      (gd(:Item, i).name rescue nil) || i.to_s
    end

    def item_desc(i)
      (gd(:Item, i).description rescue nil) || ""
    end

    def abil(a)
      return nil if a.nil?
      d = gd(:Ability, a)
      { "id" => (d.id rescue a).to_s, "name" => (d.name rescue a.to_s).to_s, "desc" => (d.description rescue "").to_s }
    end

    def item_id(i)
      return nil if i.nil?
      i.respond_to?(:id) ? i.id : i
    end

    def dex_flags(sym)
      t = trainer
      seen = (t.seen?(sym) rescue (t.pokedex.seen?(sym) rescue false))
      owned = (t.owned?(sym) rescue (t.pokedex.owned?(sym) rescue false))
      [seen ? true : false, owned ? true : false]
    end

    def species_icon(sym, form = 0, shiny = false, female = false)
      key = "si:#{sym}:#{form}:#{shiny}:#{female}"
      return @icon_cache[key] if @icon_cache.key?(key)
      f = (GameData::Species.icon_filename(sym, form, female ? 1 : 0, shiny) rescue nil)
      @icon_cache[key] = custom_icon(sym, form, shiny) || (f && image_file(f, "icon_#{sym}_#{form}#{shiny ? 's' : ''}", true))
    end

    def pokemon_icon(p)
      (custom_icon(p.species, (p.form rescue 0), (p.shiny? rescue false))) ||
        ((f = (GameData::Species.icon_filename_from_pokemon(p) rescue nil)) && image_file(f, "icon_#{p.species}_#{(p.form rescue 0)}#{(p.shiny? rescue false) ? 's' : ''}", true)) ||
        species_icon(p.species)
    end

    def species_sprite(sym)
      key = "sp:#{sym}"
      return @icon_cache[key] if @icon_cache.key?(key)
      @icon_cache[key] = resolve_file((GameData::Species.front_sprite_filename(sym) rescue nil))
    end

    def item_icon(i)
      key = "it:#{i}"
      return @icon_cache[key] if @icon_cache.key?(key)
      f = (GameData::Item.icon_filename(i) rescue nil)
      @icon_cache[key] = f && image_file(f, "item_#{i}")
    end

    ESS_STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]

    def stat_hash(h)
      return nil unless h
      out = {}
      STAT_KEYS.each_with_index { |k, n| out[k] = (h[ESS_STATS[n]] rescue nil).to_i }
      out
    end

    def cat_s(c)
      ["physical", "special", "status"][c.to_i] || "status"
    end

    def move_power(m)
      (m.respond_to?(:power) ? m.power : nil) || (m.respond_to?(:base_damage) ? m.base_damage : nil) ||
        (m.respond_to?(:baseDamage) ? m.baseDamage : 0)
    end

    def move_info(id, pp = nil, maxpp = nil)
      d = gd(:Move, id)
      { "id" => id.to_s, "name" => (d.name rescue id.to_s).to_s,
        "type" => (d.type rescue nil).to_s, "typeName" => type_name((d.type rescue nil)),
        "cat" => cat_s((d.category rescue 2)), "pow" => (move_power(d) rescue 0).to_i,
        "acc" => (d.accuracy rescue 0).to_i, "pri" => (d.priority rescue 0).to_i,
        "pp" => pp, "maxpp" => maxpp || (d.total_pp rescue nil), "desc" => (d.description rescue "").to_s }
    end

    def status_s(s)
      return nil if s.nil? || s == :NONE || s == 0
      s.to_s.upcase
    end

    def pokemon_info(p, idx, extra = {})
      return nil if p.nil?
      if (p.egg? rescue false)
        return { "slot" => idx, "egg" => true, "name" => "Egg", "icon" => pokemon_icon(p) }.merge(extra)
      end
      types = ((p.types rescue nil) || [(p.type1 rescue nil), (p.type2 rescue nil)]).compact.uniq
      nat = (p.nature rescue nil)
      up = down = nil
      begin
        (nat.stat_changes || []).each do |st, v|
          lab = { :ATTACK => "Atk", :DEFENSE => "Def", :SPECIAL_ATTACK => "SpA", :SPECIAL_DEFENSE => "SpD", :SPEED => "Spe" }[st]
          v > 0 ? (up = lab) : (down = lab)
        end
      rescue
      end
      nextexp = nil
      begin
        gr = GameData::GrowthRate.get(p.growth_rate)
        cur = gr.minimum_exp_for_level(p.level)
        nxt = gr.minimum_exp_for_level(p.level + 1)
        nextexp = { "now" => p.exp - cur, "need" => nxt - cur }
      rescue
      end
      it = item_id((p.item rescue nil))
      {
        "slot" => idx, "species" => p.species.to_s, "speciesName" => (p.species_data.name rescue mon_name(p.species)).to_s,
        "name" => p.name.to_s, "form" => (p.form rescue 0).to_i, "level" => p.level.to_i,
        "hp" => p.hp.to_i, "maxhp" => p.totalhp.to_i, "status" => status_s((p.status rescue nil)),
        "types" => types.map(&:to_s), "typeNames" => types.map { |t| type_name(t) },
        "ability" => abil((p.ability rescue nil)),
        "nature" => (nat ? { "name" => (nat.name rescue nat.to_s).to_s, "up" => up, "down" => down } : nil),
        "item" => (it ? { "id" => it.to_s, "name" => item_name(it), "desc" => item_desc(it), "icon" => item_icon(it) } : nil),
        "stats" => { "hp" => p.totalhp.to_i, "atk" => p.attack.to_i, "def" => p.defense.to_i,
                     "spa" => p.spatk.to_i, "spd" => p.spdef.to_i, "spe" => p.speed.to_i },
        "base" => stat_hash((p.species_data.base_stats rescue nil)),
        "ivs" => stat_hash((p.iv rescue nil)), "evs" => stat_hash((p.ev rescue nil)),
        "moves" => (p.moves || []).each_with_index.map { |m, i| m && m.id ? move_info(m.id, m.pp, (m.total_pp rescue nil)).merge("slot" => i) : nil }.compact,
        "shiny" => (p.shiny? rescue false), "gender" => ((p.female? rescue false) ? "F" : ((p.male? rescue false) ? "M" : nil)),
        "happiness" => (p.happiness rescue nil), "exp" => nextexp,
        "fusion" => ((p.isFusion? rescue false) ? true : nil),
        "mail" => ((p.mail rescue nil) ? true : false),
        "icon" => pokemon_icon(p), "sprite" => species_sprite(p.species)
      }.merge(extra)
    end

    # ---- overworld ------------------------------------------------------------
    def enc_kind(type)
      n = type.to_s
      time = "any"
      if n =~ /(Morning|Day|Afternoon|Evening|Night)\z/
        t = $1
        time = { "Morning" => "morning", "Day" => "day", "Afternoon" => "day", "Evening" => "night", "Night" => "night" }[t]
        n = n.sub(/#{t}\z/, "")
      end
      kind = { "Land" => "grass", "Cave" => "cave", "Water" => "surf", "OldRod" => "oldrod", "GoodRod" => "goodrod",
               "SuperRod" => "superrod", "RockSmash" => "rocksmash", "HeadbuttLow" => "headbutt", "HeadbuttHigh" => "headbutt",
               "BugContest" => "bugcontest", "PokeRadar" => "pokeradar" }[n] || n.downcase
      [kind, time]
    end

    def encounter_tables(map_id)
      ver = ($PokemonGlobal.encounter_version rescue 0) || 0
      e = (GameData::Encounter.get(map_id, ver) rescue nil) || (GameData::Encounter.get(map_id, 0) rescue nil)
      e ? (e.types || {}) : {}
    end

    def build_map
      id = $game_map.map_id
      groups = []
      encounter_tables(id).each do |type, slots|
        next if slots.nil? || slots.empty?
        kind, time = enc_kind(type)
        by = {}
        slots.each do |s|
          chance, sp, lmin, lmax = s
          e = by[sp] ||= { "chance" => 0, "min" => 999, "max" => 0 }
          e["chance"] += chance.to_i
          e["min"] = [e["min"], lmin.to_i].min
          e["max"] = [e["max"], (lmax || lmin).to_i].max
        end
        list = by.map do |sp, e|
          seen, owned = dex_flags(sp)
          d = gd(:Species, sp)
          { "species" => sp.to_s, "name" => mon_name(sp), "dex" => (d.id_number rescue 0).to_i,
            "chance" => e["chance"], "min" => e["min"], "max" => e["max"], "seen" => seen, "owned" => owned,
            "types" => (((d.types rescue nil) || [(d.type1 rescue nil), (d.type2 rescue nil)]).compact.uniq.map(&:to_s)),
            "icon" => species_icon(sp) }
        end.sort_by { |e| -e["chance"] }
        groups << { "kind" => kind, "time" => time, "encType" => type.to_s, "list" => list }
      end
      { "id" => id, "name" => ($game_map.name rescue (pbGetMapNameFromId(id) rescue "")).to_s,
        "outdoor" => ((GameData::MapMetadata.try_get(id).outdoor_map rescue false) ? true : false),
        "period" => time_period, "x" => $game_player.x, "y" => $game_player.y,
        "surfing" => (($PokemonGlobal.surfing rescue false) ? true : false),
        "pos" => (player_mappos rescue nil), "encounters" => groups }
    end

    def build_bag
      names = (PokemonBag.pocket_names rescue nil) || (PokemonBag.pocketNames rescue nil) || []
      out = []
      (bag.pockets rescue []).each_with_index do |items, pi|
        next if pi == 0 || items.nil?
        list = items.map do |slot|
          id, q = slot.is_a?(Array) ? slot : [slot, 1]
          d = gd(:Item, id)
          next nil if d.nil? || q.to_i <= 0
          bk, fk = item_kinds(id)
          { "id" => id.to_s, "name" => (d.name rescue id.to_s).to_s, "qty" => q.to_i, "desc" => (d.description rescue "").to_s,
            "icon" => item_icon(id), "battle" => bk, "field" => fk, "key" => ((d.is_key_item? rescue false) ? true : false),
            "mail" => ((d.is_mail? rescue false) ? true : false), "important" => ((d.is_important? rescue false) ? true : false) }
        end.compact
        out << { "pocket" => pi, "name" => (names[pi] || "Pocket #{pi}").to_s, "items" => list }
      end
      out
    end

    def build_state
      st = super
      st["features"] = { "saveAsks" => true }
      st["player"]["seen"] ||= (trainer.pokedex.seen_count rescue nil) if st["player"]
      st["player"]["owned"] ||= (trainer.pokedex.owned_count rescue nil) if st["player"]
      st
    end

    # ---- town map & fly -----------------------------------------------------
    def townmap_data
      regions = []
      points = []
      if defined?(GameData::TownMap)   # v21
        GameData::TownMap.each do |tm|
          regions << { "id" => tm.id, "name" => tm.name.to_s, "offset" => 8,
                       "image" => resolve_file("Graphics/UI/Town Map/#{tm.filename}") || resolve_file("Graphics/Pictures/#{tm.filename}") }
          (tm.point || []).each do |pt|
            fd = (pt[4] && pt[5] && pt[6]) ? [pt[4], pt[5], pt[6]] : nil
            points << { "x" => pt[0], "y" => pt[1], "name" => pt[2].to_s, "poi" => pt[3].to_s, "region" => tm.id, "flyData" => fd }
          end
        end
      else                              # v19 / Infinite Fusion: classic array data
        (pbLoadTownMapData || []).each_with_index do |v, rid|
          next unless v.is_a?(Array)
          regions << { "id" => rid, "name" => v[0].to_s, "offset" => 8, "image" => resolve_file("Graphics/Pictures/#{v[1]}") }
          (v[2] || []).each do |loc|
            fd = (loc[4] && loc[5] && loc[6]) ? [loc[4], loc[5], loc[6]] : nil
            points << { "x" => loc[0], "y" => loc[1], "name" => loc[2].to_s, "poi" => loc[3].to_s, "region" => rid, "flyData" => fd }
          end
        end
      end
      { "style" => "classic", "regions" => regions, "points" => points }
    end

    def player_mappos
      md = (GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
      pos = (md.town_map_position rescue nil)
      return nil unless pos.is_a?(Array) && pos.length >= 3
      pos = pos[0, 3].dup
      begin
        ms = md.town_map_size
        if ms && ms[0] && ms[0] > 0
          sqw = ms[0]
          sqh = (ms[1].length.to_f / ms[0]).ceil
          pos[1] += ($game_player.x * sqw / $game_map.width).floor if sqw > 1
          pos[2] += ($game_player.y * sqh / $game_map.height).floor if sqh > 1
        end
      rescue
      end
      pos
    end

    def fly_spot(x, y, region = nil)
      pt = townmap_data["points"].find { |q| q["x"] == x && q["y"] == y && (region.nil? || q["region"] == region) }
      pt && pt["flyData"]
    end

    def do_fly(x, y, region = nil)
      spot = fly_spot(x, y, region)
      return toast("You can't fly there", "error") unless spot
      return toast("You haven't visited there yet", "error") unless $PokemonGlobal.visitedMaps[spot[0]]
      party = trainer.party
      user = party.find { |p| !(p.egg?) && (p.hasMove?(:FLY) rescue false) }
      user ||= party.find { |p| !(p.egg?) && (p.compatible_with_move?(:FLY) rescue false) }
      return toast("Nobody in your party can Fly", "error") unless user
      if defined?(pbCanFly?)
        ok = (pbCanFly?(user, true) rescue (pbCanFly?(user) rescue true))
        return unless ok
      end
      if defined?(pbFlyToNewLocation)                      # v20+
        $game_temp.fly_destination = spot
        pbFlyToNewLocation(user)
      else                                                 # v19 / Infinite Fusion
        $PokemonTemp.flydata = spot
        defined?(pbFly) ? pbFly(:FLY, user) : pbUseHiddenMove(user, :FLY)
      end
    end

    # ---- overworld actions ----------------------------------------------------
    def do_save
      if $game_system && $game_system.save_disabled
        return toast("Saving is disabled right now", "error")
      end
      pbSaveScreen      # the game's own save screen (handles multiple save slots)
    end

    def do_open_party
      hidden = nil
      pbFadeOutIn {
        sscene = PokemonParty_Scene.new
        sscreen = PokemonPartyScreen.new(sscene, trainer.party)
        hidden = sscreen.pbPokemonScreen
      }
      pbUseHiddenMove(hidden[0], hidden[1]) if hidden
    end

    def do_open_bag
      item = nil
      pbFadeOutIn {
        scene = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, bag)
        item = screen.pbStartScreen
      }
      pbUseKeyItemInField(item) if item
    end

    def do_open_dex
      pbFadeOutIn {
        scene = PokemonPokedex_Scene.new
        screen = PokemonPokedexScreen.new(scene)
        screen.pbStartScreen
      }
    end

    def bag_qty(item)
      (bag.quantity(item) rescue (bag.pbQuantity(item) rescue 0)).to_i
    end

    def do_use_item(item)
      return toast("You don't have that item", "error") if bag_qty(item) <= 0
      ret = pbUseItem(bag, item)
      pbUseKeyItemInField(item) if ret == 2
    end

    def do_give_item(pi, item)
      pkmn = trainer.party[pi]
      return toast("No Pokémon in that slot", "error") unless pkmn
      return toast("You don't have that item", "error") if bag_qty(item) <= 0
      return toast("Give mail from the in-game Bag instead", "error") if (gd(:Item, item).is_mail? rescue false)
      pbGiveItemToPokemon(item, pkmn, HeadlessPartyScene.new, pi)
    end

    def do_take_item(pi)
      pkmn = trainer.party[pi]
      return toast("No Pokémon in that slot", "error") unless pkmn
      return toast("Remove mail from the in-game party screen", "error") if (pkmn.mail rescue nil)
      pbTakeItemFromPokemon(pkmn, HeadlessPartyScene.new)
    end

    def do_swap_move(pi, i, j)
      pkmn = trainer.party[pi]
      return unless pkmn && pkmn.moves[i] && pkmn.moves[j] && i != j
      pkmn.moves[i], pkmn.moves[j] = pkmn.moves[j], pkmn.moves[i]
      toast("#{pkmn.name}: moves reordered", "ok")
    end

    def do_swap_party(i, j)
      pt = trainer.party
      return unless pt[i] && pt[j] && i != j
      pt[i], pt[j] = pt[j], pt[i]
      toast("Party order changed", "ok")
    end

    # ---- items & balls -----------------------------------------------------------
    def ball?(it)
      (gd(:Item, it).is_poke_ball? rescue false) ? true : false
    end

    def item_kinds(it)
      d = gd(:Item, it)
      return [nil, nil] unless d
      bu = (d.battle_use rescue 0).to_i
      fu = (d.field_use rescue 0).to_i
      battle = { 1 => "pokemon", 6 => "pokemon", 2 => "move", 7 => "move", 3 => "battler", 8 => "battler",
                 4 => "ball", 9 => "ball", 5 => "self", 10 => "self" }[bu]
      field = if [1, 3, 4, 5].include?(fu) || (ItemHandlers.hasUseOnPokemon(it) rescue false) then "pokemon"
              elsif fu == 2 || (ItemHandlers.hasUseInFieldHandler(it) rescue false) || (ItemHandlers.hasOutHandler(it) rescue false) then "field"
              end
      [battle, field]
    rescue
      [nil, nil]
    end

    # Essentials' bag screen hands its choice to a block; we hand it ours instead.
    def panel_item_menu(scene, battle, idx, q, _rest, blk)
      return (toast("Open the bag on the top screen for that", "error"); nil) unless blk
      d = gd(:Item, q[:item])
      return (toast("Unknown item", "error"); nil) unless d
      return (toast("You don't have that item", "error"); nil) if bag_qty(d.id) <= 0
      ut = (d.battle_use rescue 0).to_i
      return (toast("#{d.name} can't be used in battle", "error"); nil) if ut == 0
      hs = HeadlessPartyScene.new
      case ut
      when 1, 6
        return (toast("Pick a Pokémon for that item", "error"); nil) if q[:target].nil?
        blk.call(d.id, ut, q[:target], -1, hs)
      when 2, 7
        return (toast("Pick a Pokémon for that item", "error"); nil) if q[:target].nil?
        blk.call(d.id, ut, q[:target], (q[:move] || 0), hs)
      when 3, 8
        t = q[:target] || (battle.battlers[idx].pokemonIndex rescue 0)
        blk.call(d.id, ut, t, -1, hs)
      when 4, 9
        t = q[:target]
        t ||= (battle.battlers.compact.find { |b| !b.fainted? && (b.opposes?(idx) rescue (b.index & 1) == 1) }.index rescue 1)
        blk.call(d.id, ut, t, -1, hs)
      else
        blk.call(d.id, ut, idx, -1, hs)
      end
      nil
    end

    def do_use_item_on(item, pi, move = nil)
      pkmn = trainer.party[pi]
      return toast("No Pokémon in that slot", "error") unless pkmn
      return toast("You don't have that item", "error") if bag_qty(item) <= 0
      return toast("Eggs can't use items", "error") if (pkmn.egg? rescue false)
      ret = pbUseItemOnPokemon(item, pkmn, HeadlessPartyScene.new)
      toast("It won't have any effect.", "error") unless ret
    end

    # ---- battle -------------------------------------------------------------
    def special_button; "RAW_A"; end   # Input::ACTION toggles Mega Evolution in Essentials

    def display_index(pi); pi; end      # the battle party screen lists the display party as-is

    def valid_targets(bt, index, kind)
      td = @target_data
      return [] unless bt
      (0...[bt.battlers.length, 4].max).select do |i|
        b = bt.battlers[i]
        next false if b.nil? || b.fainted?
        td ? (bt.pbMoveCanTarget?(index, i, td) rescue i != index) : i != index
      end
    end

    def target_data=(td); @target_data = td; end

    def eff_mult(type, defender)
      return 1.0 if type.nil?
      types = (defender.pbTypes(true) rescue [defender.type1, defender.type2]).compact
      v = Effectiveness.calculate(type, *types) rescue (return 1.0)
      base = defined?(Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER) ? Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER : Effectiveness::NORMAL_EFFECTIVE
      (v.to_f / base.to_f).round(3)
    end

    WEATHER_NAMES = { :Rain => "Rain", :Sun => "Harsh sun", :Sandstorm => "Sandstorm", :Hail => "Hail", :Snowstorm => "Snow",
                      :HarshSun => "Extreme sun", :HeavyRain => "Heavy rain", :StrongWinds => "Strong winds", :ShadowSky => "Shadow sky" }
    BATTLER_FX = %w[Confusion Substitute Taunt Encore Torment Curse Disable Ingrain AquaRing Yawn PerishSong FocusEnergy
                    Charge MagnetRise Telekinesis Embargo HealBlock Nightmare Trapping Imprison Minimize Stockpile SmackDown
                    LaserFocus ThroatChop Protect]
    BATTLER_FX_IDX = %w[LeechSeed Attract MeanLook]   # hold a battler index, -1 = off
    SIDE_FX = %w[Reflect LightScreen AuroraVeil Tailwind Spikes ToxicSpikes StealthRock StickyWeb Safeguard Mist LuckyChant]
    FIELD_FX = %w[TrickRoom Gravity MagicRoom WonderRoom FairyLock IonDeluge]

    # PBEffects lists battler, position, side and field effects in that order, each
    # block numbered from 0 — so the constant order tells us every effect's scope.
    # PBEffects lists battler, position, side and field effects in that order, each
    # block numbered from 0. Ruby doesn't promise constant order, so read the order
    # from the game's own PBEffects script (loose-script games have it on disk).
    def pbeffect_scopes
      @pbe_scopes ||= begin
        order = []
        f = Dir["Data/Scripts/**/*PBEffects*.rb"].first
        if f
          File.read(f).scan(/^\s*([A-Z]\w*)\s*=\s*(\d+)/) { |n, v| order << [n, v.to_i] }
        end
        if order.empty?
          PBEffects.constants.each { |c| v = (PBEffects.const_get(c) rescue nil); order << [c.to_s, v] if v.is_a?(Integer) }
        end
        segs = []
        cur = nil
        order.each do |n, v|
          if v == 0 || cur.nil?
            cur = {}
            segs << cur
          end
          cur[v] ||= n
        end
        if segs.length == 1   # v21 numbers every block uniquely (700s, 800s, 900s): one map fits all
          all = segs[0]
          { :battler => all.select { |k, _| k < 700 }, :position => all, :side => all, :field => all }
        else
          { :battler => segs[0] || {}, :position => segs[1] || {}, :side => segs[2] || {}, :field => segs[3] || {} }
        end
      rescue
        { :battler => {}, :position => {}, :side => {}, :field => {} }
      end
    end

    def fx_all(store, scope)
      names = pbeffect_scopes[scope]
      out = {}
      pairs = store.is_a?(Hash) ? store.to_a : (store || []).each_with_index.map { |v, i| [i, v] }
      pairs.each do |i, v|
        n = names[i]
        next if n.nil?
        out[n] = (v.is_a?(Integer) && v > 1 ? v : 1) if v == true || (v.is_a?(Integer) && v > 0)
      end
      out
    end

    def other_effects(b)
      shown = BATTLER_FX + BATTLER_FX_IDX
      fx_all(b.effects, :battler).keys.reject { |n| shown.include?(n) || n =~ PokeRPGLink::EFFECT_NOISE }.first(16)
    rescue
      []
    end

    def fx_list(hash, names, idx_names = [])
      out = {}
      (names + idx_names).each do |n|
        c = (PBEffects.const_get(n) rescue nil)
        next if c.nil?
        v = (hash[c] rescue nil)
        on = idx_names.include?(n) ? (v.is_a?(Integer) && v >= 0) : (v == true || (v.is_a?(Integer) && v > 0))
        out[n] = (v.is_a?(Integer) && !idx_names.include?(n) ? v : 1) if on
      end
      out
    end

    def battler_info(b, own, active_idx)
      return nil if b.nil? || b.fainted?
      types = (b.pbTypes(true) rescue [b.type1, b.type2]).compact.uniq
      stages = {}
      { "atk" => :ATTACK, "def" => :DEFENSE, "spa" => :SPECIAL_ATTACK, "spd" => :SPECIAL_DEFENSE,
        "spe" => :SPEED, "acc" => :ACCURACY, "eva" => :EVASION }.each do |k, s|
        v = (b.stages[s] rescue 0).to_i
        stages[k] = v if v != 0
      end
      sp = b.species
      h = { "index" => b.index, "own" => own, "species" => sp.to_s, "name" => b.name.to_s, "dex" => (gd(:Species, sp).id_number rescue 0).to_i,
            "speciesName" => ((b.pokemon.species_data.name rescue nil) || mon_name(sp)).to_s, "level" => b.level.to_i,
            "hp" => b.hp.to_i, "maxhp" => b.totalhp.to_i, "status" => status_s((b.status rescue nil)),
            "types" => types.map(&:to_s), "typeNames" => types.map { |t| type_name(t) },
            "ability" => abil((b.ability rescue nil)),
            "stages" => stages, "effects" => fx_list(b.effects, BATTLER_FX, BATTLER_FX_IDX).keys,
            "active" => b.index == active_idx,
            "icon" => (b.pokemon ? pokemon_icon(b.pokemon) : species_icon(sp)), "sprite" => species_sprite(sp) }
      if own
        it = item_id((b.item rescue nil))
        h["item"] = it ? { "id" => it.to_s, "name" => item_name(it) } : nil
        h["stats"] = { "atk" => b.attack.to_i, "def" => b.defense.to_i, "spa" => b.spatk.to_i, "spd" => b.spdef.to_i, "spe" => b.speed.to_i } rescue nil
      else
        seen, owned = dex_flags(sp)
        h["owned"] = owned
        h["hpPct"] = b.totalhp.to_i > 0 ? (100.0 * b.hp / b.totalhp).round : 0
        h["base"] = stat_hash((gd(:Species, sp).base_stats rescue nil))
      end
      h
    end

    def build_battle
      bt = @battle
      active = @menu_index || 0
      all = (bt.battlers rescue []).compact.reject { |b| b.fainted? }
      foes = all.select { |b| b.opposes? rescue (b.index & 1) == 1 }
      own = all - foes
      fld = bt.field
      w = (fld.weather rescue nil)
      w = nil if w == :None || w.nil?
      terr = (fld.terrain rescue nil)
      terr = nil if terr == :None
      double = !(bt.singleBattle? rescue true)
      out = {
        "turn" => (bt.turnCount rescue 0).to_i, "menu" => @menu.to_s, "targeting" => target_info,
        "activeIndex" => active, "double" => double, "trainer" => (bt.trainerBattle? rescue false) ? true : false,
        "canRun" => !(bt.trainerBattle? rescue true),
        "weather" => (w ? { "id" => w.to_s, "name" => (WEATHER_NAMES[w] || (gd(:BattleWeather, w).name rescue w.to_s)),
                             "turns" => (fld.weatherDuration rescue -1).to_i } : nil),
        "field" => (terr ? { "id" => terr.to_s, "name" => "#{(gd(:BattleTerrain, terr).name rescue terr.to_s)} Terrain".sub("Terrain Terrain", "Terrain"),
                              "message" => "", "isField" => true, "duration" => (fld.terrainDuration rescue 0).to_i, "info" => nil } : nil),
        "global" => fx_list(fld.effects, FIELD_FX).merge(fx_all(fld.effects, :field)).map { |k, v| { "id" => k, "turns" => (v.is_a?(Integer) && v > 1 ? v : nil) } },
        "sides" => [fx_list(bt.sides[0].effects, SIDE_FX).merge(fx_all(bt.sides[0].effects, :side)),
                    fx_list(bt.sides[1].effects, SIDE_FX).merge(fx_all(bt.sides[1].effects, :side))],
        "battlers" => [], "moves" => [], "party" => []
      }
      (own + foes).each { |b| h = battler_info(b, !foes.include?(b), active); out["battlers"] << h if h }
      me = bt.battlers[active]
      if me && !foes.include?(me)
        (me.moves || []).each_with_index do |m, i|
          next if m.nil? || m.id.nil?
          mtype = (m.pbCalcType(me) rescue m.type)
          mv = move_info(m.id, m.pp, (m.total_pp rescue nil))
          mv["type"] = mtype.to_s
          mv["typeName"] = type_name(mtype)
          mv["pow"] = (move_power(m) rescue mv["pow"]).to_i
          mv["slot"] = i
          mv["stab"] = (me.pbHasType?(mtype) rescue false)
          mv["field"] = 1
          mv["vs"] = (own + foes).reject { |o| o.index == me.index }.map { |o|
            { "index" => o.index, "foe" => foes.include?(o), "mult" => (mv["cat"] == "status" ? nil : eff_mult(mtype, o)) } }
          td = (m.pbTarget(me) rescue nil)
          mv["target"] = (td.id rescue td).to_s
          if double && td && (td.num_targets rescue 0) == 1
            @target_data = td
            mv["pick"] = valid_targets(bt, me.index, :any)
            @target_data = nil
          end
          out["moves"] << mv
        end
        out["specials"] = { "mega" => (bt.pbCanMegaEvolve?(active) rescue false) }
      end
      begin
        disp = (bt.pbPlayerDisplayParty(0) rescue nil) || bt.pbParty(0)
        inb = own.map { |b| b.pokemon }
        disp.each_with_index { |p, i| out["party"] << pokemon_info(p, i, "inBattle" => inb.include?(p)) if p }
      rescue => e
        err("ess party", e)
      end
      out
    end

    # ---- static exports -------------------------------------------------------
    def build_dex
      where = {}
      begin
        ver = ($PokemonGlobal.encounter_version rescue 0) || 0
        GameData::Encounter.each_of_version(ver) do |enc|
          nm = (pbGetMapNameFromId(enc.map) rescue enc.map.to_s)
          (enc.types || {}).each do |type, slots|
            kind, time = enc_kind(type)
            lab = "#{nm} · #{kind}#{time == 'any' ? '' : " (#{time})"}"
            (slots || []).each { |s| (where[s[1]] ||= []) << lab }
          end
        end
      rescue => e
        err("dex where", e)
      end
      list = []
      n = 0
      each = GameData::Species.respond_to?(:each_species) ? :each_species : :each
      GameData::Species.send(each) do |d|
        next if (d.form rescue 0) != 0
        n += 1
        break if n > 3000
        sp = d.species rescue d.id
        seen, owned = dex_flags(sp)
        list << {
          "species" => sp.to_s, "name" => d.name.to_s, "dex" => ((d.id_number rescue nil) || n).to_i,
          "types" => (((d.types rescue nil) || [(d.type1 rescue nil), (d.type2 rescue nil)]).compact.uniq.map(&:to_s)),
          "base" => stat_hash((d.base_stats rescue nil)),
          "abilities" => ((d.abilities || []) + (d.hidden_abilities || []) rescue []).uniq.map { |a| abil(a) },
          "kind" => (d.category rescue "").to_s, "entry" => (d.pokedex_entry rescue "").to_s,
          "height" => (d.height rescue nil), "weight" => (d.weight rescue nil),
          "evos" => ((d.get_evolutions(true) rescue d.evolutions) || []).map { |e| mon_name(e[0]) rescue nil }.compact.uniq,
          "seen" => seen, "owned" => owned, "where" => (where[sp] || []).uniq.first(12),
          "icon" => species_icon(sp), "sprite" => species_sprite(sp)
        }
      end
      types = []
      (GameData::Type.each { |t| types << { "id" => t.id.to_s, "name" => t.name.to_s } unless (t.pseudo_type rescue false) }) rescue nil
      { "species" => list.sort_by { |e| e["dex"] }, "types" => types }
    end
  end
end

if PokeRPGLink.essentials?
  PokeRPGLink.singleton_class.prepend(PokeRPGLink::EssMethods)
end

#==============================================================================
# ADAPTER — Pokémon Tectonic (Essentials v19.1, heavily rebuilt). Sits on top of
# the Essentials adapter and only changes what Tectonic does differently:
#   - battle menu: Fight / Dex / Ball / Pokémon / Info / Run (no bag in battle)
#   - effects are data (GameData::BattleEffect) instead of PBEffects numbers
#   - stat "steps" instead of stages, new statuses (Numb, Frostbite, Dizzy, …)
#   - Avatars: boss Pokémon with several health bars and extra moves per turn
#   - adaptive moves, up to three types, several held items
#==============================================================================
module PokeRPGLink
  def self.tectonic?
    defined?(GameData::Avatar) && defined?(GameData::BattleEffect) ? true : false
  end

  module TectMethods
    TECT_CMDS = [0, 2, 3, 5]   # Fight, Ball, Pokémon, Run in Tectonic's six-button menu

    def game_info
      @game_info ||= begin
        g = super.dup
        g["family"] = "tectonic"
        g["title"] = "Pokémon Tectonic" if g["title"].to_s.strip.empty? || g["title"] =~ /chasm|fangame/i
        v = (File.read("release_version.txt").strip rescue nil)
        g["version"] = v if v && !v.empty?
        g
      end
    end

    def cmd_slot(i); TECT_CMDS[i] || i; end

    def command_texts(t)
      return nil unless t.is_a?(Array) && t.length >= 7
      TECT_CMDS.map { |i| t[i + 1].to_s }
    end

    def cat_s(c)
      ["physical", "special", "status", "adaptive"][c.to_i] || "status"
    end

    # effects that are switched on, with the game's own names; only ones the game itself shows
    def tect_effects(holder)
      out = {}
      holder.eachEffect(true) do |id, value, data|
        next if data.respond_to?(:info_displayed) && !data.info_displayed
        name = (data.name rescue nil) || (data.real_name rescue nil) || id.to_s
        counts = (data.type rescue nil) == :Integer
        out[name.to_s] = (counts && value.is_a?(Integer) && value > 1 ? value : 1)
      end
      out
    rescue
      {}
    end

    def tect_statuses(b)
      ((b.getStatuses rescue [(b.status rescue nil)]) || []).map { |x| status_s(x) }.compact
    end

    def pokemon_info(p, idx, extra = {})
      h = super
      return h unless h && p && !(p.egg? rescue false)
      items = ((p.items rescue nil) || []).compact
      if items.length > 1
        h["items"] = items.map { |it| { "id" => it.to_s, "name" => item_name(it), "desc" => item_desc(it), "icon" => item_icon(it) } }
      end
      if (h["item"].nil? || h["item"]["id"].to_s.empty?) && items[0]
        it = items[0]
        h["item"] = { "id" => it.to_s, "name" => item_name(it), "desc" => item_desc(it), "icon" => item_icon(it) }
      end
      h
    end

    def battler_info(b, own, active_idx)
      h = super
      return h unless h
      st = tect_statuses(b)
      h["status"] = st[0]
      h["status2"] = st[1] if st[1]
      steps = {}
      { "atk" => :ATTACK, "def" => :DEFENSE, "spa" => :SPECIAL_ATTACK, "spd" => :SPECIAL_DEFENSE,
        "spe" => :SPEED, "acc" => :ACCURACY, "eva" => :EVASION }.each do |k, s|
        v = (b.steps[s] rescue 0).to_i
        steps[k] = v if v != 0
      end
      h["stages"] = steps
      fx = tect_effects(b)
      h["effects"] = fx.keys.first(8)
      h["otherEffects"] = fx.keys.drop(8).first(16)
      h["types"] = ((b.pbTypes(true) rescue nil) || []).compact.uniq.map(&:to_s)
      h["typeNames"] = h["types"].map { |t| type_name(t.to_sym) }
      if (b.boss? rescue false)
        bars = nil
        begin
          n = b.avatarData.num_phases.to_i
          bars = [n - b.avatarPhase.to_i + 1, 1].max if n > 1
        rescue
        end
        acts = 1 + ((b.extraMovesPerTurn rescue 0) || 0).to_i
        h["boss"] = { "label" => "Avatar", "bars" => bars, "actions" => (acts > 1 ? acts : nil) }
      end
      h
    end

    def tect_eff(move, mtype, user, target)
      v = move.pbCalcTypeMod(mtype, user, target, true)
      (v.to_f / Effectiveness::NORMAL_EFFECTIVE.to_f).round(3)
    rescue
      eff_mult(mtype, target)
    end

    def build_battle
      out = super
      bt = @battle
      fld = bt.field
      w = (fld.weather rescue nil)
      if w && w != :None
        out["weather"] = { "id" => w.to_s, "name" => ((gd(:BattleWeather, w).name rescue nil) || w.to_s),
                           "turns" => (fld.weatherDuration rescue -1).to_i }
      end
      out["field"] = nil
      out["global"] = tect_effects(fld).map { |k, v| { "id" => k, "turns" => (v > 1 ? v : nil) } }
      out["sides"] = [tect_effects(bt.sides[0]), tect_effects(bt.sides[1])]
      out["sidesAll"] = true            # these are already the effects the game shows
      wild = !(bt.trainerBattle? rescue true) && !(bt.bossBattle? rescue false)
      out["noBag"] = !wild               # Tectonic's "Ball" button only works in wild battles
      out["canRun"] = wild
      me = bt.battlers[@menu_index || 0]
      if me && !(me.opposes? rescue false)
        all = (bt.battlers rescue []).compact.reject { |x| x.fainted? }
        moves = ((me.getMoves rescue nil) || me.moves || [])
        out["moves"] = []
        moves.each_with_index do |m, i|
          next if m.nil? || m.id.nil?
          mtype = (m.pbCalcType(me) rescue m.type)
          mv = move_info(m.id, m.pp, (m.total_pp rescue nil))
          mv["slot"] = i
          mv["type"] = mtype.to_s
          mv["typeName"] = type_name(mtype)
          mv["pow"] = (m.baseDamage rescue mv["pow"]).to_i
          mv["cat"] = cat_s((m.calculatedCategory rescue nil) || (m.category rescue 2)) rescue mv["cat"]
          mv["stab"] = (me.pbHasType?(mtype) rescue false)
          mv["field"] = 1
          mv["vs"] = all.reject { |o| o.index == me.index }.map { |o|
            { "index" => o.index, "foe" => (o.opposes?(me.index) rescue (o.index & 1) == 1),
              "mult" => (mv["cat"] == "status" ? nil : tect_eff(m, mtype, me, o)) } }
          td = (m.pbTarget(me) rescue nil)
          mv["target"] = (td.id rescue td).to_s
          if out["double"] && td && (td.num_targets rescue 0) == 1
            @target_data = td
            mv["pick"] = valid_targets(bt, me.index, :any)
            @target_data = nil
          end
          out["moves"] << mv
        end
      end
      out
    end

    def do_take_item(pi)
      pkmn = trainer.party[pi]
      return toast("No Pokémon in that slot", "error") unless pkmn
      return super unless defined?(pbTakeItemsFromPokemon)
      pbTakeItemsFromPokemon(pkmn)
    end

    def do_give_item(pi, item)
      pkmn = trainer.party[pi]
      return toast("No Pokémon in that slot", "error") unless pkmn
      return toast("You don't have that item", "error") if bag_qty(item) <= 0
      pbGiveItemToPokemon(item, pkmn, HeadlessPartyScene.new, true)
    end
  end
end

if PokeRPGLink.essentials? && PokeRPGLink.tectonic?
  PokeRPGLink.singleton_class.prepend(PokeRPGLink::TectMethods)
end

#==============================================================================
# Hooks — each one installed separately so one failure can't break the rest
#==============================================================================
module PokeRPGLink
  # True when klass#meth is already our wrapper (guards against double-loading
  # after an F12 soft reset, which would otherwise alias the wrapper to itself).
  def self.wrapped?(klass, meth)
    loc = (klass.instance_method(meth).source_location rescue nil)
    loc && File.basename(loc[0].to_s) == "PokeRPGLink.rb"
  end

  def self.hook(name)
    yield
    @hooks_ok << name
  rescue Exception => e
    @hooks_failed << name
    err("hook #{name}", e)
  end
end

# Every hook is a module *prepended* in front of the game's class. Its methods take
# whatever they're given and pass it on with an explicit super(*args) — trimmed to what
# the game's method accepts — so the game's own method is always called the way the
# game called it, even if the game or another mod redefines it later.
module PokeRPGLink
  # Hand the game exactly what it can take. Some Ruby builds (and some games' own
  # wrappers) disagree on how many arguments reach a method; a wrapper that passes
  # too many is what crashed level-ups, so trim to what the next method accepts.
  @fit_cache = {}
  def self.fit(obj, name, args)
    key = [obj.class, name, args.length]
    n = @fit_cache.fetch(key) do
      max = nil
      begin
        mod = obj.singleton_class.ancestors.find { |m| m.name.to_s.start_with?("PokeRPGLink::Patch_") && m.instance_methods(false).include?(name) }
        sm = mod && mod.instance_method(name).bind(obj).super_method
        if sm
          ps = sm.parameters
          max = ps.any? { |t, _| t == :rest } ? nil : ps.count { |t, _| t == :req || t == :opt }
        end
      rescue
        max = nil
      end
      @fit_cache[key] = max
    end
    n && args.length > n ? args.first(n) : args
  end

  def self.patch(klass, name, &body)
    mname = "Patch_" + name.gsub(/[^A-Za-z0-9]/, "_")
    mod = const_defined?(mname, false) ? const_get(mname, false) : const_set(mname, Module.new(&body))
    return if klass.ancestors.include?(mod)   # already installed (e.g. after a soft reset)
    klass.prepend(mod)
  end
end

PokeRPGLink.hook("input") do
  PokeRPGLink.patch(Input.singleton_class, "input") do
    def update(*__a, &__b)
      r = super(*PokeRPGLink.fit(self, :update, __a), &__b)
      begin
        PokeRPGLink.tick
        PokeRPGInput.on_update
      rescue => e
        PokeRPGLink.err("tick", e)
      end
      r
    end
    def trigger?(*__a, &__b)
      b = __a[0]
      PokeRPGInput.active?(b) ? true : super(*PokeRPGLink.fit(self, :trigger?, __a), &__b)
    end
    def press?(*__a, &__b)
      b = __a[0]
      PokeRPGInput.active?(b) ? true : super(*PokeRPGLink.fit(self, :press?, __a), &__b)
    end
    def repeat?(*__a, &__b)
      b = __a[0]
      PokeRPGInput.active?(b) ? true : super(*PokeRPGLink.fit(self, :repeat?, __a), &__b)
    end
  end
end

# ---- battle scene hooks: the same code serves both engines --------------------
PokeRPGLink.const_set(:SCENE_CLASS,
  PokeRPGLink.essentials? ? (defined?(Battle::Scene) ? Battle::Scene : PokeBattle_Scene) : PokeBattle_Scene) unless PokeRPGLink.const_defined?(:SCENE_CLASS)
PokeRPGLink.const_set(:ESS_SCENE, PokeRPGLink::SCENE_CLASS) unless PokeRPGLink.const_defined?(:ESS_SCENE)
unless PokeRPGLink.const_defined?(:BATTLE_CLASS)
  bc = [(defined?(Battle) && Battle.is_a?(Class) ? Battle : nil), (defined?(PokeBattle_Battle) ? PokeBattle_Battle : nil)].compact
  PokeRPGLink.const_set(:BATTLE_CLASS, bc.find { |c| c.method_defined?(:pbThrowPokeBall) } || bc.first)
end

PokeRPGLink.hook("battle-start-end") do
  PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "battle_start_end") do
    def pbStartBattle(*__a, &__b)
      battle = __a[0]
      PokeRPGLink.battle = battle
      PokeRPGLink.turn_ready
      PokeRPGLink.battle_queue.clear
      PokeRPGLink.clear_battle_log
      super(*PokeRPGLink.fit(self, :pbStartBattle, __a), &__b)
    end
    def pbEndBattle(*__a, &__b)
      super(*PokeRPGLink.fit(self, :pbEndBattle, __a), &__b)
    ensure
      PokeRPGLink.battle = nil
      PokeRPGLink.menu = :none
      PokeRPGLink.battle_queue.clear
    end
  end
end

PokeRPGLink.hook("battle-command-menu") do
  PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "command_menu") do
    def pbCommandMenuEx(*__a, &__b)
      index = __a[0]
      rest = (__a[1..-1] || [])
      PokeRPGLink.battle ||= @battle
      PokeRPGLink.turn_ready
      PokeRPGLink.menu = :command
      PokeRPGLink.menu_index = index
      PokeRPGLink.command_labels = (PokeRPGLink.command_texts(rest[0]) rescue nil)
      super(*PokeRPGLink.fit(self, :pbCommandMenuEx, __a), &__b)
    ensure
      PokeRPGLink.menu = :none
    end
  end
end

PokeRPGLink.hook("battle-fight-menu") do
  PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "fight_menu") do
    def pbFightMenu(*__a, &__b)
      index = __a[0]
      PokeRPGLink.battle ||= @battle
      PokeRPGLink.menu = :fight
      PokeRPGLink.menu_index = index
      super(*PokeRPGLink.fit(self, :pbFightMenu, __a), &__b)
    ensure
      PokeRPGLink.menu = :none
    end
  end
end

PokeRPGLink.hook("battle-frame") do
  PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "frame") do
    def pbFrameUpdate(*__a, &__b)
      a = (__a[0..-1] || [])
      begin
        PokeRPGLink.battle_frame(self, a[0]) if PokeRPGLink.menu != :none
      rescue => e
        PokeRPGLink.err("battle_frame", e)
      end
      super(*PokeRPGLink.fit(self, :pbFrameUpdate, __a), &__b)
    end
  end
end

PokeRPGLink.hook("battle-target") do
  if PokeRPGLink.essentials?
    PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "target") do
      def pbChooseTarget(*__a, &__b)
        index = __a[0]
        target_data = __a[1]
        PokeRPGLink.target_data = target_data
        pt = PokeRPGLink.peek_pending_target
        if pt
          if (target_data.num_targets rescue 1) != 1
            return pbFirstTarget(index, target_data)   # spread move picked on the panel: confirm it
          elsif pt[0] && PokeRPGLink.valid_targets(@battle, index, :any).include?(pt[0])
            return pt[0]
          end
        end
        PokeRPGLink.begin_target(index, :any)
        super(*PokeRPGLink.fit(self, :pbChooseTarget, __a), &__b)
      ensure
        PokeRPGLink.menu = :none
        PokeRPGLink.target_data = nil
      end
    end
  else
    PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "target") do
      def pbChooseTarget(*__a, &__b)
        index = __a[0]
        t = PokeRPGLink.take_pending_target(@battle, index, :any)
        return t if t
        PokeRPGLink.begin_target(index, :any)
        r = catch(:pokerpglink_target) { super(*PokeRPGLink.fit(self, :pbChooseTarget, __a), &__b) }
        (pbUpdateSelected(-1) rescue nil)
        r
      ensure
        PokeRPGLink.menu = :none
      end

      def pbChooseTargetAcupressure(*__a, &__b)
        index = __a[0]
        t = PokeRPGLink.take_pending_target(@battle, index, :ally)
        return t if t
        PokeRPGLink.begin_target(index, :ally)
        r = catch(:pokerpglink_target) { super(*PokeRPGLink.fit(self, :pbChooseTargetAcupressure, __a), &__b) }
        (pbUpdateSelected(-1) rescue nil)
        r
      ensure
        PokeRPGLink.menu = :none
      end

      def pbUpdateSelected(*__a, &__b)
        r = super(*PokeRPGLink.fit(self, :pbUpdateSelected, __a), &__b)
        PokeRPGLink.target_frame(self) if PokeRPGLink.menu == :target   # may throw :pokerpglink_target
        r
      end
    end
  end
end

PokeRPGLink.hook("battle-switch") do
  if PokeRPGLink.essentials?
    PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "switch") do
      def pbPartyScreen(*__a, &__b)
        PokeRPGLink.in_switch = true
        PokeRPGLink.menu = :switch
        super(*PokeRPGLink.fit(self, :pbPartyScreen, __a), &__b)
      ensure
        PokeRPGLink.in_switch = false
        PokeRPGLink.auto_switchin = false
        PokeRPGLink.menu = :none
      end
    end
  else
    PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "switch") do
      def pbSwitch(*__a, &__b)
        index = __a[0]
        lax = __a[1]
        cancancel = __a[2]
        pi = PokeRPGLink.take_switch
        if pi
          party = @battle.pbParty(index)
          ok = party[pi] && !party[pi].isEgg? &&
               (lax ? @battle.pbCanSwitchLax?(index, pi, true) : @battle.pbCanSwitch?(index, pi, true))
          return pi if ok
        end
        PokeRPGLink.in_switch = true
        PokeRPGLink.menu = :switch
        super(*PokeRPGLink.fit(self, :pbSwitch, __a), &__b)
      ensure
        PokeRPGLink.in_switch = false
        PokeRPGLink.auto_switchin = false
        PokeRPGLink.menu = :none
      end
    end
  end
end

# Items chosen on the panel's bag skip the game's bag screen entirely.
PokeRPGLink.hook("battle-item-menu") do
  PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "item_menu") do
    def pbItemMenu(*__a, &__b)
      index = __a[0]
      rest = (__a[1..-1] || [])
      blk = __b
      q = PokeRPGLink.take_item_choice
      return super(*PokeRPGLink.fit(self, :pbItemMenu, __a), &__b) unless q
      PokeRPGLink.panel_item_menu(self, @battle, index, q, rest, blk)
    end
  end
end

PokeRPGLink.hook("battle-messages") do
  PokeRPGLink.patch(PokeRPGLink::SCENE_CLASS, "messages") do
    def pbDisplayMessage(*__a, &__b)
      msg = __a[0]
      (PokeRPGLink.log_message(msg) rescue nil)
      super(*PokeRPGLink.fit(self, :pbDisplayMessage, __a), &__b)
    end
    def pbDisplayPausedMessage(*__a, &__b)
      msg = __a[0]
      (PokeRPGLink.log_message(msg) rescue nil)
      super(*PokeRPGLink.fit(self, :pbDisplayPausedMessage, __a), &__b)
    end
    def pbDisplayConfirmMessage(*__a, &__b)
      msg = __a[0]
      (PokeRPGLink.log_message(msg) rescue nil)
      super(*PokeRPGLink.fit(self, :pbDisplayConfirmMessage, __a), &__b)
    end
  end
end

PokeRPGLink.hook("ball-tracking") do
  raise "no battle class" unless PokeRPGLink::BATTLE_CLASS
  PokeRPGLink.patch(PokeRPGLink::BATTLE_CLASS, "ball") do
    def pbThrowPokeBall(*__a, &__b)
      idx = __a[0]
      ball = __a[1]
      (PokeRPGLink.remember_ball(ball) rescue nil)
      super(*PokeRPGLink.fit(self, :pbThrowPokeBall, __a), &__b)
    end
  end
end

PokeRPGLink.hook("party-screen") do
  klass = PokeRPGLink.essentials? ? PokemonParty_Scene : PokemonScreen_Scene
  PokeRPGLink.patch(klass, "party_scene") do
    def update(*__a, &__b)
      begin
        PokeRPGLink.party_screen_frame(self)
      rescue => e
        PokeRPGLink.err("party_frame", e)
      end
      super(*PokeRPGLink.fit(self, :update, __a), &__b)
    end
    def pbShowCommands(*__a, &__b)
      if PokeRPGLink.auto_switchin
        PokeRPGLink.auto_switchin = false
        return 0   # "Switch In"
      end
      super(*PokeRPGLink.fit(self, :pbShowCommands, __a), &__b)
    end
  end
end

PokeRPGLink.hook("map") do
  PokeRPGLink.patch(Scene_Map, "map") do
    def update(*__a, &__b)
      r = super(*PokeRPGLink.fit(self, :update, __a), &__b)
      begin
        PokeRPGLink.map_frame
      rescue => e
        PokeRPGLink.err("map_frame", e)
      end
      r
    end
  end
end

PokeRPGLink.load_extensions
PokeRPGLink.log("PokeRPGLink #{PokeRPGLink::VERSION} loaded. hooks ok=#{PokeRPGLink.hooks_ok.join(',')} failed=#{PokeRPGLink.hooks_failed.join(',')}")
