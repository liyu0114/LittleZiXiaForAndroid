---
name: web_search
description: 搜索网页信息（使用 Brave Search API）
---

# 网页搜索 Skill

## 功能
使用 Brave Search API 搜索网页信息。

## 使用方法

### 1. 通过 LLM 直接搜索（推荐）
```markdown
用户：搜索最新的 AI 新闻
助手：好的，让我为您搜索...
```

### 2. 通过 HTTP API（备用）
```http
GET https://api.search.brave.com/res/v1/web/search
Authorization: Bearer YOUR_API_KEY
Query: q={query}
```

## 参数
- `query` (string): 搜索关键词

## 示例
- "搜索 Python 教程"
- "查一下 OpenAI 的最新动态"
- "找一下 Flutter 开发文档"

## 实现状态
✅ 已实现（通过 app_state.dart 中的 `_executeWebSearchSkill`）
