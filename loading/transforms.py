import json


def _matches(record):
    if record.get("overrides"):
        ov = record["overrides"]
        record["overrides"] = {
            "pick_multiplier": ov.get("pick_multiplier"),
            "rules":           json.dumps(ov.get("rules")),
            "scoring":         json.dumps(ov.get("scoring")),
            "element_types":   json.dumps(ov.get("element_types")),
        }
    return record


TRANSFORMS = {
    "matches": _matches,
}


def apply(record, table_name):
    transform = TRANSFORMS.get(table_name)
    return transform(record) if transform else record
