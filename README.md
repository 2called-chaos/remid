# REMID - **R**uby **E**nhanced **Mi**necraft **D**atapacks

**Datapacks but with a bit less old pain and a bit new fresh pain**

REMID is a "transpiler" or more like a Frankenstein monster of a code generator for mcfunction code / datapacks. It ~~enriches your experience~~ makes you confused by 

* providing some framework-ish features around datapacks and its elements (like an entity helper)
* extending the mcfunction syntax
  * multi-line commands
  * syntax sugar and generic helpers
  * some "compilation" warnings such as referencing undefined functions or objectives (given that you use the helpers)
  * interpolation with the Ruby interpreter
  * anonymous functions & "repeat-a-line"™
  * captured ruby block evaluation
  * ...and more

and creates a vanilla datapack out of all that. REMID should be 100% vanilla compatible so you can start using it any time you want and incrementally use any feature you desire.

---

## Disclaimer

Don't look at the code. Seriously, if you love Ruby or programming in general, just don't do it :D

It will physically hurt. **You have been warned!**



## Installation

REMID is supposed to be a Ruby gem but it will not be released as one until somewhat stable and tested. The following describes how I get my development setup:

* Make sure Ruby 2.7 or higher is installed
* Clone (or extract the zip of) the repository
* in a terminal cd into the cloned directory and run `bundle install`

You need to either add the bin directory to your PATH or use absolute/relative paths to invoke the remid.cmd executable. This won't be necessary once it's installed as a gem.

## Usage

REMID is a command line interface tool. But to get any use out of it you first need to create a project. To do that create the following directory/file structure anywhere you like (note that "MY_PROJECT_NAME" and "MY_NAMESPACE" can be the same but don't have to be):

    MY_PROJECT_NAME/
                   /data/MY_NAMESPACE/
                   /remid.rb

If you are **migrating with an existing datapack** the existing data folder you have becomes the new data folder in the project. Move your pack.mcmeta (and pack.png) also into that directory. So that it basically looks like this: 

    MY_PROJECT_NAME/
                   /data/minecraft/tags/...
                   /data/MY_NAMESPACE/functions/...
                   /data/pack.mcmeta
                   /remid.rb

Edit the file `remid.rb` and add the only required thing (replace the namespace with yours):

```ruby
$remid.function_namespace = "MY_NAMESPACE"
```

You can now use REMID with this project folder. The compiled datapack will be written to `./_datapack`. See Docs for more remid.rb options and what you can now do within mcfunction files.

This is the interface:

    Usage: remid [options] <SRC_DIR>

        -h, --help                       Shows this help
        -c, --copy DST                   Copy datapack to a directory after compile
                                         e.g. into a world save
        -s, --success SCRIPT             Run this script after successful compilations
        -f, --failure SCRIPT             Run this script after failed compilations
        -w, --watch                      Autocompile on changes in data source directory


Example usage:

```batch
%UserProfile%\Desktop\remid\bin\remid.cmd %UserProfile%\Desktop\MY_PROJECT_NAME^
 -c %appdata%\.minecraft\saves\MY_WORLD_SAVE\datapacks\^
 -s 'start "" %somewhere%\success.ahk'^
 -f '%somewhere%\failure.bat'
```

### Scripts

You may take inspiration from my scripts, take a look here: https://gist.github.com/2called-chaos/0390bfdf1be577f3dd2e6bbaa281e3d6

Most of them are currently also included in the demo project folder.


## Docs / remid.rb

Take a look at the [demo project](https://github.com/2called-chaos/remid/tree/master/_demo_project) in this repository. It contains a lot of documented examples of the options and syntax. The `_datapack` folder contains the compiled output so you can see and compare how things work.


## Why is X so weird?

The syntax additions are a bit all over the place. Initially I wanted it to be vanilla compatible (which is why some operators start with the comment character #) but quickly realized that this was a dumb idea. The other big constraints in choosing operators were potential conflicts with vanilla stuff, my lack of skill to code a proper compiler and frankly the somewhat alignment with the syntax highlighting I have in my Sublime Text :D

Technically it is easy to change the operators but I can't really bother to come up with a better set of operators myself :)


## Todo

  * Allow empty lines in multiline commands (currently that will split them into 2 commands)
  * Figure out a syntax sugar to schedule anonymous functions more easily
  * Add and increment on an Entity helper class
  * JSON text & book helper / text placeholders


## Contributing

  Contributions are very welcome! Either report errors, bugs and propose features or directly submit code:

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Added some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request



## Legal
* © 2022, Sven Pachnit (www.bmonkeys.net)
* REMID is licensed under the MIT license.
* REMID is **not** affiliated with Mojang or Microsoft.
