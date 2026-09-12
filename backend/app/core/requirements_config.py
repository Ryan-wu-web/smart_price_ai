"""Bounded rule grammar and parameter vocabulary, not ranking weights."""
PARSER_VERSION = "requirements-rules-v2"
MAX_ITEMS = 128
MAX_REVISION = 1000
REQUIRED_SLOTS = ("intent", "category", "budget_max")
# Do not widen 跑鞋 to all 运动鞋 or equate generic 降噪 with active ANC.
CATEGORY_ALIASES = {"运动鞋": "运动鞋", "耳机": "耳机", "双肩包": "双肩包"}
FEATURE_ALIASES = {"防水": "waterproof", "主动降噪": "anc", "多设备连接": "multipoint", "低延迟模式": "low_latency_mode"}
# (canonical unit, applicable catalog categories). Different weight bases stay separate.
NUMERIC_PARAMETERS = {
    "weight_g": ("g", ("运动鞋", "双肩包")),
    "earbud_weight_g": ("g", ("耳机",)),
    "device_weight_g": ("g", ("耳机",)),
    "battery_hours": ("h", ("耳机",)),
    "capacity_l": ("L", ("双肩包",)),
    "laptop_inches": ("inch", ("双肩包",)),
}
TEXT_PARAMETERS = {"material", "fit", "color", "form_factor", "waterproof_rating"}
PARAMETER_ALIASES = {
    "单只重量": ("weight_g", {"g": 1, "克": 1, "kg": 1000, "千克": 1000}),
    "空包重量": ("weight_g", {"g": 1, "克": 1, "kg": 1000, "千克": 1000}),
    "单耳重量": ("earbud_weight_g", {"g": 1, "克": 1}),
    "整机重量": ("device_weight_g", {"g": 1, "克": 1}),
    "续航": ("battery_hours", {"h": 1, "小时": 1}),
    "容量": ("capacity_l", {"L": 1, "l": 1, "升": 1}),
    "电脑隔层尺寸": ("laptop_inches", {"inch": 1, "英寸": 1, "寸": 1}),
}
USE_CASES = ("日常通勤", "通勤", "跑步", "慢跑", "散步", "雨天通勤", "旅行", "办公", "学习", "游戏", "运动", "出差", "上学", "越野跑")
TEXT_ALIASES = {"颜色": "color", "材质": "material", "鞋楦": "fit", "佩戴形式": "form_factor", "防水等级": "waterproof_rating"}
SOFT_PREFIXES = ("最好", "优先", "偏好", "希望", "尽量")
HARD_PREFIXES = ("必须", "一定要", "需要", "只要", "仅要")
INTENT_PREFIXES = {
    "帮我推荐": "recommend", "推荐": "recommend", "我想买": "recommend", "想买": "recommend", "购买": "recommend", "买": "recommend",
    "给我找": "recommend", "帮我挑": "recommend", "帮我挑选": "recommend",
    "帮我比较": "compare", "帮我对比": "compare", "对比": "compare", "比较": "compare", "解释": "explain", "了解": "explain",
}
INTENT_COMMANDS = {"推荐商品": "recommend", "生成报告": "report", "生成决策报告": "report", "生成购物决策报告": "report"}

# Whole-command templates. Never match arbitrary suffixes or discard qualifiers.
INTENT_PATTERNS = {
    "report": r"(?:帮我)?(?:生成|出|整理)(?:一份)?(?:购物决策|购物|决策)?报告",
    "explain": r"(?:(?:能)?(?:帮我)?解释(?:一下)?(?:推荐(?:理由)?|(?:这款商品|这双鞋|这些商品)(?:为什么合适)?)(?:吗)?|为什么推荐(?:这些商品|这款商品)?)",
    "compare": r"(?:帮我)?(?:对比|比较)(?:一下)?(?:候选|当前候选|这几款商品)",
}
# Category aliases remain exact. In particular, 背包 need not mean 双肩包.
ACTION_FILLER = r"^(?:一下)?(?:(?:一|两|二|三|[1-3])(?:款|双|副|个)|个)?"
# Unqualified feature/text values are observations until the user chooses strength.
CLARIFY_TEXT_KEYS = frozenset(TEXT_PARAMETERS)
CLARIFY_FEATURE_KEYS = frozenset(FEATURE_ALIASES.values())
