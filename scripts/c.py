import json
import polyline


def convert_to_linestring(encoded_str):
    """將 Polyline 加密字串轉換為 LINESTRING (lon lat, ...) 格式"""
    if not encoded_str:
        return ""
    # polyline.decode 回傳的是 (lat, lon)
    coords = polyline.decode(encoded_str)
    # 轉換成 "lon lat" 字串
    points = [f"{lon} {lat}" for lat, lon in coords]
    return f"LINESTRING ({', '.join(points)})"


def process_stations(edges, direction):
    """
    處理站點資料
    direction: 1 為 'go' (去程), 2 為 'back' (回程)
    """
    result = []
    # 過濾出對應方向的站點
    filtered_edges = [e for e in edges if e['goBack'] == direction]
    # 依照 orderNo 排序
    sorted_edges = sorted(filtered_edges, key=lambda x: x['orderNo'])

    for edge in sorted_edges:
        node = edge['node']
        result.append({
            "order": edge['orderNo'],
            "name": node['name'],
            "lat": node['lat'],
            "lon": node['lon']
        })
    return result


def main():
    # 1. 讀取原始資料 (假設檔名分別為 routes.json 和 details.json)
    try:
        with open('op_route_data_p.json', 'r', encoding='utf-8') as f:
            routes_list = json.load(f)
        with open('route_details_p.json', 'r', encoding='utf-8') as f:
            details_dict = json.load(f)
    except FileNotFoundError:
        print("請確保 routes.json 和 details.json 檔案存在。")
        return

    final_result = []

    # 2. 開始組合資料
    for route in routes_list:
        nid = route.get('nid')

        # 如果詳細資料中沒有對應的 nid，則跳過或保留基本資訊
        if nid not in details_dict:
            continue

        detail = details_dict[nid]
        route_point = detail.get('routePoint', {})
        stations_data = detail.get('stations', {}).get('edges', [])

        # 建立目標結構
        combined_data = {
            "id": route.get('id'),
            "name": route.get('name'),
            "description": route.get('description'),
            "departure": route.get('departure'),
            "destination": route.get('destination'),
            "path": {
                "go": convert_to_linestring(route_point.get('go')),
                "back": convert_to_linestring(route_point.get('back'))
            },
            "stations": {
                "go": process_stations(stations_data, 1),
                "back": process_stations(stations_data, 2)
            }
        }

        final_result.append(combined_data)

    # 3. 輸出結果
    with open('output.json', 'w', encoding='utf-8') as f:
        json.dump(final_result, f, ensure_ascii=False, indent=4)

    print(f"轉換完成，已生成 output.json，共處理 {len(final_result)} 條路線。")


if __name__ == "__main__":
    main()
