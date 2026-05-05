import json

# --- 設定 ---
INPUT_FILE = "taipei_with_en.json"
OUTPUT_FILE = "taipei_final_clean.json"


def fix_route_structure(route):
    """
    針對單一路線物件進行強制結構修復
    """
    # 1. 確保基本欄位不是 None
    for field in ["id", "name", "description", "departure", "destination"]:
        if route.get(field) is None:
            route[field] = ""

    # 2. 確保 path 結構完整
    if "path" not in route or not isinstance(route["path"], dict):
        route["path"] = {"go": "", "back": ""}
    else:
        if route["path"].get("go") is None: route["path"]["go"] = ""
        if route["path"].get("back") is None: route["path"]["back"] = ""

    # 3. 確保 stations 結構完整
    if "stations" not in route or not isinstance(route["stations"], dict):
        route["stations"] = {"go": [], "back": []}

    # 4. 遍歷站點列表 (go 與 back)
    for direction in ["go", "back"]:
        if direction not in route["stations"] or route["stations"][direction] is None:
            route["stations"][direction] = []

        # 遍歷該方向的所有站點
        for station in route["stations"][direction]:
            # --- 重點：強制補上 name_en ---
            if "name_en" not in station or station["name_en"] is None:
                station["name_en"] = ""

            # 確保其餘站點欄位也不是 null
            if station.get("name") is None: station["name"] = ""
            if station.get("lat") is None: station["lat"] = 0.0
            if station.get("lon") is None: station["lon"] = 0.0
            if station.get("order") is None: station["order"] = 0

    return route


def main():
    print(f"正在讀取並深度修復 {INPUT_FILE} ...")
    try:
        with open(INPUT_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"讀取失敗: {e}")
        return

    if not isinstance(data, list):
        print("資料格式錯誤：預期為路線列表 (List)。")
        return

    # 執行清理與補齊
    fixed_data = [fix_route_structure(route) for route in data]

    print(f"正在儲存至 {OUTPUT_FILE} ...")
    try:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(fixed_data, f, ensure_ascii=False, indent=4)
        print("成功！已確保所有站點皆含有 name_en 欄位且無 null 值。")
    except Exception as e:
        print(f"儲存失敗: {e}")


if __name__ == "__main__":
    main()
