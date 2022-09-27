# If you have created your objectives within your remid.rb you can now do this:

# create all objectives
#~~ $scores.create_all

# destroy all objectives
#~~ $scores.destroy_all

# create or destroy specific objective
#~~ $scores.registry.create
#~~ $scores.registry.destroy




# If you use the function helper to schedule all your functions then you can do this:
# cancel all functions (scheduled via @ helper) for this namespace
#~~ $schedule.cancel_all

# If you don't know or don't want to use the helper everywhere you can brute-force
# cancel all functions (scheduled or not) for this namespace
#~~ $schedule.cancel_all(:functions)

