class CommandBook < Remid::WrittenBook
  # Use a String or a Proc, procs will be evaluated on render (e.g. for variables)
  title "Command Book"
  author { "Mysterious Person" }

  # Name and Lore support JSON so the same as with pages
  # name { puts "Command Book".red }
  # lore { puts "It contains secrets!".yellow }
  # But if you don't need JSON you can also just pass strings
  # name "My name"
  # lore "My lore"

  # defaults to all pages in the order they are defined, overwrite to return an array of page names.
  def pages
    super - [:cheat_sheet]
  end

  page :cheat_sheet do
    # To write to the page use the puts and print methods. You can access the
    # page buffer with the __page variable if you need to.
    # Strings are refined with a bunch of styling methods.
    # Please also look at the other pages which showcase a more realistic book page.

    # These refined string methods return a presented object which will coerce
    # to a JSON structure. For this reason it is not advised to interpolate these
    # unless you know what you are doing.
    # You can however add two presented strings together with addition.
    puts "Hello".bold + " World".italic
    # If you start with a string literal call reset or wrap on it first.
    #puts "Hello"      + " World".italic # <--- Not good
    puts "Hello".wrap + " World".italic # <--- This Is The Way!
    # It only matters when you start with it!
    puts "Hello".bold + " World" + "!".italic

    # Since this isn't exactly readable I prefer to write a block for each line
    print "Hello".bold
    print " World".italic
    print "!".underline
    puts # next line

    print "[".bold
    print "#{"status"}".underline
    print "]".bold
    puts

    # But what can we do?
    puts "Standard formatting".bold.underline.italic.obfuscated.strikethrough
    puts "Font".font("asset_namespace:font_name")

    # Colors
    puts "black".black               or "black".color(:black)
    puts "dark_blue".dark_blue       or "dark_blue".color(:dark_blue)
    puts "dark_green".dark_green     or "dark_green".color(:dark_green)
    puts "dark_aqua".dark_aqua       or "dark_aqua".color(:dark_aqua)
    puts "dark_red".dark_red         or "dark_red".color(:dark_red)
    puts "dark_purple".dark_purple   or "dark_purple".color(:dark_purple)
    puts "gold".gold                 or "gold".color(:gold)
    puts "gray".gray                 or "gray".color(:gray)
    puts "dark_gray".dark_gray       or "dark_gray".color(:dark_gray)
    puts "blue".blue                 or "blue".color(:blue)
    puts "green".green               or "green".color(:green)
    puts "aqua".aqua                 or "aqua".color(:aqua)
    puts "red".red                   or "red".color(:red)
    puts "light_purple".light_purple or "light_purple".color(:light_purple)
    puts "yellow".yellow             or "yellow".color(:yellow)
    puts "white".white               or "white".color(:white)
    # Reset only works with the color method since reset does more than that
    puts "reset".color(:reset)
    puts "DO NOT".reset # this resets everything, not just the color
    # And custom colors ofc
    puts "custom color".color("#b00b69")

    # Click Event
    puts "Click Event: Run Command".click("kill") # vanilla command (don't prefix with slash)
    puts "Click Event: Run Command".click("/a/function") # / expands to function call, automatic namespacing
    puts "Click Event: Run Command".click("/a:scoped/function")
    puts "Click Event: URL".click(url: "https://...")
    puts "Click Event: Change Page".click(page: :page_2) # named pages, you could use indices but why?
    puts "Click Event: Copy to Clipboard".click(copy: ":-P")

    # Not that this does not work in books but in other JSON contexts
    # and this is supposed to be a cheatsheet :)
    puts "Click Event: Suggest Command".click(suggest: "/kill")

    # Hover Event
    puts "Hover Event: Text".hover("hi")
    puts "Hover Event: Text".hover("Hello".bold + " World".italic)
    puts "Hover Event: Item".hover(item: "dirt_block") # defaults to minecraft namespace
    puts "Hover Event: Item".hover(item: "namespaced:dirt_block")
    puts "Hover Event: Item".hover(item: { id: "dirt_block", count: 13 }) # @todo item tag option
    # puts "Hover Event: Entity".hover(entity: ) # @todo entity support

    # @todo translated text
    # @todo scoreboard value
    # @todo entity names
    # @todo keybind
    # @todo nbt-values

    # You can define methods, scope wise they get defined on this page only.
    def a_method arg1
      arg1.reverse
      # But you can also call methods from your book
      #book.some_method
    end
    puts a_method("Hello World")

    # You can modify the global state and all subsequent additions will inherit from that.
    bold.underline
    color(:red)

    puts "this is all red, underlined"
    puts "and bold until we either"
    bold(false).underline(false).color(nil)
    puts "or"
    reset(:bold, :underline, :color)
    puts "or"
    reset


    # We can also successively create scopes that inherit from each other
    scope do
      color(:green)
      puts "this is green"
      scope do
        bold
        puts "this is green and bold and underlined".underline
      end
      puts "this is just green again"
    end


    # If you want to use unsupported JSON you can add it manually
    # to the hash that gets converted to JSON.
    puts "Hey".underline.merged(color: :yellow)

    # Or directly append raw JSON
    __page << { text: "raw" }.to_json
  end

  page :short_test do
    bold
    puts "lol".red.underline
    scope do
      obfuscated
      puts "lol"
    end
    reset
    puts "lol"
  end
end


#/give @p written_book{pages:['{"text":"Minecraft Tools adawbook\\n\\nwadawdddd\\nd\\na\\na\\n\\na\\na\\na\\na\\n\\na\\na\\n\\na\\na\\na\\na\\n\\na\\na\\n\\na\\na\\na\\n\\na\\na\\na"}'],title:Book,author:"http://minecraft.tools/",generation:1,display:{Lore:["desc"]}}
