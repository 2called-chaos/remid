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
