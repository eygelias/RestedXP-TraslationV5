#!/usr/bin/env python3
"""download_libbabble.py - Descarga LibBabble-SubZone para todos los idiomas."""
from __future__ import annotations
import zipfile
import urllib.request
import tempfile
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
RXPGUIDES_LOCALE = BASE_DIR / "rxpguides_locale"

DOWNLOAD_URL = "https://www.wowace.com/projects/libbabble-subzone-3-0/files/latest"
LOCALES = ["esES", "esMX", "deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]


def main():
    RXPGUIDES_LOCALE.mkdir(exist_ok=True)

    # Verificar cuáles ya existen
    existing = []
    missing = []
    for locale in LOCALES:
        out = RXPGUIDES_LOCALE / f"subzone_{locale}.lua"
        if out.exists():
            existing.append(locale)
        else:
            missing.append(locale)

    if existing:
        print(f"Ya existen: {', '.join(existing)}")

    if not missing:
        print("Todos los archivos de LibBabble ya están descargados.")
        return

    print(f"Descargando faltantes: {', '.join(missing)}")
    print("Descargando LibBabble-SubZone-3.0...")

    try:
        with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
            urllib.request.urlretrieve(DOWNLOAD_URL, tmp.name)
            zip_path = tmp.name
    except Exception as e:
        print(f"Error descargando: {e}")
        print("Los archivos LibBabble deben descargarse manualmente de:")
        print("https://www.wowace.com/projects/libbabble-subzone-3-0/files/latest")
        print(f"Copia los archivos Locale/*.lua a {RXPGUIDES_LOCALE}/ como subzone_*.lua")
        return

    print("Extrayendo archivos de locale...")
    with zipfile.ZipFile(zip_path) as archive:
        for locale in LOCALES:
            out = RXPGUIDES_LOCALE / f"subzone_{locale}.lua"
            if out.exists():
                continue
            member = f"LibBabble-SubZone-3.0/Locale/{locale}.lua"
            try:
                data = archive.read(member).decode("utf-8", errors="ignore")
                out.write_text(data, encoding="utf-8")
                print(f"  ✅ {locale} → {out.name}")
            except KeyError:
                print(f"  ⚠ {locale}: no encontrado en el zip")

    Path(zip_path).unlink(missing_ok=True)
    print("\nListo.")


if __name__ == "__main__":
    main()
