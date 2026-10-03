#!/usr/bin/env python3
"""Validate required output files and local HTML links before publishing."""

import argparse
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit
from xml.etree import ElementTree


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.stylesheets = []
        self.redirect = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "meta" and attrs.get("http-equiv", "").lower() == "refresh":
            self.redirect = True
        for key in ("href", "src", "poster"):
            if attrs.get(key):
                self.links.append(attrs[key])
        if tag == "link" and "stylesheet" in attrs.get("rel", "").split():
            self.stylesheets.append(attrs.get("href", ""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    root = args.directory.resolve()
    errors = []
    for name in ("index.html", "404.html", "robots.txt", "sitemap.xml", "llms.txt", "1/index.html", "2/index.html", "classics/index.html"):
        path = root / name
        if not path.is_file() or not path.stat().st_size:
            errors.append(f"Missing or empty required output: {name}")
    for name, reader in (("sitemap.xml", ElementTree.fromstring),):
        try:
            reader((root / name).read_text())
        except (OSError, ValueError, ElementTree.ParseError) as error:
            errors.append(f"Invalid {name}: {error}")

    pages = sorted(root.rglob("*.html"))
    for path in pages:
        page = Page()
        content = path.read_text(encoding="utf-8")
        page.feed(content)
        for block in re.findall(r'<script\s+type="application/ld\+json"\s*>(.*?)</script>', content, re.DOTALL):
            try:
                json.loads(block)
            except ValueError as error:
                errors.append(f"{path.relative_to(root)}: invalid JSON-LD: {error}")
        relative = path.relative_to(root).as_posix()
        if not page.stylesheets and not page.redirect:
            errors.append(f"{relative}: no stylesheet generated")
        for link in page.links:
            target = urlsplit(urljoin(f"https://caverace.com/{relative}", link))
            if target.scheme not in ("http", "https") or target.netloc != "caverace.com":
                continue
            local = root / unquote(target.path).lstrip("/")
            if local.is_dir():
                local /= "index.html"
            if not local.is_file():
                errors.append(f"{relative}: missing local link or asset: {link}")
    if not pages:
        errors.append("No HTML pages found; build the site first")
    for error in sorted(set(errors)):
        print(error)
    print(f"Checked {len(pages)} HTML pages, local links/assets, and required site outputs; {len(errors)} errors.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
