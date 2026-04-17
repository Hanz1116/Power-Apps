"""Lists available Microsoft Power Apps Canvas App controls from the catalog."""

import json
from pathlib import Path


def load_controls(catalog_path: str = "canvas_controls.json") -> dict:
    with open(catalog_path) as f:
        return json.load(f)


def list_controls(catalog: dict, category: str = None) -> None:
    categories = catalog["categories"]

    if category:
        if category not in categories:
            print(f"Category '{category}' not found.")
            print(f"Available categories: {', '.join(categories.keys())}")
            return
        categories = {category: categories[category]}

    total = 0
    for cat_name, cat_data in categories.items():
        controls = cat_data["controls"]
        print(f"\n{cat_name.replace('_', ' ')} ({len(controls)} controls)")
        print(f"  {cat_data['description']}")
        print("  " + "-" * 60)
        for ctrl in controls:
            print(f"  [{ctrl['type']}] {ctrl['name']}")
            print(f"    {ctrl['description']}")
        total += len(controls)

    print(f"\nTotal: {total} controls across {len(categories)} categories")


def search_controls(catalog: dict, keyword: str) -> None:
    keyword = keyword.lower()
    matches = []

    for cat_name, cat_data in catalog["categories"].items():
        for ctrl in cat_data["controls"]:
            if (
                keyword in ctrl["name"].lower()
                or keyword in ctrl["type"].lower()
                or keyword in ctrl["description"].lower()
            ):
                matches.append((cat_name, ctrl))

    if not matches:
        print(f"No controls found matching '{keyword}'")
        return

    print(f"\nControls matching '{keyword}' ({len(matches)} results):")
    print("-" * 60)
    for cat_name, ctrl in matches:
        print(f"  [{ctrl['type']}] {ctrl['name']}  (Category: {cat_name.replace('_', ' ')})")
        print(f"    {ctrl['description']}")


if __name__ == "__main__":
    import sys

    catalog_file = Path(__file__).parent / "canvas_controls.json"
    catalog = load_controls(catalog_file)

    if len(sys.argv) == 1:
        list_controls(catalog)
    elif sys.argv[1] == "--search" and len(sys.argv) > 2:
        search_controls(catalog, sys.argv[2])
    elif sys.argv[1] == "--category" and len(sys.argv) > 2:
        list_controls(catalog, sys.argv[2])
    else:
        print("Usage:")
        print("  python list_canvas_controls.py                         # list all controls")
        print("  python list_canvas_controls.py --category <name>       # filter by category")
        print("  python list_canvas_controls.py --search <keyword>      # search controls")
