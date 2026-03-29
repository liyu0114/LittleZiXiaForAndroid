---
name: nearby_search
description: 搜索附近的餐厅、加油站、景点等
---

# 附近搜索 Skill

## 功能
基于当前位置搜索附近的设施和服务。

## 使用方法

### 通过 LLM
```markdown
用户：附近有什么好吃的
助手：让我为您搜索附近的餐厅...
```

## 参数
- `type` (string): 搜索类型（restaurant/gas_station/hospital/atm等）
- `radius` (int): 搜索半径（米，默认1000）

## 示例
- "附近有什么好吃的"
- "找最近的加油站"
- "附近的医院在哪里"

## 实现状态
✅ 已实现（需要 L2 位置权限）
