import json
import polyline
import requests
import time

# --- 設定與常量 ---
GRAPHQL_URL = "https://citybus.taichung.gov.tw//ebus/graphql"

QUERY_ROUTES = """
query QUERY_ROUTES($lang: String!) {
  routes(lang: $lang) {
    edges {
      node {
        id
        name
        description
        departure
        destination
      }
    }
  }
}
"""

QUERY_ROUTE_DETAIL = """
query QUERY_ROUTE_DETAIL($routeId: Int!, $lang: String!) {
  route(xno: $routeId, lang: $lang) {
    id
    name
    routePoint {
      go
      back
    }
    stations {
      edges {
        goBack
        orderNo
        node {
          name
          lat
          lon
        }
      }
    }
  }
}
"""


def fetch_graphql(query, variables):
    """發送 GraphQL 請求"""
    payload = {"variables": variables, "query": query}
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    try:
        response = requests.post(GRAPHQL_URL, json=payload, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"請求失敗，狀態碼: {response.status_code}")
            return None
    except Exception as e:
        print(f"發生錯誤: {e}")
        return None


def encoded_to_wkt(encoded_str):
    """將 Polyline 編碼字串轉換為 WKT LINESTRING 格式"""
    if not encoded_str:
        return ""
    try:
        coords = polyline.decode(encoded_str)
        wkt_points = [f"{lon} {lat}" for lat, lon in coords]
        return f"LINESTRING ({', '.join(wkt_points)})"
    except Exception:
        return ""


def main():
    print("1. 正在獲取所有營運路線清單...")
    routes_resp = fetch_graphql(QUERY_ROUTES, {"lang": "zh"})

    if not routes_resp or 'data' not in routes_resp:
        print("無法取得路線清單。")
        return

    route_edges = routes_resp['data']['routes']['edges']
    final_results = []

    print(f"2. 共找到 {len(route_edges)} 條路線，開始抓取中英文詳細資料...")

    for index, edge in enumerate(route_edges):
        node = edge['node']
        route_id = node['id']
        route_name = node['name']

        try:
            int_id = int(route_id)
        except ValueError:
            continue

        print(f"[{index + 1}/{len(route_edges)}] 處理中: {route_name} (ID: {route_id})")

        # --- 抓取中文詳細資料 ---
        detail_resp_zh = fetch_graphql(QUERY_ROUTE_DETAIL, {"routeId": int_id, "lang": "zh"})
        # --- 額外抓取英文詳細資料 ---
        detail_resp_en = fetch_graphql(QUERY_ROUTE_DETAIL, {"routeId": int_id, "lang": "en"})

        if detail_resp_zh and 'data' in detail_resp_zh and detail_resp_zh['data']['route']:
            route_detail_zh = detail_resp_zh['data']['route']

            # 建立英文站名對照表 {(goBack, orderNo): EnglishName}
            en_station_map = {}
            if detail_resp_en and 'data' in detail_resp_en and detail_resp_en['data']['route']:
                en_stations = detail_resp_en['data']['route'].get('stations', {}).get('edges', [])
                for s_edge_en in en_stations:
                    key = (s_edge_en['goBack'], s_edge_en['orderNo'])
                    en_station_map[key] = s_edge_en['node']['name']

            # --- 處理路徑 (Path) 轉 WKT ---
            path_data = route_detail_zh.get('routePoint', {"go": "", "back": ""})
            wkt_path = {
                "go": encoded_to_wkt(path_data.get("go", "")),
                "back": encoded_to_wkt(path_data.get("back", ""))
            }

            # --- 處理站點 (Stations) 分類與排序 ---
            stations_map = {"go": [], "back": []}

            if 'stations' in route_detail_zh and 'edges' in route_detail_zh['stations']:
                for s_edge in route_detail_zh['stations']['edges']:
                    s_node = s_edge['node']
                    direction = s_edge['goBack']
                    order = s_edge['orderNo']

                    # 獲取對應的英文名稱
                    name_en = en_station_map.get((direction, order), "")

                    station_info = {
                        "order": order,
                        "name": s_node['name'],
                        "name_en": name_en,  # 放入與 name 同級的欄位
                        "lat": s_node['lat'],
                        "lon": s_node['lon']
                    }

                    if direction == 1:
                        stations_map["go"].append(station_info)
                    elif direction == 2:
                        stations_map["back"].append(station_info)

                # 確保排序正確
                stations_map["go"].sort(key=lambda x: x['order'])
                stations_map["back"].sort(key=lambda x: x['order'])

            # --- 整合最終結構 ---
            result = {
                "id": route_id,
                "name": route_name,
                "description": node.get('description'),
                "departure": node.get('departure'),
                "destination": node.get('destination'),
                "path": wkt_path,
                "stations": stations_map
            }

            final_results.append(result)
        else:
            print(f"  - 警告: 無法取得 {route_name} 的詳細資料")

        # 延遲避免被伺服器阻擋 (因為現在每條線要打兩次 API，建議維持或稍微增加延遲)
        time.sleep(0.1)

    # --- 儲存檔案 ---
    output_file = "taichung_routes_with_en.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(final_results, f, ensure_ascii=False, indent=4)

    print(f"\n任務完成！資料已寫入 {output_file}")


if __name__ == "__main__":
    main()
