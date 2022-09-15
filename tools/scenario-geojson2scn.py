import argparse
import json
import os
import unicodedata
from datetime import timedelta
from typing import List

uas_id = 0
area_id = 0

# TODO comment code

defaults = {
    "zoom": 16,
    "duration": 30,
    "plugins": ["dronetraf", "usepelogger"],
    "setup": [
        "dronetraf area traffic_area",
        "asas on",
        "reso mvp",
        "rmethh spd",
        "usepeconflog on",
        "ff",
    ],
    "close": ["op", "quit"],
}


def write_output(path, out, config):
    if config["dry_run"]:
        print(f"\n - {path}:")
        print("\n".join(out))
    else:
        with open(path, "w") as f:
            f.write("\n".join(out))


def normalize_id(id):
    # TODO is the unicode normalization really necessary?
    id = unicodedata.normalize("NFKD", id).encode("ascii", "ignore")
    id = "-".join(id.decode("ascii").split())
    return id


def get_id(feature):
    global area_id

    if "id" in feature:
        id = feature["id"]
    elif "name" in feature["properties"]:
        id = normalize_id(feature["properties"]["name"])
    else:
        id = f"Area{area_id}"
        area_id = area_id + 1
    return id


def write_cmd(cmd: str, *arguments: List[str], timestamp: timedelta = timedelta(seconds=0)):
    hours, remainder = divmod(timestamp.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    timestamp = "{:02}:{:02}:{:02}".format(int(hours), int(minutes), int(seconds))
    return f'{timestamp}> {cmd.upper()} {" ".join(str(arg).upper() for arg in arguments)}'


def write_aircrafts(config, features):
    def get_point_id(feature, idx):
        return f"{get_id(feature)}_{idx}"

    def get_line_points(feature):
        points = list(p for p in feature["geometry"]["coordinates"])
        for idx, point in enumerate(points):
            if len(point) > 2:
                points[idx] = [*reversed(point[0:2]), point[2]]
            else:
                points[idx] = [*reversed(point[0:2]), None]
        return points

    config["ac_files"] = []
    for feature in features:
        props = feature["properties"]

        if feature["geometry"]["type"] == "LineString" and "model" in props:
            aid = get_id(feature)
            pid = get_point_id(feature, 0)
            if "start" in props:
                start = normalize_id(props["start"])
            else:
                start = pid

            out = []

            points = get_line_points(feature)
            point_idxs = []
            for idx, point in enumerate(points):
                point_idxs.append(idx)
                out.append(write_cmd("defwpt", get_point_id(feature, idx), *point[:2], "fix"))

            out.append(write_cmd("cre", aid, props["model"], start, 0, 0, 0))

            if "repeat" in props:
                if props["repeat"] == "loop":
                    point_idxs = point_idxs * 5
                elif props["repeat"] == "return":
                    point_idxs = [*point_idxs, *reversed(point_idxs[:-1])]

            d = timedelta(seconds=1)
            for idx in point_idxs:
                point = points[idx]
                cmd = write_cmd("addwpt", aid, get_point_id(feature, idx), timestamp=d)
                if point[2] is not None:
                    cmd = f"{cmd}, {point[2]}"
                out.append(cmd)

            # fmt: off
            d = timedelta(seconds=2)
            out.append(write_cmd("alt", aid, props["alt"], timestamp=d))
            out.append(write_cmd("vs", aid, 800, timestamp=d))
            out.append(write_cmd(aid, "atalt", props["alt"], "spd", aid, props["vs"], timestamp=d))
            out.append(write_cmd("vnav", aid, "on", timestamp=d))
            out.append(write_cmd(aid, "at", pid, "do", aid, "atdist", start, "0.03", "spd", aid, 10, timestamp=d))
            out.append(write_cmd(aid, "at", pid, "do", aid, "atdist", start, "0.001", "spd", aid, 0, timestamp=d))
            out.append(write_cmd(aid, "at", pid, "do", aid, "atspd", "0", "alt", aid, 0, timestamp=d))
            out.append(write_cmd(aid, "atalt", "10", aid, "atalt", "0", "del", aid, timestamp=d))
            # fmt: on

            path = os.path.join(*config["experiment"], f"{aid}.scn")
            config["ac_files"].append(path)
            write_output(os.path.join("scenario", path), out, config)
    return config


def write_areas(config, features):
    def get_poly_coordinates(feature):
        points = (reversed(p) for p in feature["geometry"]["coordinates"][0])
        return [c for coords in points for c in coords]

    def get_point_coordinates(feature):
        return reversed(feature["geometry"]["coordinates"])

    out = []
    for feature in features:
        if feature["geometry"]["type"] == "Polygon":
            out.append(write_cmd("poly", get_id(feature), *get_poly_coordinates(feature)))
        elif feature["geometry"]["type"] == "Point" and "radius" in feature["properties"]:
            out.append(
                write_cmd(
                    "circle",
                    get_id(feature),
                    *get_point_coordinates(feature),
                    feature["properties"]["radius"],
                )
            )
        elif feature["geometry"]["type"] == "Point":
            out.append(
                write_cmd("defwpt", get_id(feature), *get_point_coordinates(feature), "fix")
            )

    path = os.path.join("scenario", *config["experiment"], "operation_areas.scn")
    write_output(path, out, config)
    return config


def write_main(config):
    out = []
    for plugin_name in config["plugins"]:
        out.append(write_cmd("plugin", "load", plugin_name))

    out.append(
        write_cmd("pcall", os.path.join(*config["experiment"], "operation_areas.scn"), "rel")
    )

    for cmd in config["setup"]:
        cmd = cmd.split()
        out.append(write_cmd(cmd[0], *cmd[1:]))

    if "bbox" in config:
        pan_center = (
            (config["bbox"][1] + config["bbox"][3]) / 2,
            (config["bbox"][0] + config["bbox"][2]) / 2,
        )
        out.append(write_cmd("pan", *pan_center))

    out.append(write_cmd("zoom", config["zoom"]))

    for acf in config["ac_files"]:
        out.append(write_cmd("pcall", acf, "rel"))

    scenario_duration = timedelta(minutes=config["duration"])
    timestamp = scenario_duration
    for cmd in config["close"]:
        timestamp = timestamp + timedelta(seconds=2)
        cmd = cmd.split()
        out.append(write_cmd(cmd[0], *cmd[1:], timestamp=timestamp))

    path = "-".join(part.lower() for part in config["experiment"] + [config["variant"]])
    path = os.path.join("scenario", f"{path}.scn")
    write_output(path, out, config)


def convert(json_path, dry_run=False):
    json_path = os.path.relpath(os.path.normpath(json_path))
    with open(json_path, encoding="utf-8") as json_file:
        json_data = json.load(json_file)

    # Create the config from the defaults, the file path of the scenario definition
    # and foreign members of the GeoJSON FeatureCollection
    config = defaults
    config["dry_run"] = dry_run
    config["experiment"] = json_path.split(os.path.sep)[1:-1]
    config["variant"] = os.path.splitext(os.path.basename(json_path))[0]
    for key in json_data:
        if key not in ["type", "features"]:
            config[key] = json_data[key]

    # Write scenario files
    config = write_areas(config, json_data["features"])
    config = write_aircrafts(config, json_data["features"])
    config = write_main(config)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        "scenario-converter",
        description="Convert a GeoJSON file to a scenario for USEPE-BlueSky",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        dest="dry_run",
        help="Output the scenario file contents to STDOUT instead of writing them to files",
    )
    parser.set_defaults(dry_run=False)
    parser.add_argument(
        "scenario",
        help="Path to the input file that holds the base scenario",
        type=str,
    )
    args = parser.parse_args()

    convert(args.scenario, args.dry_run)
