scoreboard objectives add rd_registry dummy
execute unless score $z_initialized rd_registry matches 1 run function remid_demo:init
say Remid Demo ready
