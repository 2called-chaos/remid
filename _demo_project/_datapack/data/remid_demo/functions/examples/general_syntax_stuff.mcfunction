# If you want to stay vanilla but only want a more readable file you can
# use REMID for just the multi-line command support.

# That is you can split commands onto multiple lines by indentation.
# All those lines will be joined by spaces.
execute as @e[tag=whatever] if block ~ ~ ~ air run function remid_demo:a/function

# There is one exception to this, you may put [] and {} on the same indentation as the "main" thing
summon cow ~ ~ ~ { Tags: [delicious] }


# Also you can have inline comments this way
execute as @a[tag=some_unreadable_selector] at @s if block ~ ~ ~ air run summon cow ~ ~ ~ { Tags: [delicious], Invulnerable: 1 }
