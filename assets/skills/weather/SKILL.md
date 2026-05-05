---
name: weather
description: "查询指定城市的天气"
---

# Weather Skill

查询指定城市的天气信息。

## 使用方法

```markdown
用户：北京今天天气怎么样
助手：正在查询北京天气...
```

## 指令

```http
GET https://wttr.in/{location}?format=3&lang=zh
```

注意：添加 `lang=zh` 参数确保返回中文结果。

## 示例
- "北京天气"
- "上海今天天气"
- "广州天气怎么样"

## 实现状态
✅ 已实现
