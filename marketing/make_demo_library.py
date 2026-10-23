#!/usr/bin/env python3
"""Builds placeholder EPUBs with public-domain titles, used only to fill the library for screenshots.

Run from the repository root:  python3 marketing/make_demo_library.py
Then open each file on the simulator:  xcrun simctl openurl <udid> file://<path>
"""
import pathlib
import zipfile

OUT = pathlib.Path(__file__).resolve().parent / "demo-books"

BOOKS = [
    ("Persuasion", "Jane Austen"),
    ("Moby-Dick", "Herman Melville"),
    ("Frankenstein", "Mary Shelley"),
    ("Middlemarch", "George Eliot"),
    ("Walden", "Henry David Thoreau"),
]


def epub(title: str, author: str) -> dict:
    chapter = f"""<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>{title}</title></head>
<body><h1>{title}</h1><p>This placeholder stands in for the full text in screenshots.</p></body></html>
"""
    opf = f"""<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">urn:folio:demo:{title.lower().replace(' ', '-')}</dc:identifier>
    <dc:title>{title}</dc:title>
    <dc:creator>{author}</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest><item id="c1" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="c1"/></spine>
</package>
"""
    container = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>
"""
    return {"META-INF/container.xml": container, "content.opf": opf, "chapter.xhtml": chapter}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for title, author in BOOKS:
        path = OUT / f"{title.lower().replace(' ', '-')}.epub"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
            for name, content in epub(title, author).items():
                archive.writestr(name, content, compress_type=zipfile.ZIP_DEFLATED)
        print(path)


if __name__ == "__main__":
    main()
