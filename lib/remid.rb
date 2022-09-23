module Remid
  #ROOT = File.expand_path("../..", __FILE__)
end

# stdlib
require "benchmark"
require "fileutils"
require "pathname"
require "json"
require "find"
require "optparse"

# 3rd party
require "pry"
require "active_support"
require "active_support/core_ext"
require "active_support/time_with_zone"
require "rainbow"
require "rainbow/refinement"

# application
require "remid/version"
require "remid/application"
require "remid/source_directory"
require "remid/context"
require "remid/function_scheduler"
require "remid/function_parser"
require "remid/objective_manager"
require "remid/objective"
require "remid/coord"
