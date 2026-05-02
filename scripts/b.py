import json


def process_bus_data(input_file, output_file):
    try:
        # 讀取原始 JSON 資料
        with open(input_file, 'r', encoding='utf-8') as f:
            routes = json.load(f)

        processed_routes = []

        for route in routes:
            # 初始化 stations map 結構
            stations_map = {
                "go": [],
                "back": []
            }

            # 遍歷原始站點並分類到 go 或 back
            for station in route.get('stations', []):
                # 複製資料，移除 direction 欄位
                s_data = {k: v for k, v in station.items() if k != 'direction'}

                direction = station.get('direction')
                if direction == 1:
                    stations_map["go"].append(s_data)
                elif direction == 2:
                    stations_map["back"].append(s_data)

            # 確保站點按照 order 排序
            stations_map["go"].sort(key=lambda x: x['order'])
            stations_map["back"].sort(key=lambda x: x['order'])

            # 建立新的路線資料結構
            new_route = {
                "id": route.get("id"),
                "name": route.get("name"),
                "description": route.get("description"),
                "departure": route.get("departure"),
                "destination": route.get("destination"),
                "path": route.get("path"),
                "stations": stations_map  # 這裡改成 Map 結構
            }
            processed_routes.append(new_route)

        # 寫入新的 JSON 檔案
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(processed_routes, f, ensure_ascii=False, indent=4)

        print(f"處理完成！已將資料存至: {output_file}")

    except Exception as e:
        print(f"發生錯誤: {e}")


if __name__ == "__main__":
    input_filename = "taoyuan_routes.json"
    output_filename = "taoyuan_routes_v2.json"

    process_bus_data(input_filename, output_filename)
