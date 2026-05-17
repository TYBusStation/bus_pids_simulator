import json
import polyline
import re

CITY = "Taichung"
# --- 設定讀取的檔名 ---
DATA_FILE = f'{CITY}_data.json'
ROUTE_FILE = f'{CITY}_route.json'
STOP_FILE = f'{CITY}_stop.json'
OUTPUT_FILE = f'{CITY}.json'


def process_geometry(geo_input):
    """
    處理幾何資訊：
    1. 如果是 LINESTRING 格式則直接回傳。
    2. 如果是加密 Polyline 則解碼為 LINESTRING。
    """
    if not geo_input:
        return ""

    # 檢查是否已經是 LINESTRING 格式
    if geo_input.strip().upper().startswith("LINESTRING"):
        # 標準化格式：確保中間是逗號分隔 (有些原始資料空格較亂)
        return geo_input.strip()

    try:
        # 嘗試解碼 Polyline (回傳為 [(lat, lon), ...])
        coords = polyline.decode(geo_input)
        wkt_points = [f"{lon} {lat}" for lat, lon in coords]
        return f"LINESTRING({','.join(wkt_points)})"
    except Exception:
        return ""


def main():
    # 1. 讀取檔案
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

    # 整合結果 (Key: SubRouteUID)
    merged_results = {}
    # 建立 RouteUID -> [SubRouteUID] 的索引
    route_to_subs = {}

    print("Step 1: 處理基礎資訊 (data.json)...")
    for item in data_list:
        ruid = item.get("RouteUID")
        dep = item.get("DepartureStopNameZh", "")
        dest = item.get("DestinationStopNameZh", "")

        if ruid and ruid not in route_to_subs:
            route_to_subs[ruid] = []

        for sub in item.get("SubRoutes", []):
            suid = sub.get("SubRouteUID")
            if not suid: continue

            if ruid:
                route_to_subs[ruid].append(suid)

            # 初始化結構
            merged_results[suid] = {
                "id": suid,
                "name": sub.get("SubRouteName", {}).get("Zh_tw", ""),
                "description": sub.get("Headsign", "") or f"{dep} - {dest}",
                "departure": dep,
                "destination": dest,
                "path": {"go": "", "back": ""},
                "stations": {"go": [], "back": []}
            }

    def get_target_suids(obj):
        """根據 SubRouteUID 或 RouteUID 找到對應的所有子路線 UID"""
        suid = obj.get("SubRouteUID")
        ruid = obj.get("RouteUID")

        # 優先匹配 SubRouteUID
        if suid in merged_results:
            return [suid]
        # 匹配不到時，改匹配 RouteUID 下的所有子路線
        elif ruid in route_to_subs:
            return route_to_subs[ruid]
        return []

    print("Step 2: 轉換軌跡資訊 (route.json)...")
    for r in route_list:
        direction = r.get("Direction")
        dir_key = "go" if direction == 0 else "back"
        # 處理 Geometry (相容 WKT 與 Polyline)
        wkt_line = process_geometry(r.get("Geometry") or r.get("EncodedPolyline"))

        for target_id in get_target_suids(r):
            merged_results[target_id]["path"][dir_key] = wkt_line

    print("Step 3: 處理站點資訊 (stop.json)...")
    for s_group in stop_list:
        direction = s_group.get("Direction")
        dir_key = "go" if direction == 0 else "back"

        station_details = []
        for s in s_group.get("Stops", []):
            name_obj = s.get("StopName", {})
            pos = s.get("StopPosition", {})
            station_details.append({
                "order": s.get("StopSequence"),
                "name": name_obj.get("Zh_tw", ""),
                "name_en": name_obj.get("En", ""),
                "lat": pos.get("PositionLat"),
                "lon": pos.get("PositionLon")
            })

        # 排序
        station_details.sort(key=lambda x: x["order"] if x["order"] is not None else 0)

        for target_id in get_target_suids(s_group):
            merged_results[target_id]["stations"][dir_key] = station_details

    # 4. 產出
    final_output = [merged_results[k] for k in sorted(merged_results.keys())]

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=4)

    print(f"\n✅ 處理完成！產出檔案：{OUTPUT_FILE}")
    print(f"處理子路線總數：{len(final_output)}")


if __name__ == "__main__":
    main()
