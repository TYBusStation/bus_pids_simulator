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
        # polyline.decode 回傳 (lat, lon)，WKT 標準通常是 (lon lat)
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

    print(f"2. 共找到 {len(route_edges)} 條路線，開始抓取並處理詳細資料...")

    for index, edge in enumerate(route_edges):
        node = edge['node']
        route_id = node['id']
        route_name = node['name']

        try:
            int_id = int(route_id)
        except ValueError:
            continue

        print(f"[{index + 1}/{len(route_edges)}] 處理中: {route_name} (ID: {route_id})")

        # 抓取詳細資料
        detail_resp = fetch_graphql(QUERY_ROUTE_DETAIL, {"routeId": int_id, "lang": "zh"})

        if detail_resp and 'data' in detail_resp and detail_resp['data']['route']:
            route_detail = detail_resp['data']['route']

            # --- 處理路徑 (Path) 轉 WKT ---
            path_data = route_detail.get('routePoint', {"go": "", "back": ""})
            wkt_path = {
                "go": encoded_to_wkt(path_data.get("go", "")),
                "back": encoded_to_wkt(path_data.get("back", ""))
            }

            # --- 處理站點 (Stations) 分類與排序 ---
            stations_map = {"go": [], "back": []}

            if 'stations' in route_detail and 'edges' in route_detail['stations']:
                for s_edge in route_detail['stations']['edges']:
                    s_node = s_edge['node']
                    station_info = {
                        "order": s_edge['orderNo'],
                        "name": s_node['name'],
                        "lat": s_node['lat'],
                        "lon": s_node['lon']
                    }

                    # 根據 goBack 欄位分類 (通常 1 為去程, 2 為回程)
                    direction = s_edge['goBack']
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

        # 延遲避免被伺服器阻擋
        time.sleep(0.1)

    # --- 儲存檔案 ---
    output_file = "taichung_routes_final.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(final_results, f, ensure_ascii=False, indent=4)

    print(f"\n任務完成！最終資料已寫入 {output_file}")


if __name__ == "__main__":
    main()
