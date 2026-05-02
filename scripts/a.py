import requests
import json
import time

# 設定目標 URL (根據 Dart 代碼推測的 GraphQL 終點)
# 桃園公車 GraphQL 接口通常為此網址
GRAPHQL_URL = "https://ebus.tycg.gov.tw/ebus/graphql"

# GraphQL Query 語法
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
    """通用 GraphQL 請求函數"""
    payload = {
        "variables": variables,
        "query": query
    }
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

def main():
    print("正在獲取所有營運路線清單...")
    routes_resp = fetch_graphql(QUERY_ROUTES, {"lang": "zh"})

    if not routes_resp or 'data' not in routes_resp:
        print("無法取得路線清單。")
        return

    route_edges = routes_resp['data']['routes']['edges']
    all_results = []

    print(f"共找到 {len(route_edges)} 條路線，開始抓取詳細資料...")

    for index, edge in enumerate(route_edges):
        node = edge['node']
        route_id = node['id']
        route_name = node['name']

        # GraphQL 要求的 routeId 通常是整數
        try:
            int_id = int(route_id)
        except ValueError:
            continue

        print(f"[{index + 1}/{len(route_edges)}] 正在抓取: {route_name} (ID: {route_id})")

        # 抓取詳細站點與路徑
        detail_resp = fetch_graphql(QUERY_ROUTE_DETAIL, {"routeId": int_id, "lang": "zh"})

        if detail_resp and 'data' in detail_resp and detail_resp['data']['route']:
            route_detail = detail_resp['data']['route']

            # 整合資料
            result = {
                "id": route_id,
                "name": route_name,
                "description": node.get('description'),
                "departure": node.get('departure'),
                "destination": node.get('destination'),
                "path": route_detail.get('routePoint'), # 包含 go 與 back 的坐標字串
                "stations": []
            }

            # 處理站點資料
            if 'stations' in route_detail and 'edges' in route_detail['stations']:
                for s_edge in route_detail['stations']['edges']:
                    result["stations"].append({
                        "direction": s_edge['goBack'], # 0: 去程, 1: 回程
                        "order": s_edge['orderNo'],
                        "name": s_edge['node']['name'],
                        "lat": s_edge['node']['lat'],
                        "lon": s_edge['node']['lon']
                    })

            all_results.append(result)
        else:
            print(f"  - 警告: 無法取得 {route_name} 的詳細資料")

        # 稍微延遲避免被封鎖
        time.sleep(0.2)

    # 寫入 JSON 檔案
    output_file = "taoyuan_routes.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(all_results, f, ensure_ascii=False, indent=4)

    print(f"\n抓取完成！資料已寫入 {output_file}")

if __name__ == "__main__":
    main()