module Remid
  class HotbarController
    attr_reader :default, :menu

    def self.mount fnspace
      new(fnspace).mount!
    end

    def initialize fnspace = nil
      @fnspace = fnspace
      @scope = fnspace || self.class.to_s.split("::").last.underscore
      @default = SlotGroup.new(self, default_group: true)
      @menus = {}
      @main_menu = :menu_main
      init if respond_to?(:init)

      methods.grep(/^menu_/).each do |meth|
        @menus[meth] = SlotGroup.new(self)
        begin
          @menu = @menus[meth]
          send(meth)
        ensure
          @menu = nil
        end
      end
    end

    def main which
      @main_menu = :"menu_#{which}"
    end

    def item &block
      @menu.slot(&block)
    end

    def mount!
      $remid.stub "#{@scope}/enter", %{
        execute as @s[tag=!hbc.in.#{@scope}] run <<<
        \t# @todo store inventory
        \tsay todo: store your inventory
        \tclear @s
        \ttag @s add hbc.in.#{@scope}
        \t/./#{@main_menu}/enter
        >>>
      }

      $remid.stub "#{@scope}/leave" do |f|
        f << "execute as @s[tag=hbc.in.#{@scope}] run <<<"
        f << "\t# @todo restore inventory"
        f << "\tsay todo: restore your inventory"
        f << "\tclear @s"
        f << "\ttag @s remove hbc.in.#{@scope}"
        @menus.each do |mname, mobj|
          f << "\ttag @s remove hbc.#{@scope}.#{mname}"
        end
        f << "\titem replace entity @s hotbar.0 with minecraft:stick"
        f << "\titem replace entity @s hotbar.1 with minecraft:wooden_axe"
        f << ">>>"
      end

      ticks = []
      @menus.each do |mname, mobj|
        ticks << "execute if entity @a[tag=hbc.#{@scope}.#{mname}] run \#{/./#{mname}/tick}"

        $remid.stub "#{@scope}/#{mname}/enter" do |f|
          f << "execute as @s[tag=hbc.in.#{@scope},tag=!hbc.#{@scope}.#{mname}] run <<<"
          f << "\ttag @s add hbc.#{@scope}.#{mname}"
          f << "\tclear @s"
          mobj.each_with_index do |slot, si|
            next unless slot
            f << "\t/./#{si}_#{slot.safe_name}/give"
          end
          f << ">>>"
        end

        $remid.stub "#{@scope}/#{mname}/leave", %{
          execute as @s[tag=hbc.in.#{@scope},tag=hbc.#{@scope}.#{mname}] run tag @s remove hbc.#{@scope}.#{mname}
        }

        $remid.stub "#{@scope}/#{mname}/tick" do |f|
          mobj.each_with_index do |slot, si|
            next unless slot
            f << "\t/./#{si}_#{slot.safe_name}/tick"
          end
        end

        mobj.each_with_index do |slot, si|
          next unless slot
          $remid.stub("#{@scope}/#{mname}/#{si}_#{slot.safe_name}/give") {|f| slot.to_give_function(f, "hbc.item.#{@scope}.#{mname}", si) }
          $remid.stub("#{@scope}/#{mname}/#{si}_#{slot.safe_name}/tick") {|f| slot.to_tick_function(f, "hbc.item.#{@scope}.#{mname}", si) }
        end
      end

      $remid.stub "#{@scope}/tick", ticks.join("\n")

      self
    end

    def tick!
      $remid.buf << "function #{$remid.function_namespace}:#{@scope}/tick"
    end

    def kill
      $remid.buf << "execute as @a[tag=hbc.in.#{@scope}] run function #{$remid.function_namespace}:#{@scope}/leave"
    end

    def to_s
      [].tap do |r|
        @menus.each do |mname, menu|
          r << "#{mname}"
          menu.each_with_index do |slot, si|
            r << "\t#{si}\t#{slot&.name} \t#{slot&.action}"
          end
        end
      end.join("\n")
    end

    class SlotGroup
      def initialize(controller, num = 9, default_group: false)
        @is_default_group = default_group
        @controller = controller
        @group = []
        @controller.default&.each_with_index do |value, slot|
          self[slot].instance_eval(&value) if value
        end
      end

      [:each, :each_with_index, :map].each do |meth|
        define_method(meth) do |*a, **kw, &b|
          @group.send(meth, *a, **kw, &b)
        end
      end

      def [] index, &block
        if block
          if @is_default_group
            @group[index] = block
          else
            self[index].instance_eval(&block)
          end
        elsif index
          @group[index] ||= slot
        else
          raise "no index provided"
        end
      end

      def slot &block
        Slot.new(@controller, self).setup(&block)
      end

      def << item
        if @group.include?(nil)
          @group[@group.index(nil)] = item
        else
          @group << item
        end
        self
      end
    end

    class Slot
      attr_writer :name
      attr_reader :action

      def initialize(controller, group)
        @controller = controller
        @group = group
        @name = JsonHelper::PresentedMinecraftString.wrap("unnamed")
        reset
      end

      def setup &block
        instance_eval(&block) if block
        self
      end

      def reset
        @action = { as_player: {} }
        self
      end

      def name *args
        if args.any?
          @name = JsonHelper::PresentedMinecraftString.wrap(args.first)
          self
        else
          @name
        end
      end

      def lore *args
        if args.any?
          if args.first
            @lore = JsonHelper::PresentedMinecraftString.wrap(args.first)
          else
            @lore = args.first
          end
          self
        else
          @lore
        end
      end

      def safe_name
        @name.to_plain.parameterize.gsub(/[^0-9a-z\-_\+]/i, "")
      end

      def as_player yesno = true
        @action[:__context] = yesno ? :player : :entity
        self
      end

      def as_entity yesno = true
        @action[:__context] = yesno ? :entity : :player
        self
      end

      [:execute, :run, :enchant, :model, :enter, :leave, :regive].each do |meth|
        define_method(meth) do |*args|
          args << true if args.empty? && %i[enchant leave regive as_player].include?(meth)
          if %i[execute run].include?(meth) && @action[:__context] == :player
            @action[:as_player][meth] = args.first
          else
            @action[meth] = args.first
          end
          self
        end
      end

      def to_give_function f, scope, index
        f << "item replace entity @s hotbar.#{index} with snowball{"
        f << "\tTags: [\"#{scope}.#{index}_#{safe_name}\"],"
        f << "\tdisplay: {"
        f << "\t\tName: '#{name.to_s}',"
        f << "\t\tLore: ['#{lore}']" if lore
        f << "\t},"
        f << "\tEnchantments: [{}]," if @action[:enchant]
        if model = @action[:model]
          if model.is_a?(Symbol)
            lookup = @controller.class::MODELS
            model = lookup.is_a?(Array) ? lookup.index(model) + 1 : lookup[model]
          end
          f << "\tCustomModelData: #{model || 0},"
        end
        f << "}"
      end

      def to_tick_function f, scope, index
        f << "execute as @e[type=snowball,nbt={Item:{tag:{Tags:[\"#{scope}.#{index}_#{safe_name}\"]}}}] at @s run <<<"
        if @action[:as_player].any? || @action[:regive] || @action[:enter] || @action[:leave]
          f << "\texecute as @p at @s run <<<"
          f << "\t\texecute as @p[gamemode=!creative] run \#{/./give}" if @action[:regive]

          if @action[:enter]
            f << "\t\t/../leave"
            f << "\t\t/../../menu_#{@action[:enter]}/enter"
          end

          if @action[:leave]
            f << "\t\t/../leave"
            f << "\t\t/../../leave"
          end

          if @action[:as_player][:run]
            f << "\t\t/#{@action[:as_player][:run]}"
          end

          if @action[:as_player][:execute]
            $remid.__deindent_by_first_line(@action[:as_player][:execute]).split("\n").each do |line|
              f << "\t\t#{line}"
            end
          end
          f << "\t>>>"
        end

        if @action[:run]
          f << "\t/#{@action[:run]}"
        end

        if @action[:execute]
          $remid.__deindent_by_first_line(@action[:execute]).split("\n").each do |line|
            f << "\t#{line}"
          end
        end

        f << "\tkill @s"
        f << ">>>"
      end
    end
  end
end
