# If you have created your objectives within your remid.rb you can now do this:

# create all objectives
scoreboard objectives modify rd_foo rendertype hearts
scoreboard objectives setdisplay sidebar rd_foo
scoreboard objectives add rd_foo dummy "FOO"
scoreboard objectives add rd_sneak minecraft.custom:minecraft.sneak_time
scoreboard objectives add rd_registry dummy

# destroy all objectives
scoreboard objectives remove rd_foo
scoreboard objectives remove rd_sneak
scoreboard objectives remove rd_registry

# create or destroy specific objective
scoreboard objectives add rd_registry dummy
scoreboard objectives remove rd_registry




# If you use the function helper to schedule all your functions then you can do this:
# cancel all functions (scheduled via @ helper) for this namespace
actually schedule clear remid_demo:foo/bar

# If you don't know or don't want to use the helper everywhere you can brute-force
# cancel all functions (scheduled or not) for this namespace
schedule clear remid_demo:load
schedule clear remid_demo:reload
schedule clear remid_demo:foo
schedule clear remid_demo:examples/anonymous_functions_and_ral
schedule clear remid_demo:examples/eval
schedule clear remid_demo:examples/frameworkish_stuff
schedule clear remid_demo:examples/function_helper
schedule clear remid_demo:examples/general_syntax_stuff
schedule clear remid_demo:examples/interpolation
schedule clear remid_demo:examples/ruby_classes/coord
schedule clear remid_demo:examples/scoreboard_helper
schedule clear remid_demo:examples/scoreboard_operation_helper
schedule clear remid_demo:examples

