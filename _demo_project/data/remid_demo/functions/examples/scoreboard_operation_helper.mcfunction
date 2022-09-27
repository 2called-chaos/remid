# Scoreboard operation helper work as literal when standing alone and as a sugar variant in interpolations.
# The general syntax is:
#   >! OBJECTIVE SELECTOR_1 OPERATOR SELECTOR_2
#   >! OBJECTIVE_1 SELECTOR_1 OPERATOR OBJECTIVE_2 SELECTOR_2



# The literal form works by starting a line/command with a greater than symbol plus and exclamation mark(>!).
>! an_objective player1 = player2

# If you want to copy one objective to another specify them on both sides
>! an_objective player1 = another_objective player2

# The same namespacing rules as with the normal scoreboard helper apply
>! /cc_id @s = $max_id

# The same operators as ingame are supported, these are
>! an_objective player1  = player2
>! an_objective player1 += player2
>! an_objective player1 -= player2
>! an_objective player1 *= player2
>! an_objective player1 /= player2
>! an_objective player1 %= player2
>! an_objective player1 >< player2
>! an_objective player1 >  player2
>! an_objective player1 <  player2
