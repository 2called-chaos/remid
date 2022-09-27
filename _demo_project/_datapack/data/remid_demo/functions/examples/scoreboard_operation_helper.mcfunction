# Scoreboard operation helper work as literal when standing alone and as a sugar variant in interpolations.
# The general syntax is:
#   >! OBJECTIVE SELECTOR_1 OPERATOR SELECTOR_2
#   >! OBJECTIVE_1 SELECTOR_1 OPERATOR OBJECTIVE_2 SELECTOR_2



# The literal form works by starting a line/command with a greater than symbol plus and exclamation mark(>!).
scoreboard players operation player1 rd_an_objective = player2 rd_an_objective

# If you want to copy one objective to another specify them on both sides
scoreboard players operation player1 rd_an_objective = player2 rd_another_objective

# The same namespacing rules as with the normal scoreboard helper apply
scoreboard players operation @s cc_id = $max_id cc_id

# The same operators as ingame are supported, these are
scoreboard players operation player1 rd_an_objective = player2 rd_an_objective
scoreboard players operation player1 rd_an_objective += player2 rd_an_objective
scoreboard players operation player1 rd_an_objective -= player2 rd_an_objective
scoreboard players operation player1 rd_an_objective *= player2 rd_an_objective
scoreboard players operation player1 rd_an_objective /= player2 rd_an_objective
scoreboard players operation player1 rd_an_objective %= player2 rd_an_objective
scoreboard players operation player1 rd_an_objective >< player2 rd_an_objective
scoreboard players operation player1 rd_an_objective > player2 rd_an_objective
scoreboard players operation player1 rd_an_objective < player2 rd_an_objective
