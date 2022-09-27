# REMID provides several helper classes on the Ruby side.

# In this example we will use the eval syntax to define these objects
# but generally you want to place this into your remid.rb or something
# it loads like a dedicated datapack settings file.



# ------------------
# --- Coordinate ---
# ------------------
# "Coord" is a class to represent a 3d vector(x,y,z)


# coordinates will automatically coerce to a string representation
setblock 0 10 20 air

# get a relative position from a coordinate
setblock 0 0 0 air

# you may also pass named parameters instead
# (either 3 arguments(x,y,z) or up to 3 named parameters
# will work for any following example too)
setblock 0 20 10 air

# at does the same as rel except it works with absolute values
setblock 0 10 -1337 air

# these are chainable of course
setblock 1337 20 20 air

# move does the same as rel but also affects the original coordinate
setblock 0 20 20 air
setblock 0 30 20 air
setblock 0 40 20 air

# set does the same as move but works with absolute values
setblock 0 10 20 air

# you can work with the original coordinate
setblock 0 10 20 air

# or straight up reset it
setblock 0 10 20 air

# or maybe just reset specific axis
setblock 0 110 20 air


# using set! or move! will also modify the original position
setblock 0 10 20 air
setblock 0 1000 20 air
setblock 0 1000 1020 air
setblock 0 1000 1020 air


# you can duplicate a coordinate

# if you want to retain the original position as well


# delta gives you the delta of the current position to the
# original position or a given other coordinate.
say 123 11 321



# this way you could do something like this (advanced)

setblock 0 0 0
setblock 10 0 0
setblock 20 0 0
setblock 30 0 0
setblock 40 0 0
setblock 50 0 0
setblock 60 0 0
setblock 70 0 0
setblock 80 0 0
setblock 90 0 0
setblock 100 0 0
