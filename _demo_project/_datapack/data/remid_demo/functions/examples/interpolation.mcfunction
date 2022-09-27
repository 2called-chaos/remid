# Interpolation - the insertion of something of a different nature into something else

# With REMID this happens with a pound followed by a pair of curly braces, like this: #{}
# This does not work in comments BUT a "command" directly starting with #{ will be interpolated!
# It is good practice to always have a space after the pound symbol/hashtag to prevent accidents :)

# {"say"} this is a comment
#so is this
say but this is not a comment


# Inside the curly braces you are in a Ruby context UNLESS the first symbol(s) trigger a syntax sugar behavior.
# For examples look at the function and scoreboard helper examples. Here's an example:
execute as @a run function remid_demo:some/function


# The power of interpolation will become all the more apparent the more you look into the other examples.
# But for this demonstration let's define a coordinate and summon a few entities...
summon cow 110 110 110
summon cow 120 120 120
summon cow 130 130 130
