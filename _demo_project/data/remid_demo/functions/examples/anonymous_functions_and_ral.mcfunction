# Anonymous functions are primarily to workaround some read- and workability issues with vanilla
# especially when caring about performance.


# Imagine you want to execute 3 commands in a given environment. For performance reasons (as to
# not reevaluate selectors multiple times) it is advised to move these 3 commands into a function.
#
# But this easily makes it hard to follow what is going on. Now figure this:
execute as @e[tag=expensive_selector] at @s run <<<
	say one
	say two
	say three
>>>
# This will automatically create an unnamed function (well technically it has a name but you know)
# and directly references it as function call.


# You can also nest this and do all sort of things, a more complicated example
execute as @e[tag=expensive_selector] at @s run <<<
	say one
	execute as @s[tag=subselection] run <<<
		say one-a
		say one-b
		say one-c
	>>>
	summon cow ~ ~ ~
	{
		Tags: [ foo ]
	}
	say three
>>>


# Scheduling anonymous functions is not yet sugar-ified. You can do it like this but the scheduler won't know
# that this function has been scheduled (when you use cancel_all, see frameworkish_stuff).
# If you have an idea for a syntax for this let me know, I thought about ending with ">>> @ 10t" like
# the function helper works but I'm not convinced yet.
execute as @s run schedule <<<
	say one second later
>>>
	1s




# RAL (Repeat A Line™) is basically the same as an anonymous function except it actually just repeats
# the previous line. So less repetition, no performance gain. Fortunately you just need to add 2 characters
# to make it an anonymous function. But this can be used for different scenarios, like:
say [Some Prefix] <<
	hello there
	please leave a like
>>
