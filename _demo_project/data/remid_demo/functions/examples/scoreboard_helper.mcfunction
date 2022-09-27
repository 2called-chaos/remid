# Scoreboard helper work as literal when standing alone and as a sugar variant in interpolations.
# The general syntax is:
#   > OBJECTIVE SELECTOR OPERATOR [VALUE]
#   > OBJECTIVE SELECTOR OPERATION
#   > OBJECTIVE SELECTOR
#   > OBJECTIVE


# The literal form works by starting a line/command with a greater than symbol(>).
> an_objective @a = 1

# Objective names will be prefixed with your scoreboard prefix (or function namespace if not defined).
# If you don't want that (because you want to specify a non or differently namespaced objective) prefix the
# objective with a slash
> /cc_id @a = 1

# The scoreboard helper supports the following operators
> an_objective @a = 1
> an_objective @a += 2
> an_objective @a -= 3

# The scoreboard helper supports the following operations
> an_objective @a ++
> an_objective @a --
> an_objective @a reset
> an_objective @a enable

# providing just an objective and a selector translates to a "scoreboard players get" command
# but still adhering to namespaceing rules.
> an_objective @s

# providing just the objective resolves the objective name according to the namespacing rules
execute if score @s #{> registry} matches 1 run say hi
execute
	as @s[scores={
		#{>registry} = 1..2,
		#{> whatever} = 1..,
		# note that the trailing command in the line above is only resulting in a valid command with `$remid.opts.autofix_trailing_commas` being enabled in remid.rb
	}]
	run say hi
