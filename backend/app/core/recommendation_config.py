"""Versioned, deterministic purchase rules; unrelated to retrieval relevance."""
ALGORITHM_VERSION = "facts-ranking-v1"
# One weight per field/key dimension. Multiple unique preferences within a
# dimension share that weight; repeated copies cannot boost their score.
SOFT_WEIGHTS = {"budget": 2.0, "brand": 1.0, "use_case": 2.0, "feature": 2.0, "parameter": 2.0}
SCORE_DECIMALS = 6
RETRIEVAL_TOP_K = 10
REJECTION_DETAIL_LIMIT = 10
POLICIES = {
    "candidate_coverage": "complete_exact_category_snapshot",
    "budget": "whole_price_interval_inside_hard_bounds",
    "text": "case_sensitive_exact_no_substring_or_inferred_synonyms",
    "use_case": "exact_declared_support_or_exclusion_else_unknown",
    "unknown": "reject_hard_zero_soft",
    "soft_score": "weighted_mean_of_unique_satisfaction_per_field_key_times_100",
    "tie_break": "rounded_score_desc_product_id_asc",
    "relaxation": "explicit_confirmed_requirements_edit_only",
}
WARNINGS = (
    "商品与价格来自本地虚构样例，不是实时报价；分数是已表达软偏好的规则匹配度，不是商品质量或购买保证。",
    "预算按整个样例价格区间判断；未知事实不通过硬约束，软偏好未知或不满足计0分。",
    "用途和文本只做精确匹配，不推断同义词；未声明用途不等于不支持。请查看商品完整缺点、排斥条件和选购建议，自由文本风险不做自动语义推理。",
    "混合检索仅提供相关证据，候选补齐到同品类完整目录；检索得分不参与购买资格或软偏好排序。无软偏好时均为0分，按商品ID稳定排列。",
)
