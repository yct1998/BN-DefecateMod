local mod = game.mod_runtime[game.current_mod]
local gettext = locale.gettext



game.add_hook("on_game_started", function(...) return mod.on_game_started(...) end)
game.add_hook("on_game_load", function(...) return mod.on_game_load(...) end)
gapi.add_on_every_x_hook(TimeDuration.from_minutes(5), function(...) return mod.on_every_5_minutes(...) end)
game.iuse_functions["TN_DRINK_URINE"] = function(...) return mod.drink_urine(...) end
game.iuse_functions["TN_EAT_FECES"] = function(...) return mod.eat_feces(...) end
