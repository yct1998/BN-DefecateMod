-- UI 与物品 use_action 入口。
--
-- 这个文件只处理玩家交互：
-- 1. 如厕管理器菜单；
-- 2. 吃屎 / 喝尿的 use_action 回调；
-- 3. 状态查看文本。



local logic = require( "tn.logic" )
local gettext = locale.gettext
local vgettext = locale.vgettext

local M = {}

gapi.register_action_menu_entry{
    id = "toilet_needs:relief_menu",
    --~ 动作菜单中的排泄管理入口名称。
    name = gettext( "Excretion Management" ),
    category = "misc",
    hotkey = "n",
    fn = function()
        return M.open_relief_menu()
    end
}


-- 实际执行菜单逻辑的内部函数。
-- 可被动作菜单和旧的物品 use_action 共用。
local function open_relief_menu_for( who )
    if not who or not who:is_avatar() then
        return 0
    end

    local menu = UiList.new()
    --~ 排泄管理菜单标题。
    menu:title( gettext( "Excretion Management" ) )
    --~ 排泄管理菜单中的“小便”选项。
    menu:add( 1, gettext( "Urinate" ) )
    --~ 排泄管理菜单中的“大便”选项。
    menu:add( 2, gettext( "Defecate" ) )
    --~ 排泄管理菜单中的“都解决”选项。
    menu:add( 3, gettext( "Both" ) )
    --~ 排泄管理菜单中的“Check Status”选项。
    menu:add( 4, gettext( "Check Status" ) )
    --~ 排泄管理菜单中的“用水清洗污染”选项。
    menu:add( 5, gettext( "Wash off contamination with water" ) )

    local choice = menu:query()
    if choice == 1 then
        --~ 玩家主动排尿成功后的提示。
        logic.do_relief( who, 0.10, 1.00, 220, gettext( "You have urinated and feel much more comfortable." ) )
    elseif choice == 2 then
        --~ 玩家主动排便成功后的提示。
        logic.do_relief( who, 1.00, 0.10, 360, gettext( "You have defecated, and your abdomen feels relieved." ) )
    elseif choice == 3 then
        --~ 玩家同时解决尿意和便意后的提示。
        logic.do_relief( who, 0.10, 0.10, 480, gettext( "You have completely taken care of your physiological needs." ) )
    elseif choice == 4 then
        local pee_load = logic.get_num_value( who, "tn_pee_load", 0 )
        local poo_load = logic.get_num_value( who, "tn_poo_load", 0 )
        local pee_pending = logic.get_num_value( who, "tn_pee_pending", 0 )
        local poo_pending = logic.get_num_value( who, "tn_poo_pending", 0 )
        local soiled_level = logic.get_num_value( who, "tn_soiled_level", 0 )
        --~ 身体污染状态：无污染。
        local soiled_text = gettext( "No contamination" )
        if soiled_level == 1 then
            --~ 身体污染状态：尿液污染。
            soiled_text = gettext( "Urine contamination" )
        elseif soiled_level == 2 then
            --~ 身体污染状态：粪便污染。
            soiled_text = gettext( "Fecal contamination" )
        end
        --~ 查看排泄状态时的汇总文本，依次显示：尿意、尿意储备、便意、便意储备、污染描述。
        gapi.add_msg(
            MsgType.mixed,
            string.format(
                gettext( "Current urge to urinate %.1f / 100 (reserve %.1f), urge to defecate %.1f / 100 (reserve %.1f), bodily contamination: %s." ),
                pee_load,
                pee_pending,
                poo_load,
                poo_pending,
                soiled_text
            )
        )
    elseif choice == 5 then
        if logic.get_num_value( who, "tn_soiled_level", 0 ) <= 0 then
            --~ 玩家尝试清洗，但当前没有污染时的提示。
            gapi.add_msg( MsgType.info, gettext( "You currently have no contamination that needs washing off." ) )
        elseif logic.consume_clean_water( who ) then
            logic.clean_soiled_state( who )
            --~ 玩家成功用水清洗身体污染时的提示。
            gapi.add_msg( MsgType.good, gettext( "You used water to wash off the bodily contamination." ) )
        else
            --~ 玩家想清洗身体污染，但没有足够水时的提示。
            gapi.add_msg( MsgType.warning, gettext( "You need water to wash off the contamination." ) )
        end
    end

    return 0
end

-- 打开排泄管理菜单（供旧物品 use_action 兼容调用）。
function M.use_relief_tool( params )
    return open_relief_menu_for( params.user )
end

-- 打开排泄管理菜单（供动作菜单入口调用）。
function M.open_relief_menu()
    return open_relief_menu_for( gapi.get_avatar() )
end

-- 喝尿 use_action。
function M.drink_urine( params )
    local who = params.user
    if who and who:is_avatar() then
        logic.apply_foul_consumption( who, true )
    end
    -- 返回 1，表示这次 use_action 成功执行并消耗物品。
    return 1
end

-- 吃屎 use_action。
function M.eat_feces( params )
    local who = params.user
    if who and who:is_avatar() then
        logic.apply_foul_consumption( who, false )
    end
    -- 返回 1，表示这次 use_action 成功执行并消耗物品。
    return 1
end

return M