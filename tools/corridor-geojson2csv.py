import argparse
import csv
import json


def convert(file_path, idx_offset=1):
    csv_path = file_path + ".csv"
    with open(file_path) as json_file, open(csv_path, "w", newline="") as csv_file:
        gj_in = json.load(json_file)
        csv_out = csv.writer(csv_file)
        for idx, feature in enumerate(gj_in["features"]):
            if feature["properties"]["class"] != "corridor":
                continue
            geo = feature["geometry"]
            for point in geo["coordinates"]:
                csv_out.writerow([idx + idx_offset, point[0], point[1]])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        "scenario-converter",
        description="Convert a GeoJSON file to a scenario for USEPE-BlueSky",
    )
    parser.set_defaults(dry_run=False)
    parser.add_argument(
        "file",
        help="Path to the input file that holds the corridor geometries",
        type=str,
    )
    args = parser.parse_args()

    convert(args.file)
