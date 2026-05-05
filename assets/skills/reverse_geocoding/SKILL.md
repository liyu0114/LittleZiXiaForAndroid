---
name: reverse_geocoding
description: 将经纬度转换为具体地点名称
---

# 逆地理编码

将经纬度坐标转换为人类可读的地点名称。

## 获取地点名称

```http
GET https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lon}&zoom=18&addressdetails=1
```

## 参数

- `lat`: 纬度
- `lon`: 经度
- `zoom`: 缩放级别（0-18，越大越详细，默认 18）
- `addressdetails`: 是否返回详细地址（1=是，0=否，默认 1）

## 返回示例

```json
{
  "place_id": "123456789",
  "licence": "Data © OpenStreetMap contributors",
  "osm_type": "way",
  "osm_id": "123456789",
  "lat": "39.9042",
  "lon": "116.4074",
  "display_name": "北京市东城区东华门街道, 北京市, 100000, 中国",
  "address": {
    "city": "北京市",
    "state": "北京市",
    "country": "中国",
    "country_code": "cn"
  }
}
```

## 使用场景

- 用户问"我在哪"时，先获取经纬度，再转换为地点名称
- 返回格式："📍 你在：北京市东城区（经纬度：39.9042, 116.4074）"

## 注意

- Nominatim API 有速率限制（1次/秒）
- 建议添加缓存机制
- 需要网络权限
