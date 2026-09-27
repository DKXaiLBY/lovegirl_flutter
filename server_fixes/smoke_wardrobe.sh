#!/bin/bash
set -e
B=http://127.0.0.1:3001/api
A="Authorization: Bearer $TOKEN"
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > /tmp/lg_px.png

echo "== 建三件单品"
mkitem() { curl -s -X POST $B/wardrobe/items -H "$A" -F "image=@/tmp/lg_px.png;type=image/png" -F "category=$1" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
I1=$(mkitem 上装); I2=$(mkitem 裤装); I3=$(mkitem 鞋子)
echo "items: $I1 $I2 $I3"

echo "== 组合(2件, 今天) → 待确认不计"
OID=$(curl -s -X POST $B/wardrobe/outfits -H "$A" -F "source=组合" -F "itemIds=[$I1,$I2]" -F "wornDate=2026-09-27" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "outfit=$OID wear(应0/0): $(curl -s $B/wardrobe/items -H "$A" | grep -o '"wear_count":[0-9]*' | tr '\n' ' ')"

echo "== PATCH 通过 → 1/1"
curl -s -X PATCH $B/wardrobe/outfits/$OID/status -H "$A" -H 'Content-Type: application/json' -d '{"status":"已通过"}' | head -c 60; echo
echo "after+1: $(curl -s $B/wardrobe/items -H "$A" | grep -o '"wear_count":[0-9]*' | tr '\n' ' ')"
echo "== 改回待确认 → 0/0；再通过 → 1/1；幂等重放=200不变"
curl -s -X PATCH $B/wardrobe/outfits/$OID/status -H "$A" -H 'Content-Type: application/json' -d '{"status":"待确认"}' >/dev/null
echo "after-1: $(curl -s $B/wardrobe/items -H "$A" | grep -o '"wear_count":[0-9]*' | tr '\n' ' ')"
curl -s -X PATCH $B/wardrobe/outfits/$OID/status -H "$A" -H 'Content-Type: application/json' -d '{"status":"已通过"}' >/dev/null
curl -s -X PATCH $B/wardrobe/outfits/$OID/status -H "$A" -H 'Content-Type: application/json' -d '{"status":"已通过"}' | head -c 60; echo
echo "after replay: $(curl -s $B/wardrobe/items -H "$A" | grep -o '"wear_count":[0-9]*' | tr '\n' ' ')"

echo "== PUT 换件 [I2,I3] → I1=0 I2=1 I3=1"
curl -s -X PUT $B/wardrobe/outfits/$OID -H "$A" -H 'Content-Type: application/json' -d "{\"itemIds\":[$I2,$I3]}" | head -c 60; echo
echo "after diff: $(curl -s $B/wardrobe/items -H "$A" | grep -o '"id":[0-9]*\|"wear_count":[0-9]*' | tr '\n' ' ')"

echo "== DELETE 组合 → 0/0/0"
curl -s -X DELETE $B/wardrobe/outfits/$OID -H "$A" | head -c 60; echo
echo "after del: $(curl -s $B/wardrobe/items -H "$A" | grep -o '"wear_count":[0-9]*' | tr '\n' ' ')"

echo "== 实拍关联 I1（即已通过 I1=1）；未来日期=400"
OID2=$(curl -s -X POST $B/wardrobe/outfits -H "$A" -F "source=实拍" -F "photo=@/tmp/lg_px.png;type=image/png" -F "wornDate=2026-09-27" -F "itemIds=[$I1]" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "outfit2=$OID2 wear I1: $(curl -s $B/wardrobe/items -H "$A" | grep -o '"wear_count":[0-9]*' | head -1)"
curl -s -o /dev/null -w 'future_http=400实际=%{http_code}\n' -X POST $B/wardrobe/outfits -H "$A" -F "source=实拍" -F "photo=@/tmp/lg_px.png;type=image/png" -F "wornDate=2026-09-28"

echo "== 软删 I1 → 列表 2 件；outfits 摘要带 已删除·上装"
curl -s -X DELETE $B/wardrobe/items/$I1 -H "$A" | head -c 60; echo
echo "items_left(应2): $(curl -s $B/wardrobe/items -H "$A" | grep -o '"id":[0-9]*' | wc -l)"
curl -s $B/wardrobe/outfits -H "$A" | grep -o '"deleted":true,"category":"[^"]*"' | head -1

echo "== bg-status / bg-remove"
curl -s $B/wardrobe/bg-status -H "$A"; echo
curl -s -o /dev/null -w 'bgremove_http=503实际=%{http_code}\n' -X POST $B/wardrobe/bg-remove -H "$A" -F "image=@/tmp/lg_px.png;type=image/png"
echo "OID2_FOR_CLEANUP=$OID2"
echo "SMOKE_DONE"
