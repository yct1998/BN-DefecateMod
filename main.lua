local mod = game.mod_runtime[game.current_mod]

-- 主入口文件只做“装配”：
-- 1. 载入拆分后的模块；
-- 2. 把对外暴露的回调函数挂到 mod_runtime 上。

local ui = require( "tn.ui" )
local logic = require( "tn.logic" )

-- 物品主动使用：打开排泄管理菜单。
mod.use_relief_tool = ui.use_relief_tool
-- 动作菜单入口：无需携带专门物品也可打开菜单。
mod.open_relief_menu = ui.open_relief_menu

-- 污秽食物的 use_action 回调。
mod.drink_urine = ui.drink_urine
mod.eat_feces = ui.eat_feces

-- 新游戏与读档时初始化角色状态。
mod.on_game_started = function()
    logic.initialize_state( gapi.get_avatar() )
end

mod.on_game_load = function()
    logic.initialize_state( gapi.get_avatar() )
end

-- 定时推进系统：把 pending 储备池逐步转成实际需求值。
mod.on_every_5_minutes = function()
    local who = gapi.get_avatar()
    if not who then
        return
    end
    logic.tick_player_needs( who )
end
