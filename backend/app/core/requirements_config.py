"""Bounded rule grammar and parameter vocabulary, not ranking weights."""
PARSER_VERSION = "requirements-rules-v1"
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
    "电脑隔层尺寸": ("laptop_inches", {"inch": 1, "英寸": 1}),
}
USE_CASES = ("日常通勤", "通勤", "跑步", "慢跑", "散步", "雨天通勤", "旅行", "办公", "学习", "游戏", "运动", "出差", "上学", "越野跑")
TEXT_ALIASES = {"颜色": "color", "材质": "material", "鞋楦": "fit", "佩戴形式": "form_factor", "防水等级": "waterproof_rating"}
SOFT_PREFIXES = ("最好", "优先", "偏好", "希望", "尽量")
HARD_PREFIXES = ("必须", "一定要", "需要", "只要", "仅要")
INTENT_PREFIXES = {
    "帮我推荐": "recommend", "推荐": "recommend", "我想买": "recommend", "想买": "recommend", "购买": "recommend", "买": "recommend",
    "帮我对比": "compare", "对比": "compare", "比较": "compare", "解释": "explain", "了解": "explain",
}
INTENT_COMMANDS = {"推荐商品": "recommend", "生成报告": "report", "生成决策报告": "report", "生成购物决策报告": "report"}
