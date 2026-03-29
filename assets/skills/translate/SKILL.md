---
name: translate
description: 翻译文本到指定语言
---

# 翻译 Skill

## 功能
使用大模型进行多语言翻译。

## 使用方法

### 通过 LLM 翻译
```markdown
用户：把"Hello World"翻译成中文
助手：好的，翻译结果：你好世界
```

## 参数
- `text` (string): 要翻译的文本
- `target_lang` (string): 目标语言（默认：en）

## 支持的语言
- 中文 (zh)
- 英语 (en)
- 日语 (ja)
- 韩语 (ko)
- 法语 (fr)
- 德语 (de)
- 西班牙语 (es)
- 俄语 (ru)

## 示例
- "把这句话翻译成英文：你好世界"
- "翻译成日语：早上好"
- "How are you 翻译成中文"

## 实现状态
✅ 已实现（通过 app_state.dart 中的 `_executeTranslateSkill`）
