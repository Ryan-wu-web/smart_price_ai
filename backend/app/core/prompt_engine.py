class PromptEngine:
    @staticmethod
    def recognize(description: str) -> str:
        return (
            "你是一位专业的商品识别专家。请根据以下图片描述，提取结构化信息并以 JSON 格式输出。\n\n"
            "输出字段：name（商品名称）、brand（品牌，无法识别则为空字符串）、"
            "category（品类）、color（主色调）、material（材质）、style（款式）。\n\n"
            "约束：\n"
            "- 如果无法识别品牌，brand 设为空字符串，不要猜测\n"
            "- category 必须是具体品类，如运动鞋、手机、口红、零食等\n"
            "- color 用简洁的中文，如纯白色、黑色、红色\n"
            "- material 无法识别设为空字符串\n"
            "- style 描述具体款式，如低帮板鞋、连衣裙、无线耳机\n\n"
            "示例1（完整识别）：\n"
            '{"name": "Nike Air Force 1 白色 42码", "brand": "Nike", "category": "运动鞋", "color": "纯白色", "material": "皮革", "style": "低帮板鞋"}\n\n'
            "示例2（部分未知）：\n"
            '{"name": "白色运动鞋", "brand": "", "category": "运动鞋", "color": "纯白色", "material": "", "style": "低帮运动鞋"}\n\n'
            f"描述：{description}\n\n"
            "请只输出 JSON，不要添加任何解释文字。"
        )

    @staticmethod
    def suggestion_cards(category: str, brand: str, color: str) -> str:
        return (
            "你是一位购物助手。根据以下商品信息，生成 3-5 张建议卡片，"
            "帮助用户进一步决策。卡片类型包括：lowest_price（全网最低价）、"
            "official_store（官方旗舰店）、similar_style（相似风格推荐）、"
            "price_trend（价格趋势提醒）、filter_color（按颜色筛选）。\n\n"
            f"品类：{category}\n品牌：{brand}\n颜色：{color}\n\n"
            "请以 JSON 数组输出，每个元素包含 type、title、description 字段。"
            "只输出 JSON，不要添加任何解释文字。"
        )

    @staticmethod
    def filter_parse(query_text: str) -> str:
        return (
            "你是一位购物筛选助手。将用户的自然语言筛选请求解析为结构化条件，"
            "以 JSON 格式输出，包含可选字段：price_max（最高价格，数字）、"
            "price_min（最低价格，数字）、color（颜色）、rating_min（最低评分，数字）、"
            "brand（品牌）、platform（平台）。如果某个条件未提及，不要包含该字段。\n\n"
            f"用户请求：{query_text}\n\n"
            "请只输出 JSON，不要添加任何解释文字。"
        )

    @staticmethod
    def trend_analysis(product_name: str, prices: list[dict]) -> str:
        prices_text = "\n".join(
            [f"- {p['date']}: ¥{p['price']} ({p['platform']})" for p in prices]
        )
        return (
            "你是一位价格分析师。根据以下商品价格历史数据，生成趋势分析。\n\n"
            f"商品：{product_name}\n历史价格：\n{prices_text}\n\n"
            "请以 JSON 格式输出，包含字段：trend（趋势描述，如上涨/下跌/平稳）、"
            "advice（购买建议，如建议等待/立即购买/观望）、"
            "confidence（置信度，0-1 之间的浮点数）。"
            "只输出 JSON，不要添加任何解释文字。"
        )

    @staticmethod
    def report_generation(
        product_name: str, best_choice: dict, alternatives: list[dict]
    ) -> str:
        alts_text = "\n".join(
            [
                f"- {a['name']} ({a['platform']}): ¥{a['price']}，评分{a.get('rating', 'N/A')}"
                for a in alternatives
            ]
        )
        return (
            "你是一位购物决策顾问。根据以下信息，为用户生成一份购买决策报告。\n\n"
            f"目标商品：{product_name}\n"
            f"最佳选择：{best_choice['name']} ({best_choice['platform']})，"
            f"¥{best_choice['price']}，评分{best_choice.get('rating', 'N/A')}\n"
            f"备选方案：\n{alts_text}\n\n"
            "请以 JSON 格式输出，包含字段：summary（摘要）、pros（优点列表）、"
            "cons（缺点列表）、recommendation（最终推荐语）。"
            "只输出 JSON，不要添加任何解释文字。"
        )

    @staticmethod
    def chat_reply(
        message: str,
        context: list[dict],
        current_product: dict | None,
    ) -> str:
        ctx_text = "\n".join(
            [f"{'用户' if c['role'] == 'user' else '助手'}: {c['content']}" for c in context[-6:]]
        )
        product_text = (
            f"当前关注商品：{current_product['name']}（¥{current_product.get('price', 0)}）"
            if current_product
            else "当前未关注特定商品"
        )
        history_part = ctx_text + "\n\n" if ctx_text else "\n"
        return (
            "你是购物顾问'小价'，语气亲切自然，适当使用 emoji。\n\n"
            f"{product_text}\n\n"
            f"最近对话：\n{history_part}"
            f"用户：{message}\n\n"
            "以 JSON 输出：reply, action, action_data, current_product。\n\n"
            "action 规则：\n"
            "- 含'对比/比较/vs' → report + report_type=comparison\n"
            "- 含'购买建议/什么时候买/在哪买' → report + report_type=buy_guide\n"
            "- 含'哪个好/推荐/帮我选' → report + report_type=decision\n"
            "- 含'走势/历史价格/趋势' → trend\n"
            "- 其他 → none\n\n"
            "action_data 格式：\n"
            'comparison: {"report_type":"comparison","product_a":"","product_b":"","differences":"","advantages_a":"","advantages_b":"","suitable_for_a":"","suitable_for_b":"}\n'
            'buy_guide: {"report_type":"buy_guide","target_product":"","best_time":"","best_platform":"","popular_colors":"","price_estimate":""}\n'
            'decision: {"report_type":"decision","target_product":"","best_choice":"","suggestion":"","savings":0}\n\n'
            "示例1（对比）："
            '{"reply":"AF1和Dunk各有特色😊","action":"report","action_data":{"report_type":"comparison","product_a":"Nike AF1","product_b":"Nike Dunk","differences":"AF1经典，Dunk潮流","advantages_a":"皮质好、耐穿","advantages_b":"配色多、轻便","suitable_for_a":"通勤用户","suitable_for_b":"潮流用户"},"current_product":{"name":"Nike AF1","brand":"Nike","category":"运动鞋","price":799,"platform":"京东"}}\n'
            "示例2（购买建议）："
            '{"reply":"AF1大促入手最划算👟","action":"report","action_data":{"report_type":"buy_guide","target_product":"Nike AF1","best_time":"618/双11","best_platform":"京东自营","popular_colors":"纯白、熊猫","price_estimate":"¥600-800"},"current_product":{"name":"Nike AF1","brand":"Nike","category":"运动鞋","price":799,"platform":"京东"}}\n'
            "只输出 JSON，不要解释。"
        )
