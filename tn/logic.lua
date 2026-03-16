-- 排泄系统核心逻辑。
--
-- 这个文件负责：
-- 1. 管理 pending/load 的增长与转化；
-- 2. 处理事故、脏污、清洗、污秽食物反应；
-- 3. 根据 TN_FENHAI_KUANGQU 切换正负反馈。

local C = require( "tn.constants" )
local H = require( "tn.helpers" )
local gettext = locale.gettext
local vgettext = locale.vgettext

local M = {}

-- 对外暴露基础读写工具，方便 UI 模块读取状态值。
M.get_num_value = H.get_num_value
M.set_num_value = H.set_num_value

-- 计算尿意/便意容量倍率。
local function get_capacity_modifiers( char )
    local pee_mult = 1.0
    local poo_mult = 1.0

    if H.safe_has_trait( char, C.trait_gourmand ) then poo_mult = poo_mult + 0.35 end
    if H.safe_has_trait( char, C.trait_lighteater ) then poo_mult = poo_mult - 0.25 end
    if H.safe_has_trait( char, C.trait_huge ) then
        pee_mult = pee_mult + 0.10
        poo_mult = poo_mult + 0.10
    end
    if H.safe_has_trait( char, C.trait_small ) then
        pee_mult = pee_mult - 0.12
        poo_mult = poo_mult - 0.12
    end
    if H.safe_has_trait( char, C.trait_thirsty ) then pee_mult = pee_mult - 0.10 end

    pee_mult = H.clamp( pee_mult, 0.55, 1.80 )
    poo_mult = H.clamp( poo_mult, 0.55, 1.80 )
    return pee_mult, poo_mult
end

-- 在角色脚下生成排泄产物。
local function add_ground_item_at_char( char, itype, count )
    if C.disable_item_generation then
        return
    end
    pcall( function() char:create_item( ItypeId.new( itype ), count ) end )
end

-- 记录当前污染类型：1=尿液，2=粪便。
local function mark_lower_clothing_dirty_state( char, type_key )
    local state_num = 1
    if type_key == "poo" then state_num = 2 end
    H.set_num_value( char, "tn_soiled_level", state_num )
end

-- 消耗清水用于清洗。
function M.consume_clean_water( char )
    local ok1, used1 = pcall( function() return char:use_charges_if_avail( ItypeId.new( "water_clean" ), 1 ) end )
    if ok1 and used1 then return true end
    local ok2, used2 = pcall( function() return char:use_charges_if_avail( ItypeId.new( "water" ), 1 ) end )
    if ok2 and used2 then return true end
    return false
end

-- 消耗纸张用于擦拭。
local function consume_wiping_paper( char )
    local item_ids = { "toilet_paper", "paper" }
    for _, item_id in ipairs( item_ids ) do
        local ok_charges, used_charges = pcall( function() return char:use_charges_if_avail( ItypeId.new( item_id ), 1 ) end )
        if ok_charges and used_charges then return true end
        local ok_amount, used_amount = pcall( function() return char:use_amount( ItypeId.new( item_id ), 1 ) end )
        if ok_amount and used_amount ~= nil and used_amount ~= false then return true end
    end
    return false
end

-- 执行排泄动作的时间消耗。
local function spend_relief_time( char, move_cost )
    if move_cost <= 0 then return end
    local ok = pcall( function() char:mod_moves( -move_cost ) end )
    if ok then return end
    pcall( function() char:assign_activity( C.act_wait, move_cost, 0 ) end )
end

-- 清除所有脏污相关效果与对应士气。
function M.clean_soiled_state( char )
    H.set_num_value( char, "tn_soiled_level", 0 )
    H.clear_effect_if_present( char, C.effect_soiled )
    H.clear_effect_if_present( char, C.effect_wet_pants )
    H.clear_effect_if_present( char, C.effect_poop_pants )
    H.clear_effect_if_present( char, C.effect_no_wipe )
    pcall( function() char:rem_morale( C.morale_laoba_dirty ) end )
    pcall( function() char:rem_morale( C.morale_urine_disgust ) end )
    pcall( function() char:rem_morale( C.morale_feces_disgust ) end )
end

-- 根据 TN_FENHAI_KUANGQU 对脏污状态进行正负分流。
function M.apply_filth_trait_morale( char )
    local soiled_level = H.get_num_value( char, "tn_soiled_level", 0 )
    local is_dirty = soiled_level > 0
        or char:has_effect( C.effect_soiled )
        or char:has_effect( C.effect_wet_pants )
        or char:has_effect( C.effect_poop_pants )

    if not H.safe_has_trait( char, C.trait_fenhai_kuangqu ) then
        pcall( function() char:rem_morale( C.morale_laoba_dirty ) end )
        return
    end

    H.clear_effect_if_present( char, C.effect_soiled )
    H.clear_effect_if_present( char, C.effect_wet_pants )
    H.clear_effect_if_present( char, C.effect_poop_pants )
    H.clear_effect_if_present( char, C.effect_no_wipe )
    pcall( function() char:rem_morale( C.morale_urine_disgust ) end )
    pcall( function() char:rem_morale( C.morale_feces_disgust ) end )

    if not is_dirty then
        pcall( function() char:rem_morale( C.morale_laoba_dirty ) end )
        return
    end

    H.add_morale_safe( char, C.morale_laoba_dirty, 8, 24, 45, 20 )
end

-- 吃屎/喝尿时的特殊反应。
function M.apply_foul_consumption( char, is_urine )
    if H.safe_has_trait( char, C.trait_fenhai_kuangqu ) then
        local gain = 20
        if not is_urine then gain = 26 end
        pcall( function() char:rem_morale( C.morale_urine_disgust ) end )
        pcall( function() char:rem_morale( C.morale_feces_disgust ) end )
        H.add_morale_safe( char, C.morale_laoba_feast, gain, 60, 120, 30 )
        --~ 粪海狂蛆食用污秽物后获得快感时的提示。
        if char:is_avatar() then gapi.add_msg( MsgType.good, gettext( "You relish this filthy delicacy.。" ) ) end
        return
    end

    if is_urine then
        char:add_effect( C.effect_nausea, TimeDuration.from_minutes( 7 ) )
        H.add_morale_safe( char, C.morale_urine_disgust, -18, -40, 90, 25 )
        --~ 普通角色喝尿后的恶心提示。
        if char:is_avatar() then gapi.add_msg( MsgType.bad, gettext( "The smell makes you nauseous and disgusted." ) ) end
        return
    end

    char:add_effect( C.effect_nausea, TimeDuration.from_minutes( 15 ) )
    H.add_morale_safe( char, C.morale_feces_disgust, -30, -70, 120, 30 )
    --~ 普通角色吃粪后的恶心提示。
    if char:is_avatar() then gapi.add_msg( MsgType.bad, gettext( "You almost vomited bile." ) ) end
end

-- 根据当前 load / capacity 比例设置阶段 effect。
local function set_effect_stage( char, type_key, load, capacity )
    local stage = 0
    local t1 = capacity * 0.55
    local t2 = capacity * 0.80
    local t3 = capacity * 1.00
    if load >= t3 then
        stage = 3
    elseif load >= t2 then
        stage = 2
    elseif load >= t1 then
        stage = 1
    end

    local old_stage = H.get_num_value( char, "tn_stage_" .. type_key, 0 )

    if type_key == "pee" then
        H.clear_effect_if_present( char, C.effect_pee_1 )
        H.clear_effect_if_present( char, C.effect_pee_2 )
        H.clear_effect_if_present( char, C.effect_pee_3 )
        if stage == 1 then char:add_effect( C.effect_pee_1, TimeDuration.from_minutes( 10 ) ) end
        if stage == 2 then char:add_effect( C.effect_pee_2, TimeDuration.from_minutes( 10 ) ) end
        if stage == 3 then char:add_effect( C.effect_pee_3, TimeDuration.from_minutes( 10 ) ) end
    else
        H.clear_effect_if_present( char, C.effect_poo_1 )
        H.clear_effect_if_present( char, C.effect_poo_2 )
        H.clear_effect_if_present( char, C.effect_poo_3 )
        if stage == 1 then char:add_effect( C.effect_poo_1, TimeDuration.from_minutes( 10 ) ) end
        if stage == 2 then char:add_effect( C.effect_poo_2, TimeDuration.from_minutes( 10 ) ) end
        if stage == 3 then char:add_effect( C.effect_poo_3, TimeDuration.from_minutes( 10 ) ) end
    end

    if char:is_avatar() and stage > old_stage then
        --~ 玩家首次进入轻度尿意阶段时的提示。
        if type_key == "pee" and stage == 1 then gapi.add_msg( MsgType.warning, gettext( "You're starting to feel the urge to urinate." ) ) end
        --~ 玩家首次进入强烈尿意阶段时的提示。
        if type_key == "pee" and stage == 2 then gapi.add_msg( MsgType.bad, gettext( "Your urge to urinate is noticeable; it's best to use the toilet soon." ) ) end
        --~ 玩家首次进入临界尿意阶段时的提示。
        if type_key == "pee" and stage == 3 then gapi.add_msg( MsgType.bad, gettext( "You can barely hold it in!" ) ) end
        --~ 玩家首次进入轻度便意阶段时的提示。
        if type_key == "poo" and stage == 1 then gapi.add_msg( MsgType.warning, gettext( "You're starting to feel the urge to defecate." ) ) end
        --~ 玩家首次进入强烈便意阶段时的提示。
        if type_key == "poo" and stage == 2 then gapi.add_msg( MsgType.bad, gettext( "Your urge to defecate is noticeable; it's best to use the toilet soon." ) ) end
        --~ 玩家首次进入临界便意阶段时的提示。
        if type_key == "poo" and stage == 3 then gapi.add_msg( MsgType.bad, gettext( "You're about to lose the urge to hold it in!" ) ) end
    end

    H.set_num_value( char, "tn_stage_" .. type_key, stage )
end

function M.initialize_state( char )
    if not char then return end
    local thirst = H.call_method_number( char, "get_thirst" )
    local hunger = H.call_method_number( char, "get_hunger" )
    local kcal = H.call_method_number( char, "get_stored_kcal" )
    if thirst then H.set_num_value( char, "tn_last_thirst", thirst ) end
    if hunger then H.set_num_value( char, "tn_last_hunger", hunger ) end
    if kcal then H.set_num_value( char, "tn_last_kcal", kcal ) end
    if char:get_value( "tn_pee_load" ) == "" then H.set_num_value( char, "tn_pee_load", 0 ) end
    if char:get_value( "tn_poo_load" ) == "" then H.set_num_value( char, "tn_poo_load", 0 ) end
    if char:get_value( "tn_pee_pending" ) == "" then H.set_num_value( char, "tn_pee_pending", 0 ) end
    if char:get_value( "tn_poo_pending" ) == "" then H.set_num_value( char, "tn_poo_pending", 0 ) end
    if char:get_value( "tn_stage_pee" ) == "" then H.set_num_value( char, "tn_stage_pee", 0 ) end
    if char:get_value( "tn_stage_poo" ) == "" then H.set_num_value( char, "tn_stage_poo", 0 ) end
    if char:get_value( "tn_soiled_level" ) == "" then H.set_num_value( char, "tn_soiled_level", 0 ) end
    if char:get_value( "tn_pee_prompt_locked" ) == "" then H.set_num_value( char, "tn_pee_prompt_locked", 0 ) end
end

-- 当前是否在进行容易被尿急打断的活动。
local function has_important_activity( char )
    local ids = { C.act_wait, C.act_read, C.act_craft, C.act_longcraft }
    for _, act in ipairs( ids ) do
        local ok, has = pcall( function() return char:has_activity( act ) end )
        if ok and has then return true end
    end
    return false
end

-- 执行一次主动排泄。
function M.do_relief( char, pee_ratio, poo_ratio, move_cost, label )
    local pee_before = H.get_num_value( char, "tn_pee_load", 0 )
    local poo_before = H.get_num_value( char, "tn_poo_load", 0 )
    local want_pee = pee_ratio < 0.999
    local want_poo = poo_ratio < 0.999
    local allow_pee = ( not want_pee ) or pee_before >= C.pee_relief_threshold
    local allow_poo = ( not want_poo ) or poo_before >= C.poo_relief_threshold

    --~ 玩家当前尿意/便意不足以如厕时的提示。
    if not allow_pee and want_pee and char:is_avatar() then gapi.add_msg( MsgType.info, gettext( "You don't feel like using the toilet for now." ) ) end
    --~ 玩家当前尿意/便意不足以如厕时的提示。
    if not allow_poo and want_poo and char:is_avatar() then gapi.add_msg( MsgType.info, gettext( "You don't feel like using the toilet for now." ) ) end
    if not allow_pee and not allow_poo then return false end
    if not allow_pee then pee_ratio = 1.00 end
    if not allow_poo then poo_ratio = 1.00 end

    local pee_after = pee_before * pee_ratio
    local poo_after = poo_before * poo_ratio
    local pee_released = pee_before - pee_after
    local poo_released = poo_before - poo_after

    -- 如果在阈值过滤后并没有实际释放任何需求值，就直接返回，避免误报“已排便/已排尿”。
    if pee_released <= 0.001 and poo_released <= 0.001 then
        return false
    end

    spend_relief_time( char, move_cost or 0 )
    H.set_num_value( char, "tn_pee_load", pee_after )
    H.set_num_value( char, "tn_poo_load", poo_after )
    H.set_num_value( char, "tn_pee_prompt_locked", 0 )

    if pee_released >= 20 then
        local pee_count = math.max( 1, math.floor( pee_released / 45 ) )
        add_ground_item_at_char( char, "tn_urine", pee_count )
    end
    if poo_released >= 20 then
        local poo_count = math.max( 1, math.floor( poo_released / 50 ) )
        add_ground_item_at_char( char, "tn_human_feces", poo_count )
    end

    if poo_released >= 5 then
        if consume_wiping_paper( char ) then
            H.clear_effect_if_present( char, C.effect_no_wipe )
            --~ 玩家排便后成功使用纸张擦拭时的提示。
            if char:is_avatar() then gapi.add_msg( MsgType.good, gettext( "You used paper to wipe." ) ) end
        else
            if H.safe_has_trait( char, C.trait_fenhai_kuangqu ) then
                H.clear_effect_if_present( char, C.effect_no_wipe )
                --~ 粪海狂蛆排便后未擦拭时的特殊提示。
                if char:is_avatar() then gapi.add_msg( MsgType.good, gettext( "You didn't wipe and instead found it even more thrilling." ) ) end
            else
                char:add_effect( C.effect_no_wipe, TimeDuration.from_minutes( 90 ) )
                --~ 普通角色排便后未擦拭时的提示。
                if char:is_avatar() then gapi.add_msg( MsgType.bad, gettext( "You didn't use toilet paper to wipe, and your mood worsened." ) ) end
            end
        end
    end

    if char:is_avatar() and label then gapi.add_msg( MsgType.good, label ) end
    local pee_mult, poo_mult = get_capacity_modifiers( char )
    set_effect_stage( char, "pee", pee_after, 100 * pee_mult )
    set_effect_stage( char, "poo", poo_after, 100 * poo_mult )
    return true
end

-- 尿意 3 阶时，中断重要活动并提示是否立即解决。
local function prompt_pee_during_activity( char )
    local stage_pee = H.get_num_value( char, "tn_stage_pee", 0 )
    if stage_pee < 3 then return end
    if not has_important_activity( char ) then return end
    if H.get_num_value( char, "tn_pee_prompt_locked", 0 ) > 0 then return end
    H.set_num_value( char, "tn_pee_prompt_locked", 1 )

    pcall( function() char:cancel_activity() end )
    local popup = QueryPopup.new()
    --~ 尿意达到临界且打断活动时的确认弹窗。
    popup:message( gettext( "Your urge to urinate is extremely severe; holding it further might lead to wetting yourself. Go to urinate now? " ) )
    local answer = popup:query_yn()
    if answer == "YES" then
        --~ 玩家在尿急弹窗中选择立即排尿后的提示。
        M.do_relief( char, 0.10, 1.00, 200, gettext( "You quickly relieved your urge to urinate." ) )
    end
end

-- 超过事故线后触发被动排泄，并按特质切换正负反馈。
local function apply_accident_if_needed( char, pee_load, poo_load, pee_capacity, poo_capacity )
    local has_fenhai = H.safe_has_trait( char, C.trait_fenhai_kuangqu )

    if pee_load >= pee_capacity * 1.25 then
        pee_load = pee_capacity * 0.35
        H.set_num_value( char, "tn_pee_prompt_locked", 0 )
        if not has_fenhai then
            char:add_effect( C.effect_soiled, TimeDuration.from_minutes( 120 ) )
            char:add_effect( C.effect_wet_pants, TimeDuration.from_hours( 4 ) )
        else
            H.clear_effect_if_present( char, C.effect_soiled )
            H.clear_effect_if_present( char, C.effect_wet_pants )
        end
        mark_lower_clothing_dirty_state( char, "pee" )
        add_ground_item_at_char( char, "tn_urine", 2 )
        if char:is_avatar() then
            if has_fenhai then
                --~ 粪海狂蛆发生尿失禁后的提示。
                gapi.add_msg( MsgType.good, gettext( "After losing control, you feel a strange satisfaction, with your lower body soiled by urine." ) )
            else
                --~ 普通角色发生尿失禁后的提示。
                gapi.add_msg( MsgType.bad, gettext( "You have lost control of your bladder, and the lower half of your body is soiled with urine." ) )
            end
        end
    end

    if poo_load >= poo_capacity * 1.20 then
        poo_load = poo_capacity * 0.30
        if not has_fenhai then
            char:add_effect( C.effect_soiled, TimeDuration.from_minutes( 180 ) )
            char:add_effect( C.effect_poop_pants, TimeDuration.from_hours( 8 ) )
            char:add_effect( C.effect_no_wipe, TimeDuration.from_hours( 3 ) )
        else
            H.clear_effect_if_present( char, C.effect_soiled )
            H.clear_effect_if_present( char, C.effect_poop_pants )
            H.clear_effect_if_present( char, C.effect_no_wipe )
        end
        mark_lower_clothing_dirty_state( char, "poo" )
        add_ground_item_at_char( char, "tn_human_feces", 2 )
        if char:is_avatar() then
            if has_fenhai then
                --~ 粪海狂蛆发生失禁排便后的提示。
                gapi.add_msg( MsgType.good, gettext( "After losing control, you feel a strange satisfaction, with your lower body soiled by urine." ) )
            else
                --~ 普通角色发生失禁排便后的提示。
                gapi.add_msg( MsgType.bad, gettext( "You have lost control of your bowels, and your buttocks and lower body are soiled with feces." ) )
            end
        end
    end

    return pee_load, poo_load
end

-- 每 5 分钟执行一次：
-- 1. 喝水 -> 尿意 pending
-- 2. kcal 增量为主、hunger 为辅 -> 便意 pending
-- 3. pending 按比例缓慢转为实际需求值
-- 4. 检查事故、阶段和特质反馈。
function M.tick_player_needs( char )
    if not char then return end
    local pee_load = H.get_num_value( char, "tn_pee_load", 0 )
    local poo_load = H.get_num_value( char, "tn_poo_load", 0 )
    local pee_pending = H.get_num_value( char, "tn_pee_pending", 0 )
    local poo_pending = H.get_num_value( char, "tn_poo_pending", 0 )

    local current_thirst = H.call_method_number( char, "get_thirst" )
    local current_hunger = H.call_method_number( char, "get_hunger" )
    local current_kcal = H.call_method_number( char, "get_stored_kcal" )

    local last_thirst = H.get_num_value( char, "tn_last_thirst", current_thirst or 0 )
    local last_hunger = H.get_num_value( char, "tn_last_hunger", current_hunger or 0 )
    local last_kcal = H.get_num_value( char, "tn_last_kcal", current_kcal or 0 )

    if current_thirst and last_thirst then
        local thirst_drop = last_thirst - current_thirst
        if thirst_drop > 0 then
            pee_pending = pee_pending + thirst_drop * C.pee_intake_factor
        end
    end

    if current_hunger and last_hunger then
        local hunger_drop = last_hunger - current_hunger
        if hunger_drop > 0 then
            poo_pending = poo_pending + hunger_drop * C.poo_hunger_fallback_factor
        end
    end

    if current_kcal and last_kcal then
        local kcal_gain = current_kcal - last_kcal
        if kcal_gain > 0 then
            poo_pending = poo_pending + kcal_gain * C.poo_kcal_factor
        end
    end

    local delta
    pee_pending, delta = H.bleed_pending( pee_pending, C.pee_pending_ratio, C.pending_epsilon )
    pee_load = pee_load + delta

    poo_pending, delta = H.bleed_pending( poo_pending, C.poo_pending_ratio, C.pending_epsilon )
    poo_load = poo_load + delta

    local pee_mult, poo_mult = get_capacity_modifiers( char )
    local pee_capacity = 100 * pee_mult
    local poo_capacity = 100 * poo_mult

    pee_load, poo_load = apply_accident_if_needed( char, pee_load, poo_load, pee_capacity, poo_capacity )

    pee_load = H.clamp( pee_load, 0, 250 )
    poo_load = H.clamp( poo_load, 0, 250 )

    H.set_num_value( char, "tn_pee_load", pee_load )
    H.set_num_value( char, "tn_poo_load", poo_load )
    H.set_num_value( char, "tn_pee_pending", pee_pending )
    H.set_num_value( char, "tn_poo_pending", poo_pending )
    if current_thirst then H.set_num_value( char, "tn_last_thirst", current_thirst ) end
    if current_hunger then H.set_num_value( char, "tn_last_hunger", current_hunger ) end
    if current_kcal then H.set_num_value( char, "tn_last_kcal", current_kcal ) end

    set_effect_stage( char, "pee", pee_load, pee_capacity )
    set_effect_stage( char, "poo", poo_load, poo_capacity )
    M.apply_filth_trait_morale( char )
    prompt_pee_during_activity( char )
end

return M