-- 常量与 ID 定义。
--
-- 这个文件只负责：
-- 1. 统一管理 effect / trait / morale / activity 的 ID；
-- 2. 集中放置排泄系统的平衡参数，方便后续调数值。

local C = {}

-- 效果 ID
C.effect_pee_1 = EffectTypeId.new( "tn_urge_pee_1" )
C.effect_pee_2 = EffectTypeId.new( "tn_urge_pee_2" )
C.effect_pee_3 = EffectTypeId.new( "tn_urge_pee_3" )
C.effect_poo_1 = EffectTypeId.new( "tn_urge_poo_1" )
C.effect_poo_2 = EffectTypeId.new( "tn_urge_poo_2" )
C.effect_poo_3 = EffectTypeId.new( "tn_urge_poo_3" )
C.effect_soiled = EffectTypeId.new( "tn_soiled" )
C.effect_wet_pants = EffectTypeId.new( "tn_wet_pants" )
C.effect_poop_pants = EffectTypeId.new( "tn_poop_pants" )
C.effect_no_wipe = EffectTypeId.new( "tn_no_wipe" )
C.effect_nausea = EffectTypeId.new( "nausea" )

-- 特质 ID
C.trait_gourmand = MutationBranchId.new( "GOURMAND" )
C.trait_lighteater = MutationBranchId.new( "LIGHTEATER" )
C.trait_huge = MutationBranchId.new( "HUGE" )
C.trait_small = MutationBranchId.new( "SMALL" )
C.trait_thirsty = MutationBranchId.new( "THIRSTY" )
C.trait_fenhai_kuangqu = MutationBranchId.new( "TN_FENHAI_KUANGQU" )

-- 士气 ID
C.morale_urine_disgust = MoraleTypeDataId.new( "morale_tn_urine_disgust" )
C.morale_feces_disgust = MoraleTypeDataId.new( "morale_tn_feces_disgust" )
C.morale_laoba_feast = MoraleTypeDataId.new( "morale_tn_laoba_feast" )
C.morale_laoba_dirty = MoraleTypeDataId.new( "morale_tn_laoba_dirty" )

-- activity ID
C.act_wait = ActivityTypeId.new( "ACT_WAIT" )
C.act_read = ActivityTypeId.new( "ACT_READ" )
C.act_craft = ActivityTypeId.new( "ACT_CRAFT" )
C.act_longcraft = ActivityTypeId.new( "ACT_LONGCRAFT" )

-- 基础开关与阈值
C.disable_item_generation = false
C.pee_relief_threshold = 18
C.poo_relief_threshold = 22

-- 输入与转化参数
-- 尿意：由喝水带来的 thirst 下降驱动。
C.pee_intake_factor = 0.5
-- 便意：以 kcal 增量为主，hunger 下降为辅。
C.poo_kcal_factor = 0.05
C.poo_hunger_fallback_factor = 0.1
-- pending -> load 的转化比例
C.pee_pending_ratio = 0.05
C.poo_pending_ratio = 0.05
-- 尾数收尾阈值，避免 pending 永远残留极小值
C.pending_epsilon = 0.05

return C