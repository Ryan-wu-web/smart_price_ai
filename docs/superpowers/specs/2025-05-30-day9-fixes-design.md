# Day 9 功能修复 + AI Pipeline 调优 — 设计规格

> 日期：2025-05-30
> 范围：7个测试反馈问题的修复 + 2个AI Pipeline优化

---

## 架构概览

本次改动覆盖前后端共 10+ 个文件，分为 6 个独立模块。模块间依赖关系：

```
模块一（官方/相似加载修复） ─┬─→ compare_screen.dart（新增 filterMode 参数）
                              └─→ result_screen.dart（去掉多余 API 调用）
                              └─→ comparison.py（支持 tag 过滤 + 相似度）

模块二（搜索页美化） ─────────→ search_screen.dart（视觉重构 + 历史记录）

模块三（决策卡片稳定性） ─────┬─→ prompt_engine.py（重写 chat_reply Prompt）
                              └─→ chat_screen.dart（前端兜底触发逻辑）

模块四（VLM Prompt 调优） ────┬─→ prompt_engine.py（重写 recognize Prompt）
                              └─→ vlm_client.py（更新默认 prompt）
                              └─→ recognition.py（增加重试容错）

模块五（AI导购对话优化） ─────┬─→ prompt_engine.py（优化 chat_reply 风格）
                              └─→ chat.py（增加摘要机制 + 会话持久化）

模块六（Mock数据扩充） ──────→ comparison.py（base_items 扩充至 ~195 条）
```

---

## 模块一：官方旗舰店 / 相似推荐

### 问题诊断
ResultScreen 点击"官方旗舰店"/"相似推荐"时，先调用 `ApiService().getSuggestions()` → 后端 `SuggestionService.generate_cards()` → `LLMClient.chat_json()` → 火山引擎 LLM API（往返 15-20s）。调用完成后前端仅做 SnackBar 提示，**丢弃返回数据**，直接跳转 CompareScreen。CompareScreen 自行重新调用 `/api/v1/compare` 获取数据。因此 suggest API 调用**完全多余**。

同时 `_isLoading` 状态控制的 `CircularProgressIndicator` 被插入 ListView children 中，位于两个 SuggestionCard 之间，挤占布局。

### 方案
1. **去掉多余 API 调用**：ResultScreen 中官方/相似按钮点击后直接跳转 CompareScreen，携带 `filterMode` 参数
2. **CompareScreen 增加 filterMode**：支持 `null`（正常）/`official`（仅官方）/`similar`（相似推荐）
3. **后端支持 tag 过滤**：`MockDataSource.search()` 增加 `tags` 过滤能力
4. **UI 标识**：CompareScreen 根据 filterMode 显示顶部标识栏 + Toggle 开关

### 数据流
```
用户点击"官方旗舰店" → ResultScreen 携带 filterMode='official' 跳转 CompareScreen
                                                ↓
                              CompareScreen.initState() 调用 _loadProducts()
                                                ↓
                              后端 /api/v1/compare?category=运动鞋&brand=Nike
                                                ↓
                              ComparisonService.compare() → MockDataSource.search()
                              如果 filterMode='official'，额外过滤 tags 含'自营'/'官方'
                                                ↓
                              前端渲染 + 顶部显示"🏪 官方旗舰店筛选中" Toggle
```

---

## 模块二：搜索页美化

### 设计 Token 调整
- Placeholder 颜色：`tertiaryTextColor` → `secondaryTextColor`
- Placeholder 字号：14 → 15
- 热门标签字号：13 → 14
- 搜索框聚焦边框：增加品牌色渐变发光（`brandColor` → `primaryDark`）

### 新增功能
1. **最近搜索**：使用 `SharedPreferences` 存储最近 10 条搜索记录，显示在热门搜索上方
2. **动效**：
   - 搜索框：从顶部 `Offset(0, -20)` 滑入，300ms `easeEntrance`
   - 热门标签：stagger 淡入，80ms 间隔
   - 搜索提示卡片：依次从下方 30px 滑入 + 淡入
   - 标签点击：`scale 0.95 → 1.0`，150ms `easeSpring`
3. **搜索中状态**：搜索框右侧显示品牌青脉冲圆点（复用 scan_line_overlay 圆点样式）

---

## 模块三：决策卡片稳定性

### Prompt 优化（prompt_engine.py）
`chat_reply` Prompt 重写策略：
1. 增加 3 组 Few-shot 示例（分别触发 none/report/trend）
2. action 触发规则结构化：
   - 用户消息包含"对比"、"比较"、"哪个好"、"推荐"、"决策"、"报告" → `action="report"`
   - 用户消息包含"走势"、"历史价格"、"涨跌"、"趋势" → `action="trend"`
   - 其他 → `action="none"`
3. `current_product` 提取规则：如果对话中提到具体商品名，必须回填 name/brand/category/price

### 前端兜底（chat_screen.dart）
```dart
// 收到 LLM 响应后
String action = response['action'] ?? 'none';
if (action == 'none' && _containsReportKeywords(userMessage)) {
  action = 'report'; // 强制触发决策卡片
}
```

关键词列表：`['对比', '比较', '哪个好', '哪个更好', '推荐', '决策', '报告', '帮我选']`

---

## 模块四：VLM Prompt 调优

### VLM Prompt 重写
原 Prompt："请详细描述这张图片中的物品，包括品牌、品类、颜色、材质、款式等关键信息。"

新 Prompt：
```
你是一位专业的商品识别专家。请观察图片并提取以下信息，按固定格式输出：

品牌：（如果能识别出品牌logo或文字，填写品牌名；否则写"未知"）
品类：（如运动鞋、手机、口红等，必须填写）
颜色：（主色调，如纯白色、黑色、红色等）
材质：（如皮革、棉、金属、塑料等，无法识别写"未知"）
款式：（如低帮板鞋、连衣裙、无线耳机等）

约束：
- 每个字段单独一行，格式严格为"字段名：内容"
- 如果无法识别某个字段，明确写"未知"，不要猜测
- 不要输出任何解释性文字，只输出上述5行

示例1（完整识别）：
品牌：Nike
品类：运动鞋
颜色：纯白色
材质：皮革
款式：低帮板鞋

示例2（部分未知）：
品牌：未知
品类：手提包
颜色：黑色
材质：未知
款式：单肩包
```

### LLM 解析容错（recognition.py）
```python
async def recognize(self, image_base64: str) -> RecognizeResponse:
    description = await self.vlm_client.describe_image(image_base64)
    prompt = PromptEngine.recognize(description)
    messages = [{"role": "user", "content": prompt}]
    
    # 第一次尝试
try:
        result = await self.llm_client.chat_json(messages, temperature=0.3)
    except Exception:
        # 第二次尝试，降低 temperature 提高确定性
        result = await self.llm_client.chat_json(messages, temperature=0.1)
    
    return RecognizeResponse(...)
```

---

## 模块五：AI 导购对话优化

### 对话摘要机制（chat.py）
当对话超过 6 轮（3 轮问答）时，自动调用 LLM 生成摘要：
```python
if len(context) > 12:  # 6轮 = 12条消息
    summary = await self._summarize_context(context)
    context = [
        {"role": "system", "content": f"历史对话摘要：{summary}"},
        *context[-4:],  # 保留最近2轮完整对话
    ]
```

### 会话持久化（chat.py）
```python
import json
import os

SESSION_DIR = "data/sessions"

async def _save_session(self, session_id: str, context: list):
    os.makedirs(SESSION_DIR, exist_ok=True)
    with open(f"{SESSION_DIR}/{session_id}.json", "w", encoding="utf-8") as f:
        json.dump(context, f, ensure_ascii=False)

async def _load_session(self, session_id: str) -> list:
    path = f"{SESSION_DIR}/{session_id}.json"
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return []
```

### Prompt 风格优化
在 `chat_reply` Prompt 中增加角色设定：
> "你是一位热情专业的购物顾问，名叫'小价'。语气亲切自然，像朋友聊天一样。避免机械感，适当使用 emoji。如果你推荐的商品与当前关注的商品不同，请说明推荐理由。"

---

## 模块六：Mock 数据扩充

### 现有品类加深
| 品类 | 新增商品 |
|------|----------|
| 运动鞋 | Adidas Samba OG、Nike Air Max 95、New Balance 550、李宁驭帅18、安踏狂潮6 +10款 |
| 数码 | MacBook Air M3、iPad mini 6、华为 FreeBuds Pro 3、小米手环9、罗技 G304 +8款 |
| 美妆 | 雅诗兰黛小棕瓶、兰蔻粉水、SK-II 神仙水、YSL 恒久粉底液 +7款 |
| 家居 | 宜家 LACK 茶几、MUJI 香薰机、网易严选乳胶枕 +5款 |

### 全新品类（各 10-15 款）
| 品类 | 示例商品 |
|------|----------|
| 食品 | 三只松鼠坚果礼盒、元气森林气泡水、Swisse 维C泡腾片、良品铺子肉脯 |
| 图书 | 《三体》全集、《深入理解计算机系统》、《小王子》、《活着》 |
| 母婴 | 爱他美奶粉、花王纸尿裤、贝亲奶瓶、好孩子婴儿车 |
| 宠物 | 皇家猫粮、渴望狗粮、pidan 猫砂、小佩饮水机 |

总计约 195 条基础数据 × 3 平台 = **~585 条** 商品。

---

## 错误处理策略

| 场景 | 处理方式 |
|------|----------|
| LLM API 超时 | 前端显示"网络较慢，请重试"；后端返回 fallback 数据 |
| LLM 返回非 JSON | 尝试清洗 markdown 代码块后解析；失败则返回 fallback |
| 会话文件读写失败 | 降级到内存存储，记录 warning 日志 |
| SharedPreferences 读写失败 | 降级到空列表，不影响搜索功能 |
| filterMode 传入非法值 | 后端忽略，返回全部数据 |

---

## 测试策略

1. **单元测试**：后端 `comparison.py` 的 tag 过滤和相似度匹配逻辑
2. **集成测试**：
   - 官方/相似推荐端到端流程（ResultScreen → CompareScreen）
   - 搜索页历史记录读写
   - Chat 会话持久化
3. **Prompt 测试**：用 3-5 张不同商品图片测试 VLM 识别准确率
4. **真机测试**：修复完成后完整走一遍 拍照→识别→比价→官方/相似→趋势→报告→分享 链路

---

## 文件清单

### 修改文件（12个）
- `android-app/lib/screens/result_screen.dart`
- `android-app/lib/screens/compare_screen.dart`
- `android-app/lib/screens/search_screen.dart`
- `android-app/lib/screens/chat_screen.dart`
- `android-app/lib/services/api_service.dart`
- `android-app/lib/utils/constants.dart`
- `backend/app/services/comparison.py`
- `backend/app/core/prompt_engine.py`
- `backend/app/core/vlm_client.py`
- `backend/app/services/recognition.py`
- `backend/app/services/chat.py`
- `backend/app/models/schemas.py`（可能新增字段）

### 新增文件（1个）
- `android-app/lib/widgets/search_history_chip.dart`（搜索历史标签组件）
