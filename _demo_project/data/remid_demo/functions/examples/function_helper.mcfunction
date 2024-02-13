# Function helper work as literal when standing alone and as a sugar variant in interpolations.



# The literal form works by starting a line/command with a slash(/).
# When you don't specify a namespace it will expand to reference self (your namespace)
/foo/bar

# When you want to call a dependency (function from a different namespace) just specify it
/some_namespace:foo/bar



# The interpolation form works the same way just that you can use them inside a normal command.
execute as @a run #{/foo/bar}

# You can also use the function helper to schedule a function instead. If you use this way of
# scheduling functions you can also cancel all schedule functions with one call (e.g. when reloading)
/foo/bar @ 10t
execute as @a run #{/foo/bar @ 10s}

# If you want to append the schedule instead of the default replace:
/foo/bar @<< 10t
execute as @a run #{/foo/bar @<< 10s}

# You can also clear a given schedule
/foo/bar @ clear


# This also works with relative paths
/./function_in_this_folder
/../function_in_parent_folder
#{/../examples/../something/function}



# Function arguments (1.20.2+) are supported UNLESS they include an @ (and maybe other symbols)
# (note multiline and trailing comma support)
/a_function {
	"x" => 3,
	"y" => 4,
	"z" => 5,
}
# You still need to use macros correctly (in a_function:)
#   $execute as @p run say $(x)



# There is also a magic "::self" which references self (duh), including and intended for anonymous functions
> registry foo = 10
execute as @a run <<<
	> registry foo --
	summon cow

	# iterate until foo is zero
	execute
		if score foo #{> registry} matches 1..
		run #{/::self}
>>>
