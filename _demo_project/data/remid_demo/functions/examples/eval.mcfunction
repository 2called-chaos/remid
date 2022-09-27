# Eval is evil! This is why we have not one, not two but many ways to do it :)


# The most crucial one is the eval that happens in interpolations, see interpolations for more info.
# This is just one example
execute run #{("a".."z").to_a.rotate(-10).join}

# Another way for single line evals (to set or manipulate variables for example)
#~~ "hey" + "this is ruby"
#~~ $coord = Coord.new(0, 0, 0)



# Now wouldn't it be nice to use the magic of Ruby blocks somehow?
# Well you can! Because I suck at writing parsers the syntax is like that, mkay?
#~[ 3.times do |x|
	#~[ 3.times do |y|
		setblock #{$coord.rel(x: x, y: y)} dirt
	#~] end
#~] end



# If you know Ruby you might have the idea to use procs but that won't work,
# but using the capture helper absolutely does! With arguments and everything!

# create a meta-function of sorts
#~[ $a_cow = capture do |x, y, z, tag: :untagged|
	summon cow #{x} #{y} #{z}
	{
		Tags: [#{tag}]
	}
#~] end

# And call it
#~~ $a_cow.call(1, 2, 3)
execute run #{$a_cow.call(4, 5, 6, tag: :delicious)}
#~~ $a_cow.call(*$coord.to_a, tag: :delicious)



# If you want to embed some Ruby without restraints (scoping) you can use the following syntax.
__BEGIN__

# This is completely Ruby eval'd all at once.
# That means that we have proper local_variable and scoping support.

# Note that you have access to a variable `out` in the top scope which is the output buffer
# for the resulting mcfunction. You can use, add to or otherwise manipulate the array.

class MyRandomHelperThatShouldntBeHere
  def initialize wildness: 10
    @wildness = wildness
  end

  def do_something_wild out
    @wildness.times do |i|
      # despite scoping we have an out here
      out << "say this is wild times #{i}"
    end
  end
end

my_local_var = MyRandomHelperThatShouldntBeHere.new(wildness: 20)
my_local_var.do_something_wild(out)

puts "Hello from the eval example, don't be evil!"
puts "The last output line is #{out.last}"
out.last << " (really boring)"
out.last.gsub!(/boring/, "wild")
puts "The last output line is now #{out.last}"
__END__
