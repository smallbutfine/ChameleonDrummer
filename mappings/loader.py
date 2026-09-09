"""Keymap Loader — discover, validate, and load drum instrument mappings."""

import json
from pathlib import Path

# ── Keymap Metadata ──────────────────────────────────────────────────────────


class KeymapInfo:
    """Metadata about a single loaded keymap file."""

    name: str
    version: str
    description: str
    source: str
    path: Path
    instruments: dict  # instrument_name -> {midi_note, description}


# ── Template & Discovery ────────────────────────────────────────────────────


def load_template(template_path: Path | None = None) -> KeymapInfo:
    """Load the master template keymap."""
    if template_path is None:
        template_path = _default_template_path()
    return _load_keymap_file(template_path)


def discover_keymaps(mappings_dir: Path | None = None) -> list[KeymapInfo]:
    """Discover all keymap JSON files in the mappings directory.

    Returns a list of KeymapInfo objects, one per discovered file.
    Skips the template file.
    """
    if mappings_dir is None:
        mappings_dir = _default_mappings_dir()

    keymaps = []
    for fpath in sorted(mappings_dir.glob("*.json")):
        # Skip the template file itself
        if fpath.name == "template.json" or "template" in fpath.stem.lower():
            continue
        info = _load_keymap_file(fpath)
        keymaps.append(info)
    return keymaps


def get_all_instruments(template_path: Path | None = None) -> set[str]:
    """Get the full list of instrument names from the template."""
    tmpl = load_template(template_path)
    return set(tmpl.instruments.keys())


def get_mapped_instruments(
    keymap_name: str, mappings_dir: Path | None = None
) -> set[str]:
    """Get instruments that have non-null MIDI notes in a given keymap.

    Args:
        keymap_name: The stem of the mapping file (e.g., 'ad2', 'gm', 'ezd3')
                     or a full path to a JSON file.
    """
    if mappings_dir is None:
        mappings_dir = _default_mappings_dir()

    fpath = Path(keymap_name)
    if not fpath.suffix:
        # Assume it's a keymap name, look for the corresponding file
        candidates = list(mappings_dir.glob(f"{keymap_name.lower()}*.json"))
        if not candidates:
            return set()
        fpath = candidates[0]

    info = _load_keymap_file(fpath)
    return {
        inst
        for inst, data in info.instruments.items()
        if data.get("midi_note") is not None
    }


def get_unmapped_instruments(
    keymap_name: str, mappings_dir: Path | None = None
) -> set[str]:
    """Get instruments that are present in the template but have null MIDI notes in the keymap."""
    mapped = get_mapped_instruments(keymap_name, mappings_dir)
    all_instruments = get_all_instruments()
    return all_instruments - mapped


def generate_user_keymap(target_path: Path) -> None:
    """Write a copy of the template with null MIDI notes for user editing."""
    tmpl = load_template()
    output = {
        "name": "User Custom Kit",
        "version": tmpl.version,
        "description": "Custom keymap — fill in midi_note values. Leave as null for unavailable articulations.",
        "instruments": {},
    }
    for name, data in tmpl.instruments.items():
        output["instruments"][name] = {
            "midi_note": None,
            "description": data.get("description", ""),
        }

    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(json.dumps(output, indent=4), encoding="utf-8")


def print_keymap_summary(keymaps: list[KeymapInfo] | None = None) -> None:
    """Print a summary table of all discovered keymaps."""
    if keymaps is None:
        keymaps = discover_keymaps()

    all_instruments = get_all_instruments()
    total_instruments = len(all_instruments)

    print(f"Discovered {len(keymaps)} keymap(s):\n")
    print(f"{'Keymap':<20} {'Mapped':>8} {'Unmapped':>10} {'Coverage':>10}")
    print("-" * 52)

    for km in keymaps:
        mapped = len(get_mapped_instruments(km.path.name))
        unmapped = total_instruments - mapped
        coverage = (
            f"{(mapped / total_instruments * 100):.0f}%"
            if total_instruments
            else "N/A"
        )
        print(f"{km.name:<20} {mapped:>8} {unmapped:>10} {coverage:>10}")


def print_missing(keymap_name: str, mappings_dir: Path | None = None) -> None:
    """Print instruments missing from a specific keymap."""
    unmapped = get_unmapped_instruments(keymap_name, mappings_dir)
    if not unmapped:
        print(f"All {len(unmapped)} instruments mapped for '{keymap_name}'")
        return

    tmpl = load_template()
    print(
        f"\nUnmapped instruments in '{keymap_name}' ({len(unmapped)} of {len(tmpl.instruments)}):\n"
    )
    for inst in sorted(unmapped):
        desc = tmpl.instruments.get(inst, {}).get("description", "")
        print(f"  - {inst:50} {desc}")


# ── Internals ────────────────────────────────────────────────────────────────


def _default_template_path() -> Path:
    return _default_mappings_dir() / "template.json"


def _default_mappings_dir() -> Path:
    return Path(__file__).resolve().parent


def _load_keymap_file(path: Path) -> KeymapInfo:
    """Load and validate a single keymap JSON file."""
    if not path.exists():
        raise FileNotFoundError(f"Keymap file not found: {path}")

    data = json.loads(path.read_text(encoding="utf-8"))

    info = KeymapInfo()
    info.name = data.get("name", "Unknown")
    info.version = data.get("version", "0.0")
    info.description = data.get("description", "")
    info.source = data.get("source", "")
    info.path = path
    info.instruments = data.get("instruments", {})

    return info


def _validate_keymap(
    keymap: KeymapInfo, template_path: Path | None = None
) -> list[str]:
    """Validate a keymap against the template.

    Returns a list of warning/error messages.
    """
    warnings = []
    tmpl = load_template(template_path)
    tmpl_instruments = set(tmpl.instruments.keys())
    km_instruments = set(keymap.instruments.keys())

    # Check for instruments in keymap but not in template
    extra = km_instruments - tmpl_instruments
    if extra:
        warnings.append(
            f"WARNING: Keymap has {len(extra)} instruments not in template: {sorted(extra)[:5]}..."
        )

    # Check for instruments in template but missing from keymap
    missing = tmpl_instruments - km_instruments
    if missing:
        warnings.append(
            f"INFO: {len(missing)} instruments from template are missing from this keymap (will fall back to null)"
        )

    return warnings
