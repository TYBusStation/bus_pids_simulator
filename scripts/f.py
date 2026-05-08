import json

CITY = "Taipei"


def process_city_bus_data():
    # 設定讀取的檔名
    DATA_FILE = CITY + '_data.json'
    ROUTE_FILE = CITY + '_route.json'
    STOP_FILE = CITY + '_stop.json'
    OUTPUT_FILE = CITY + '.json'

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
    except json.JSONDecodeError as e:
        print(f"錯誤: JSON 格式有誤 ({e})")
        return

    # 整合資料的字典
    merged_results = {}
    # 建立 RouteID 與 SubRouteID 的映射關係，處理「找不到 SubRouteID 時改找 RouteID」的需求
    route_to_subs = {}

    print("Step 1: 處理基礎資訊 (Data)...")
    for item in data_list:
        route_id_main = item.get("RouteID")
        departure_main = item.get("DepartureStopNameZh", "")
        destination_main = item.get("DestinationStopNameZh", "")

        if route_id_main not in route_to_subs:
            route_to_subs[route_id_main] = []

        # 遍歷附屬路線 SubRoutes
        for sub in item.get("SubRoutes", []):
            sid = sub.get("SubRouteID")
            if not sid:
                continue

            # 建立 RouteID 對應 SubRouteID 的索引
            route_to_subs[route_id_main].append(sid)

            # 初始化結構
            merged_results[sid] = {
                "id": str(sid),
                "route_id": route_id_main,  # 暫存以便追蹤
                "name": sub.get("SubRouteName", {}).get("Zh_tw", ""),
                "description": sub.get("Headsign", ""),
                "departure": departure_main,
                "destination": destination_main,
                "path": {"go": "", "back": ""},
                "stations": {"go": [], "back": []}
            }

    print("Step 2: 處理軌跡資訊 (Route)...")
    for r in route_list:
        sid = r.get("SubRouteID")
        rid = r.get("RouteID")
        direction = r.get("Direction")
        geometry = r.get("Geometry", "")

        # 決定要更新哪些 SubRouteID
        target_sids = []
        if sid in merged_results:
            target_sids = [sid]
        elif rid in route_to_subs:
            # 如果 SubRouteID 找不到，嘗試用 RouteID 找回其下所有的 SubRoutes
            target_sids = route_to_subs[rid]

        for target_id in target_sids:
            if direction == 0:
                merged_results[target_id]["path"]["go"] = geometry
            elif direction == 1:
                merged_results[target_id]["path"]["back"] = geometry

    print("Step 3: 處理站點資訊 (Stop)...")
    for s_group in stop_list:
        sid = s_group.get("SubRouteID")
        rid = s_group.get("RouteID")
        direction = s_group.get("Direction")
        dir_key = "go" if direction == 0 else "back"

        station_details = []
        for s in s_group.get("Stops", []):
            stop_name_obj = s.get("StopName", {})
            pos = s.get("StopPosition", {})
            station_details.append({
                "order": s.get("StopSequence"),
                "name": stop_name_obj.get("Zh_tw", ""),
                "name_en": stop_name_obj.get("En", ""),
                "lat": pos.get("PositionLat"),
                "lon": pos.get("PositionLon")
            })
        station_details.sort(key=lambda x: x["order"] if x["order"] is not None else 0)

        # 決定要更新哪些 SubRouteID
        target_sids = []
        if sid in merged_results:
            target_sids = [sid]
        elif rid in route_to_subs:
            target_sids = route_to_subs[rid]

        for target_id in target_sids:
            # 避免重複填入（如果該 SubRoute 已經有資料了可自行決定是否覆蓋）
            merged_results[target_id]["stations"][dir_key] = station_details

    # 移除暫存用的 route_id 並轉換為 List
    final_output = []
    for res in merged_results.values():
        res.pop("route_id", None)  # 移除中間變數
        final_output.append(res)

    # 儲存結果
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=4)

    print(f"\n✅ 處理完成！")
    print(f"產出檔案：{OUTPUT_FILE}")
    print(f"總共處理路線數：{len(final_output)}")


if __name__ == "__main__":
    process_city_bus_data()
