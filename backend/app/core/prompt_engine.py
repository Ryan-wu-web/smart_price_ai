class PromptEngine:
    @staticmethod
    def recognize(description: str) -> str:
        return (
            '你是一位专业的商品识别专家。根据以下对图片中物品的描述，'
            '提取结构化信息并以 JSON 格式输出，包含字段：name（商品名称）、'
            'brand（品牌，如无法识别则为空字符串）、category（品类，如鞋、包、手机等）、'
            'color（主色调）、material（材质）、style（款式）。

'
            f'描述：{description}

'
            '请只输出 JSON，不要添加任何解释文字。'
        )

    @staticmethod
    def suggestion_cards(category: str, brand: str, color: str) -> str:
        return (
            '你是一位购物助手。根据以下商品信息，生成 3-5 张建议卡片，'
            '帮助用户进一步决策。卡片类型包括：lowest_price（全网最低价）、'
            'official_store（官方旗舰店）、similar_style（相似风格推荐）、'
            'price_trend（价格趋势提醒）、filter_color（按颜色筛选）。

'
            f'品类：{category}
品牌：{brand}
颜色：{color}

'
            '请以 JSON 数组输出，每个元素包含 type、title、description 字段。'
            '只输出 JSON，不要添加任何解释文字。'
        )

    @staticmethod
    def filter_parse(query_text: str) -> str:
        return (
            '你是一位购物筛选助手。将用户的自然语言筛选请求解析为结构化条件，'
            '以 JSON 格式输出，包含可选字段：price_max（最高价格，数字）、'
            'price_min（最低价格，数字）、color（颜色）、rating_min（最低评分，数字）、'
            'brand（品牌）、platform（平台）。如果某个条件未提及，不要包含该字段。

'
            f'用户请求：{query_text}

'
            '请只输出 JSON，不要添加任何解释文字。'
        )

    @staticmethod
    def trend_analysis(product_name: str, prices: list[dict]) -> str:
        prices_text = "
".join(
            [f"- {p['date']}: ¥{p['price']} ({p['platform']})" for p in prices]
        )
        return (
            '你是一位价格分析师。根据以下商品价格历史数据，生成趋势分析。

'
            f'商品：{product_name}
历史价格：
{prices_text}

'
            '请以 JSON 格式输出，包含字段：trend（趋势描述，如上涨/下跌/平稳）、'
            'advice（购买建议，如建议等待/立即购买/观望）、'
            'confidence（置信度，0-1 之间的浮点数）。'
            '只输出 JSON，不要添加任何解释文字。'
        )

    @staticmethod
    def report_generation(
        product_name: str, best_choice: dict, alternatives: list[dict]
    ) -> str:
        alts_text = "
".join(
            [
                f"- {a['name']} ({a['platform']}): ¥{a['price']}，评分{a.get('rating', 'N/A')}"
                for a in alternatives
            ]
        )
        return (
            '你是一位购物决策顾问。根据以下信息，为用户生成一份购买决策报告。

'
            f'目标商品：{product_name}
'
            f'最佳选择：{best_choice["name"]} ({best_choice["platform"]})，'
            f'¥{best_choice["price"]}，评分{best_choice.get("rating", "N/A")}
'
            f'备选方案：
{alts_text}

'
            '请以 JSON 格式输出，包含字段：summary（摘要）、pros（优点列表）、'
            'cons（缺点列表）、recommendation（最终推荐语）。'
            '只输出 JSON，不要添加任何解释文字。'
        )

    @staticmethod
    def chat_reply(
        message: str,
        context: list[dict],
        current_product: dict | None,
    ) -> str:
        ctx_text = "
".join(
            [f"{'用户' if c['role'] == 'user' else '助手'}: {c['content']}" for c in context]
        )
        product_text = (
            f"当前关注商品：{current_product['name']}"
            if current_product
            else "当前未关注特定商品"
        )
        return (
            '你是一位智能购物导购助手。根据对话历史和当前关注商品，回复用户的问题，'
            '并决定是否需要执行某个动作。

'
            f'{product_text}

'
            '对话历史：
' + (ctx_text + "

" if ctx_text else "
")
            f'用户最新消息：{message}

'
            '请以 JSON 格式输出，包含字段：reply（回复内容）、'
            'action（动作类型，可选值：none/compare/filter/trend/report，如不需要动作则为 none）、'
            'action_data（动作所需数据，字典类型，如不需要则为空对象）。'
            '只输出 JSON，不要添加任何解释文字。'
        )
