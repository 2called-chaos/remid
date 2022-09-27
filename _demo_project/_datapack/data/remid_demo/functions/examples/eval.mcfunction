# Eval is evil! This is why we have not one, not two but many ways to do it :)


# The most crucial one is the eval that happens in interpolations, see interpolations for more info.
# This is just one example
execute run qrstuvwxyzabcdefghijklmnop

# Another way for single line evals (to set or manipulate variables for example)



# Now wouldn't it be nice to use the magic of Ruby blocks somehow?
# Well you can! Because I suck at writing parsers the syntax is like that, mkay?
setblock 0 0 0 dirt
setblock 0 1 0 dirt
setblock 0 2 0 dirt
setblock 1 0 0 dirt
setblock 1 1 0 dirt
setblock 1 2 0 dirt
setblock 2 0 0 dirt
setblock 2 1 0 dirt
setblock 2 2 0 dirt



# If you know Ruby you might have the idea to use procs but that won't work,
# but using the capture helper absolutely does! With arguments and everything!

# create a meta-function of sorts

# And call it
summon cow 1 2 3 { Tags: [untagged] }
summon cow 4 5 6 { Tags: [delicious] }
execute run summon cow 4 5 6 { Tags: [delicious] }
summon cow 0 0 0 { Tags: [delicious] }



# If you want to embed some Ruby without restraints (scoping) you can use the following syntax.
say this is wild times 0
say this is wild times 1
say this is wild times 2
say this is wild times 3
say this is wild times 4
say this is wild times 5
say this is wild times 6
say this is wild times 7
say this is wild times 8
say this is wild times 9
say this is wild times 10
say this is wild times 11
say this is wild times 12
say this is wild times 13
say this is wild times 14
say this is wild times 15
say this is wild times 16
say this is wild times 17
say this is wild times 18
say this is wild times 19 (really wild)
