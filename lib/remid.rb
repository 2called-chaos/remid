module Remid
  #ROOT = File.expand_path("../..", __FILE__)
end

module Kernel
  def load_relative *paths
    dir = Pathname.new(caller.first).dirname
    paths.each do |path|
      xpath = dir.join(path)
      if FileTest.file?("#{xpath}.rb")
        load dir.join("#{xpath}.rb")
      else
        load dir.join(xpath)
      end
    end
    true
  end
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
require "remid/types"
require "remid/application"
require "remid/source_directory"
require "remid/context"
require "remid/function_scheduler"
require "remid/function_parser"
require "remid/tag_manager"
require "remid/objective_manager"
require "remid/objective"
require "remid/advancement_manager"
require "remid/advancement"
require "remid/sound"
require "remid/team_manager"
require "remid/team"
require "remid/json_helper"
require "remid/json_storage_context"

require "remid/entity"
require "remid/coord"
require "remid/cardinal_direction"
require "remid/written_book"
require "remid/function_book"
require "remid/hotbar_controller"
require "remid/resource_pack"
require "remid/string_collection"
