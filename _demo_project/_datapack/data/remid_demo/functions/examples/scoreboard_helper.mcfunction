# Scoreboard helper work as literal when standing alone and as a sugar variant in interpolations.
# The general syntax is:
#   > OBJECTIVE SELECTOR OPERATOR [VALUE]
#   > OBJECTIVE SELECTOR OPERATION
#   > OBJECTIVE SELECTOR
#   > OBJECTIVE


# The literal form works by starting a line/command with a greater than symbol(>).
scoreboard players set @a rd_an_objective 1

# Objective names will be prefixed with your scoreboard prefix (or function namespace if not defined).
# If you don't want that (because you want to specify a non or differently namespaced objective) prefix the
# objective with a slash
scoreboard players set @a cc_id 1

# The scoreboard helper supports the following operators
scoreboard players set @a rd_an_objective 1
scoreboard players add @a rd_an_objective 2
scoreboard players remove @a rd_an_objective 3

# The scoreboard helper supports the following operations
scoreboard players add @a rd_an_objective 1
scoreboard players remove @a rd_an_objective 1
scoreboard players reset @a rd_an_objective
scoreboard players enable @a rd_an_objective

# providing just an objective and a selector translates to a "scoreboard players get" command
# but still adhering to namespaceing rules.
scoreboard players get @s rd_an_objective

# providing just the objective resolves the objective name according to the namespacing rules
execute if score @s rd_registry run say hi
execute as @s[scores={ rd_registry = 1..2, rd_whatever = 1.. }] run say hi
