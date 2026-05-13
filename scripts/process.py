import json
import os
import polyline
import re

# --- 設定讀取的檔名 (請根據您的實際檔名修改) ---
DATA_FILE = 'Taoyuan_data.json'  # 包含路線基本資訊
ROUTE_FILE = 'Taoyuan_route.json'  # 包含 Geometry (Polyline)
STOP_FILE = 'Taoyuan_stop_raw.json'  # 包含 Stops 資訊 (避免與輸出檔名衝突，暫稱 raw)
OUTPUT_FILE = 'Taoyuan_stop.json'


def polyline_to_wkt(encoded_str):
    """將 Polyline 加密字串轉換為 WKT LINESTRING (lon lat) 格式"""
    if not encoded_str:
        return ""
    try:
        # polyline.decode 回傳的是 (lat, lon)
        coords = polyline.decode(encoded_str)
        # 轉換成 "lon lat" 並以逗號分隔
        wkt_points = [f"{lon} {lat}" for lat, lon in coords]
        return f"LINESTRING({','.join(wkt_points)})"
    except Exception:
        return ""


def main():
    # 1. 讀取三個原始檔案
    try:
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            data_list = json.load(f)
        with open(ROUTE_FILE, 'r', encoding='utf-8') as f:
            route_list = json.load(f)
        with open(STOP_FILE, 'r', encoding='utf-8') as f:
            stop_list = json.load(f)
    except FileNotFoundError as e:
        print(f"錯誤: 找不到檔案 {e.filename}")
        return

    # 整合結果的字典
    merged_results = {}
    # 建立 RouteID 對應 SubRouteID 的索引 (用於 Step 2 & 3 的匹配)
    route_to_subs = {}

    print("Step 1: 處理路線基礎資訊 (Data)...")
    for item in data_list:
        route_id_main = item.get("RouteID")
        departure_main = item.get("DepartureStopNameZh", "")
        destination_main = item.get("DestinationStopNameZh", "")

        if route_id_main not in route_to_subs:
            route_to_subs[route_id_main] = []

        for sub in item.get("SubRoutes", []):
            sid = sub.get("SubRouteID")
            if not sid: continue

            route_to_subs[route_id_main].append(sid)

            # 初始化您要求的 JSON 結構
            merged_results[sid] = {
                "id": str(sid),
                "route_id": route_id_main,  # 暫存用於匹配
                "name": sub.get("SubRouteName", {}).get("Zh_tw", ""),
                "description": sub.get("Headsign", "") or f"{departure_main} - {destination_main}",
                "departure": departure_main,
                "destination": destination_main,
                "path": {"go": "", "back": ""},
                "stations": {"go": [], "back": []}
            }

    print("Step 2: 轉換軌跡資訊為 WKT (Route)...")
    for r in route_list:
        sid = r.get("SubRouteID")
        rid = r.get("RouteID")
        direction = r.get("Direction")  # 0: 去程, 1: 回程
        geometry = r.get("Geometry", "")

        # 轉換 Polyline 為 LINESTRING(lon lat)
        wkt_line = polyline_to_wkt(geometry)

        # 尋找目標 SubRouteID
        target_sids = []
        if sid in merged_results:
            target_sids = [sid]
        elif rid in route_to_subs:
            target_sids = route_to_subs[rid]

        for target_id in target_sids:
            if direction == 0:
                merged_results[target_id]["path"]["go"] = wkt_line
            elif direction == 1:
                merged_results[target_id]["path"]["back"] = wkt_line

    print("Step 3: 處理中英文站點資訊 (Stop)...")
    for s_group in stop_list:
        sid = s_group.get("SubRouteID")
        rid = s_group.get("RouteID")
        direction = s_group.get("Direction")  # 0: 去程, 1: 回程
        dir_key = "go" if direction == 0 else "back"

        station_details = []
        for s in s_group.get("Stops", []):
            stop_name_obj = s.get("StopName", {})
            pos = s.get("StopPosition", {})

            station_details.append({
                "order": s.get("StopSequence"),
                "name": stop_name_obj.get("Zh_tw", ""),
                "name_en": stop_name_obj.get("En", ""),  # 這裡會填入英文站名
                "lat": pos.get("PositionLat"),
                "lon": pos.get("PositionLon")
            })

        # 依序號排序
        station_details.sort(key=lambda x: x["order"] if x["order"] is not None else 0)

        target_sids = []
        if sid in merged_results:
            target_sids = [sid]
        elif rid in route_to_subs:
            target_sids = route_to_subs[rid]

        for target_id in target_sids:
            merged_results[target_id]["stations"][dir_key] = station_details

    # 4. 轉換為最終 List 並清理暫存欄位
    final_output = []
    # 依照 ID 排序讓輸出整齊一點
    for sid in sorted(merged_results.keys()):
        res = merged_results[sid]
        res.pop("route_id", None)  # 移除用於匹配的暫存 ID
        final_output.append(res)

    # 5. 儲存結果
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=4)

    print(f"\n✅ 處理完成！產出檔案：{OUTPUT_FILE}")
    print(f"總共處理路線數：{len(final_output)}")


if __name__ == "__main__":
    main()
