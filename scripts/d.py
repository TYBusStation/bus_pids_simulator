import aiohttp
import asyncio
import json
import random
import re

# --- 設定 ---
INPUT_FILE = "taipei.json"  # d.py 產出的檔案
OP_ROUTE_FILE = "op_route_data_p.json"  # 包含 nid 的原始檔案
OUTPUT_FILE = "taipei_with_en.json"  # 最終產出
CONCURRENT_REQUESTS = 10  # 同時請求數

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    "Referer": "https://ebus.gov.taipei/",
    "Accept-Language": "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7"
}

SET_EN_URL = "https://ebus.gov.taipei/Home/SetCulture?culture=en"
ROUTE_URL_PREFIX = "https://ebus.gov.taipei/Route/StopsOfRoute?routeid="


async def fetch_en_json(session, nid):
    """根據 nid 抓取英文版原始資料"""
    url = f"{ROUTE_URL_PREFIX}{nid}"
    try:
        async with session.get(url, headers=HEADERS, timeout=20) as response:
            if response.status != 200:
                return None
            html = await response.text()
            match = re.search(r'var routeJsonString = JSON\.stringify\((.*?)\);', html, re.DOTALL)
            if not match:
                return None
            return json.loads(match.group(1))
    except Exception:
        return None


async def worker(session, semaphore, route_data, nid_map):
    """單一任務：使用 nid 補齊英文站名"""
    route_id = route_data.get("id")
    nid = nid_map.get(route_id)

    if not nid:
        return

    async with semaphore:
        try:
            await asyncio.sleep(random.uniform(0.1, 0.3))
            raw_data = await fetch_en_json(session, nid)

            if not raw_data:
                return

            # --- 修正重點：處理 null 的情況 ---
            raw_go = raw_data.get("GoDirStops") or []
            raw_back = raw_data.get("BackDirStops") or []

            en_go = {i + 1: s.get("Name", "") for i, s in enumerate(raw_go)}
            en_back = {i + 1: s.get("Name", "") for i, s in enumerate(raw_back)}

            # 補入英文站名 (去程)
            for station in route_data.get("stations", {}).get("go", []):
                order = station.get("order")
                station["name_en"] = en_go.get(order, "")

            # 補入英文站名 (回程)
            for station in route_data.get("stations", {}).get("back", []):
                order = station.get("order")
                station["name_en"] = en_back.get(order, "")

            print(f"  [完成] {route_data.get('name')} (nid: {nid})")
        except Exception as e:
            print(f"  [失敗] 處理 {route_data.get('name')} 時發生異常: {e}")


async def main():
    # 1. 讀取 nid 對照表
    try:
        with open(OP_ROUTE_FILE, "r", encoding="utf-8") as f:
            op_data = json.load(f)
            nid_map = {item['id']: item['nid'] for item in op_data if 'id' in item and 'nid' in item}
    except Exception as e:
        print(f"讀取 {OP_ROUTE_FILE} 失敗: {e}")
        return

    # 2. 讀取 d.py 的產出
    try:
        with open(INPUT_FILE, "r", encoding="utf-8") as f:
            all_routes = json.load(f)
    except Exception as e:
        print(f"讀取 {INPUT_FILE} 失敗: {e}")
        return

    print(f"已載入 {len(all_routes)} 條路線。開始根據 nid 補抓英文資料...")

    # 3. 初始化 Session 並切換語系
    semaphore = asyncio.Semaphore(CONCURRENT_REQUESTS)
    async with aiohttp.ClientSession() as session:
        try:
            # 設定語系
            await session.get(SET_EN_URL, headers=HEADERS)
        except Exception as e:
            print(f"無法切換語系: {e}")
            return

        # 4. 併發執行任務
        tasks = [worker(session, semaphore, route, nid_map) for route in all_routes]
        await asyncio.gather(*tasks)

    # 5. 存檔
    try:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(all_routes, f, ensure_ascii=False, indent=4)
        print(f"\n處理完成！結果已存至 {OUTPUT_FILE}")
    except Exception as e:
        print(f"儲存失敗: {e}")


if __name__ == "__main__":
    asyncio.run(main())
