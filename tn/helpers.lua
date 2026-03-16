-- 通用辅助函数。
--
-- 这里放不会直接涉及业务规则的小工具，避免逻辑文件过长。

local H = {}

-- 从角色变量表中读取数值，不存在或无法解析时回落到默认值。
function H.get_num_value( char, key, default )
    local val = char:get_value( key )
    if val == "" then
        return default
    end
    local n = tonumber( val )
    if not n then
        return default
    end
    return n
end

-- 向角色变量表写入数值，统一转成字符串保存。
function H.set_num_value( char, key, value )
    char:set_value( key, tostring( value ) )
end

-- 安全调用一个返回数字的方法；失败时返回 nil。
function H.call_method_number( char, method_name )
    local fn = char[method_name]
    if not fn then
        return nil
    end
    local ok, value = pcall( function() return fn( char ) end )
    if not ok then
        return nil
    end
    local n = tonumber( value )
    if not n then
        return nil
    end
    return n
end

-- 安全检测特质，避免 Lua 异常中断主流程。
function H.safe_has_trait( char, trait_id )
    local ok, has = pcall( function() return char:has_trait( trait_id ) end )
    if not ok then
        return false
    end
    return has == true
end

-- 数值夹逼。
function H.clamp( value, lo, hi )
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

-- 把 pending 储备池按比例释放成实际增长值。
function H.bleed_pending( pending, ratio, epsilon )
    if pending <= 0 then
        return 0, 0
    end
    local delta = pending * ratio
    if pending <= epsilon or delta < epsilon then
        delta = pending
    end
    return pending - delta, delta
end

-- 安全移除 effect。不同版本可能暴露不同 API，因此双重尝试。
function H.clear_effect_if_present( char, effect_id )
    if not char:has_effect( effect_id ) then
        return
    end
    pcall( function() char:remove_effect( effect_id ) end )
    pcall( function() char:rem_effect( effect_id ) end )
end

-- 统一加士气；失败时静默，不影响核心逻辑。
function H.add_morale_safe( char, morale_id, value, cap, duration_mins, decay_mins )
    pcall( function()
        char:add_morale(
            morale_id,
            value,
            cap,
            TimeDuration.from_minutes( duration_mins ),
            TimeDuration.from_minutes( decay_mins ),
            true,
            nil
        )
    end )
end

return H