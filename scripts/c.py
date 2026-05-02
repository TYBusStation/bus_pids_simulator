import json
import polyline


def encoded_to_wkt(encoded_str):
    if not encoded_str:
        return ""
    try:
        coords = polyline.decode(encoded_str)
        wkt_points = [f"{lon} {lat}" for lat, lon in coords]
        return f"LINESTRING ({', '.join(wkt_points)})"
    except Exception:
        return ""


def process_v2_to_wkt(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as f:
        routes = json.load(f)

    for route in routes:
        if "path" in route:
            path_obj = route["path"]
            path_obj["go"] = encoded_to_wkt(path_obj.get("go", ""))
            path_obj["back"] = encoded_to_wkt(path_obj.get("back", ""))

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(routes, f, ensure_ascii=False, indent=4)


if __name__ == "__main__":
    process_v2_to_wkt("taoyuan_routes_v2.json", "taoyuan_routes_wkt.json")
