import json

CITY = "InterCity"


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

    # 建立一個以 SubRouteID 為 Key 的字典來整合資料
    merged_results = {}

    print("Step 1: 處理基礎資訊 (Data)...")
    for item in data_list:
        # 主路線資訊
        departure_main = item.get("DepartureStopNameZh", "")
        destination_main = item.get("DestinationStopNameZh", "")

        # 遍歷附屬路線 SubRoutes
        for sub in item.get("SubRoutes", []):
            rid = sub.get("SubRouteID")
            if not rid:
                continue

            # 初始化結構
            merged_results[rid] = {
                "id": str(rid),  # SubRouteID => id
                "name": sub.get("SubRouteName", {}).get("Zh_tw", ""),  # SubRouteName => name
                "description": sub.get("Headsign", ""),  # headsign => description
                "departure": departure_main,
                "destination": destination_main,
                "path": {"go": "", "back": ""},
                "stations": {"go": [], "back": []}
            }

    print("Step 2: 處理軌跡資訊 (Route)...")
    for r in route_list:
        # 使用 .get 避免 KeyError
        rid = r.get("SubRouteID")
        if rid in merged_results:
            direction = r.get("Direction")
            geometry = r.get("Geometry", "")

            if direction == 0:
                merged_results[rid]["path"]["go"] = geometry
            elif direction == 1:
                merged_results[rid]["path"]["back"] = geometry

    print("Step 3: 處理站點資訊 (Stop)...")
    for s_group in stop_list:
        rid = s_group.get("SubRouteID")
        if rid in merged_results:
            direction = s_group.get("Direction")
            dir_key = "go" if direction == 0 else "back"

            station_details = []
            for s in s_group.get("Stops", []):
                stop_name_obj = s.get("StopName", {})
                pos = s.get("StopPosition", {})

                stop_info = {
                    "order": s.get("StopSequence"),
                    "name": stop_name_obj.get("Zh_tw", ""),
                    "name_en": stop_name_obj.get("En", ""),  # 放入與 name 同級
                    "lat": pos.get("PositionLat"),
                    "lon": pos.get("PositionLon")
                }
                station_details.append(stop_info)

            # 確保按照 StopSequence 排序
            station_details.sort(key=lambda x: x["order"] if x["order"] is not None else 0)
            merged_results[rid]["stations"][dir_key] = station_details

    # 將字典轉換回 List 格式
    final_output = list(merged_results.values())

    # 儲存結果
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=4)

    print(f"\n✅ 處理完成！")
    print(f"產出檔案：{OUTPUT_FILE}")
    print(f"總共處理路線數：{len(final_output)}")


if __name__ == "__main__":
    process_city_bus_data()
