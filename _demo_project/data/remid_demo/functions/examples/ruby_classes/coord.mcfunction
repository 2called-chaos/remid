# REMID provides several helper classes on the Ruby side.

# In this example we will use the eval syntax to define these objects
# but generally you want to place this into your remid.rb or something
# it loads like a dedicated datapack settings file.



# ------------------
# --- Coordinate ---
# ------------------
# "Coord" is a class to represent a 3d vector(x,y,z)

#~~ $a_position = Coord.new(0, 10, 20)

# coordinates will automatically coerce to a string representation
setblock #{$a_position} air

# get a relative position from a coordinate
setblock #{$a_position.rel(0, -10, -20)} air

# you may also pass named parameters instead
# (either 3 arguments(x,y,z) or up to 3 named parameters
# will work for any following example too)
setblock #{$a_position.rel(y: 10, z: -10)} air

# at does the same as rel except it works with absolute values
setblock #{$a_position.at(z: -1337)} air

# these are chainable of course
setblock #{$a_position.rel(y: 10).at(x: 1337)} air

# move does the same as rel but also affects the original coordinate
setblock #{$a_position.move(y: 10)} air
setblock #{$a_position.move(y: 10)} air
setblock #{$a_position.move(y: 10)} air

# set does the same as move but works with absolute values
setblock #{$a_position.set(y: 10)} air

# you can work with the original coordinate
setblock #{$a_position.original_position} air

# or straight up reset it
setblock #{$a_position.reset} air

# or maybe just reset specific axis
setblock #{$a_position.move(100, 100, 100).reset(:x, :z)} air


# using set! or move! will also modify the original position
setblock #{$a_position.reset} air
setblock #{$a_position.set!(y: 1000)} air
setblock #{$a_position.move!(z: 1000)} air
setblock #{$a_position.reset} air


# you can duplicate a coordinate
#~~ $another_position = $a_position.dupe

# if you want to retain the original position as well
#~~ $another_position_with_original = $a_position.dupe!


# delta gives you the delta of the current position to the
# original position or a given other coordinate.
say #{$a_position.set!(10, 10, 10).move(123, 11, 321).delta}



# this way you could do something like this (advanced)
#~~ $center = Coord.new(0, 0, 0)
#~~ $radius = 100
#~~ $step = 10

#~~ $center.set(x: -$step)
#~[ while $center.delta.x < $radius
	setblock #{$center.move(x: $step)}
#~] end
