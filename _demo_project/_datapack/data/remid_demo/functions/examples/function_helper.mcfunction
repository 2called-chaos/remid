# Function helper work as literal when standing alone and as a sugar variant in interpolations.



# The literal form works by starting a line/command with a slash(/).
# When you don't specify a namespace it will expand to reference self (your namespace)
function remid_demo:foo/bar

# When you want to call a dependency (function from a different namespace) just specify it
function some_namespace:foo/bar



# The interpolation form works the same way just that you can use them inside a normal command.
execute as @a run function remid_demo:foo/bar

# You can also use the function helper to schedule a function instead. If you use this way of
# scheduling functions you can also cancel all schedule functions with one call (e.g. when reloading)
schedule function remid_demo:foo/bar 10t
execute as @a run schedule function remid_demo:foo/bar 10s

# If you want to append the schedule instead of the default replace:
schedule function remid_demo:foo/bar 10t append
execute as @a run schedule function remid_demo:foo/bar 10s append

# You can also clear a given schedule
schedule clear remid_demo:foo/bar


# This also works with relative paths
function remid_demo:examples/function_in_this_folder
function remid_demo:function_in_parent_folder
function remid_demo:examples/../something/function



# Function arguments (1.20.2+) are supported UNLESS they include an @ (and maybe other symbols)
# (note multiline and trailing comma support)
function remid_demo:a_function { "x" => 3, "y" => 4, "z" => 5 }
# You still need to use macros correctly (in a_function:)
#   $execute as @p run say $(x)



# There is also a magic "::self" which references self (duh), including and intended for anonymous functions
scoreboard players set foo rd_registry 10
execute as @a run function remid_demo:examples/function_helper/__anon_51_1
