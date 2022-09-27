require "rubygems"
require "rubygems/command.rb"
require "rubygems/dependency_installer.rb"
begin
  Gem::Command.build_args = ARGV
  rescue NoMethodError
end
inst = Gem::DependencyInstaller.new

begin
  # enable listen gem to actually listen instead of polling (on Windows)
  if Gem.win_platform?
    inst.install "wdm", ">= 0.1.0"
  end

  # @todo macos needs another gem I think
rescue
  exit(1)
end
