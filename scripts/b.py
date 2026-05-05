import aiohttp
import asyncio
import json
import time

# --- 設定與常量 ---
GRAPHQL_URL = "https://ebus.tycg.gov.tw/ebus/graphql"
INPUT_FILE = "taoyuan.json"
OUTPUT_FILE = "taoyuan_routes_with_en.json"
CONCURRENT_REQUESTS = 20  # 同時併發請求數，可依網路狀況調整 (10-30)

QUERY_ROUTE_DETAIL_EN = """
query QUERY_ROUTE_DETAIL($routeId: Int!, $lang: String!) {
  route(xno: $routeId, lang: $lang) {
    stations {
      edges {
        goBack
        orderNo
        node {
          name
        }
      }
    }
  }
}
"""

HEADERS = {
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


async def fetch_graphql_async(session, semaphore, route_id):
    """非同步發送 GraphQL 請求"""
    payload = {
        "variables": {"routeId": int(route_id), "lang": "en"},
        "query": QUERY_ROUTE_DETAIL_EN
    }

    async with semaphore:
        for attempt in range(3):  # 失敗重試 3 次
            try:
                async with session.post(GRAPHQL_URL, json=payload, headers=HEADERS, timeout=15) as response:
                    if response.status == 200:
                        return await response.json()
                    return None
            except Exception:
                await asyncio.sleep(1)
        return None


async def process_route(session, semaphore, route):
    """單一路線處理邏輯"""
    route_id = route['id']

    result = await fetch_graphql_async(session, semaphore, route_id)

    if result and 'data' in result and result['data']['route']:
        en_map = {}
        en_edges = result['data']['route'].get('stations', {}).get('edges', [])
        for edge in en_edges:
            key = (edge['goBack'], edge['orderNo'])
            en_map[key] = edge['node']['name']

        # 填入英文名稱
        for station in route['stations'].get('go', []):
            station['name_en'] = en_map.get((1, station['order']), "")
        for station in route['stations'].get('back', []):
            station['name_en'] = en_map.get((2, station['order']), "")

        print(f"  [完成] {route['name']} (ID: {route_id})")
    else:
        # 失敗處理
        for station in route['stations'].get('go', []): station['name_en'] = ""
        for station in route['stations'].get('back', []): station['name_en'] = ""
        print(f"  [警告] 無法取得 {route['name']} 的英文資料")


async def main():
    # 1. 讀取舊資料
    try:
        with open(INPUT_FILE, "r", encoding="utf-8") as f:
            routes_data = json.load(f)
    except FileNotFoundError:
        print(f"找不到檔案 {INPUT_FILE}")
        return

    print(f"開始併發補抓 {len(routes_data)} 條路線的英文名稱...")
    start_time = time.time()

    # 2. 建立非同步任務
    semaphore = asyncio.Semaphore(CONCURRENT_REQUESTS)
    async with aiohttp.ClientSession() as session:
        tasks = [process_route(session, semaphore, route) for route in routes_data]
        await asyncio.gather(*tasks)

    # 3. 儲存結果
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(routes_data, f, ensure_ascii=False, indent=4)

    end_time = time.time()
    print(f"\n任務完成！耗時: {end_time - start_time:.2f} 秒")
    print(f"新資料已寫入 {OUTPUT_FILE}")


if __name__ == "__main__":
    asyncio.run(main())
