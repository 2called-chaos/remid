# ------------
# --- Meta ---
# ------------

# description used for the pack.mcmeta (if you want to define the mcmeta yourself see options below)
$remid.meta.description     = "Remid Demo by 2called-chaos"

# REQUIRED: the namespace for your datapack
$remid.function_namespace   = "remid_demo"

# OPTIONAL: the pseudo-namespace used for scoreboard objectives
# If not defined will use the same as function_namespace
$remid.scoreboard_namespace = "rd"


# Define which functions to run on load/tick.
# By default, if exist, "load" will be called on load
#                   and "tick" will be called on tick
$remid.on_load << :load_something_else_as_well
$remid.on_tick = :use_a_different_tick_function
$remid.on_tick = [:use_multiple, :different_tick_functions]
$remid.on_tick = false # use no tick function even if a function named "tick" exists
$remid.on_tick = :__remid_auto # return to default behavior


# --- anything below is optional and showcases all the possible things



# -----------------------
# --- Project Options ---
# -----------------------

# JSON files will be validated and rewritten.
# Define if you want the output to be pretty (multiline) or minified
# (default: true)
$remid.opts.pretty_json = true

# Whether to generate a pack.mcmeta or use your own.
# Put top level files (like custom pack.mcmeta or a pack.png) into the data directory.
# (default: true)
$remid.opts.mcmeta = true

# Whether to apply comma autofix (experimental)
# Will basically only remove trailing commas before } and ]
# Will remove no matter the context so don't use it if you plan on using ,] or ,} in strings for some reason
# (default: false)
$remid.opts.autofix_trailing_commas = true

# To suppress replacement logging:
$remid.opts.autofix_trailing_commas = :silent



# ---------------
# --- Imports ---
# ---------------
# "imports" or less verbose access to features
$scores = $remid.objectives
$schedule = $remid.scheduler



# ------------------
# --- Objectives ---
# ------------------
# Define your objectives here to later use create_all or destroy_all without the need to maintain two lists
$scores.add :registry
$scores.add :sneak, "minecraft.custom:minecraft.sneak_time"
$scores.add :foo, name: "FOO", display: :sidebar, render: :hearts



# ------------
# --- Tags ---
# ------------
# Optional alternative way to generate tag JSON for entities/blocks/functions
$remid.tag.entities :boats, %w[boat chest_boat]
$remid.tag.blocks :all_water, %w[water bubble_column]
$remid.tag.functions :foo, %w[bar :baz foobar:barbaz]

# by default values will bejj prefixed with "minecraft:" for entities and blocks and your function prefix for functions
# use ":name" to prefix with your function prefix,
# use "prefix:name" to manually prefix or
# use the prefix option to change the default prefix (use the prefix :_ to use your function prefix)
# by default replace is false but you can pass that option if needed
$remid.tag.entities :foo, %w[whatever :boats dependency:something], prefix: :something, replace: true

# If you need or want to progressively add more to an existing tag:
# (note that a changed prefix option while creating the tag will not affect the following)
$remid.tag.entities[:boats] << :another_one
$remid.tag.entities[:boats].values # line above is sugar to append to this array, feel free to do array things with it :)
$remid.tag.entities[:boats].replace = true # you can set this option here as well



# -----------------
# --- Variables ---
# -----------------
# Define variables and use them later
$center = Coord.new(123, 123, 123) # ground level center point



# -------------------------
# --- Stubbed functions ---
# -------------------------
# Basically a helper. The same as creating a mcfunction with the same name.
# Could be used to inherit functions on a Ruby level.
$remid.stub :load, %q{
  #~~ $scores.registry.create
  execute unless score $z_initialized #{> registry} matches 1 run #{/init}
  say Remid Demo ready
}

# Can accept an array of functions.
# When missing a namespace the function namespace will be prefixed.
# Virtually the same as minecraft function tags.
$remid.stub :reload, ["kill", "init"]
$remid.stub :foo, ["bar:one", "bar:two"]
