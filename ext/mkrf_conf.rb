require "rubygems"
require "rubygems/command.rb"
require "rubygems/dependency_installer.rb"
begin
  Gem::Command.build_args = ARGV
  rescue NoMethodError
end
inst = Gem::DependencyInstaller.new

begin
  if Gem.win_platform?
    inst.install "wdm", ">= 0.1.0"
  end
rescue
  exit(1)
end
