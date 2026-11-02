#!/usr/bin/env python3
"""Minimal skills installer: list / install / outdated / update, plus index / check for CI.

Source repo is cloned (sparse, shallow) into a per-machine cache; only requested
skills are checked out and copied into the workspace target folder.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd()
DEFAULT_TARGETS = {"claude": ".claude/skills", "github": ".github/skills"}
LOCK = ".skills-lock.json"
CACHE_ROOT = Path(os.environ.get("SKILLS_CACHE", Path.home() / ".cache" / "skills"))


def git(*args, cwd=None, check=True):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and r.returncode:
        sys.exit(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    out = {}
    for line in (m.group(1).splitlines() if m else []):
        k, _, v = line.partition(":")
        if _:
            out[k.strip()] = v.strip().strip('"')
    return out


def content_hash(folder):
    h = hashlib.sha256()
    for p in sorted(Path(folder).rglob("*")):
        if p.is_file():
            h.update(str(p.relative_to(folder)).encode())
            h.update(p.read_bytes())
    return h.hexdigest()[:16]


# ---------- source side (CI) ----------

def build_index(root=HERE, ref="HEAD"):
    index = {}
    for skill_md in sorted((root / "skills").glob("*/SKILL.md")):
        name = skill_md.parent.name
        fm = frontmatter(skill_md.read_text(encoding="utf-8"))
        if "version" not in fm:
            sys.exit(f"skills/{name}/SKILL.md has no version")
        index[name] = {
            "version": fm["version"],
            "path": f"skills/{name}",
            "tree": git("rev-parse", f"{ref}:skills/{name}", cwd=root),
        }
    return index


def cmd_index(a):
    (HERE / "index.json").write_text(json.dumps(build_index(), indent=2) + "\n")
    print("index.json written")


def cmd_check(a):
    """Fail if skills/x/ changed vs base without a version bump."""
    changed = git("diff", "--name-only", f"{a.base}...HEAD", cwd=HERE).splitlines()
    names = {p.split("/")[1] for p in changed if p.startswith("skills/") and p.count("/") >= 2}
    bad = []
    for n in sorted(names):
        if not (HERE / "skills" / n / "SKILL.md").exists():
            continue  # removed
        new = frontmatter((HERE / "skills" / n / "SKILL.md").read_text(encoding="utf-8")).get("version")
        old_md = git("show", f"{a.base}:skills/{n}/SKILL.md", cwd=HERE, check=False)
        if old_md and frontmatter(old_md).get("version") == new:
            bad.append(f"{n} changed but version is still {new}")
    if bad:
        sys.exit("\n".join(bad))
    print("version check ok")


# ---------- consumer side ----------

def source_of(a, lock):
    return a.source or lock.get("source") or os.environ.get("SKILLS_SOURCE") or str(HERE)


def cache_for(source):
    return CACHE_ROOT / hashlib.sha1(source.encode()).hexdigest()[:12]


def sync(source, names=()):
    """Update the cache clone and make sure `names` are checked out."""
    cache = cache_for(source)
    if not cache.exists():
        cache.parent.mkdir(parents=True, exist_ok=True)
        url = "file://" + source if Path(source).exists() else source
        git("clone", "--depth", "1", "--filter=blob:none", "--sparse", url, str(cache))
    else:
        git("pull", "--ff-only", "-q", cwd=cache)
    if names:
        git("sparse-checkout", "add", *[f"skills/{n}" for n in names], cwd=cache)
    return cache


def load_lock():
    p = Path(LOCK)
    return json.loads(p.read_text()) if p.exists() else {"source": None, "skills": {}}


def save_lock(lock):
    Path(LOCK).write_text(json.dumps(lock, indent=2) + "\n")


def load_index(cache):
    return json.loads((cache / "index.json").read_text())


def targets():
    f = HERE / "targets.json"  # absent when the script is piped in from a URL
    return json.loads(f.read_text()) if f.exists() else DEFAULT_TARGETS


def cmd_list(a):
    lock = load_lock()
    index = load_index(sync(source_of(a, lock)))
    for n, e in index.items():
        if a.names:  # machine-readable: value|label|description, for the VS Code picker
            print(f"{n}|{n}|v{e['version']}" + (f" (installed {lock['skills'][n]['version']})" if n in lock["skills"] else ""))
            continue
        inst = lock["skills"].get(n)
        print(f"{n:15} {e['version']:8} {'installed ' + inst['version'] if inst else ''}")


def do_install(name, target, source, lock, cache, index, force=False):
    if name not in index:
        sys.exit(f"unknown skill: {name}")
    dest = Path(targets()[target]) / name
    prev = lock["skills"].get(name)
    if dest.exists():
        if prev and content_hash(dest) != prev["content"] and not force:
            print(f"! {name}: local edits in {dest}, skipping (use --force to overwrite)")
            return
        if not prev and not force:
            print(f"! {name}: {dest} exists and is not managed, skipping (use --force)")
            return
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(cache / index[name]["path"], dest)
    lock["source"] = source
    lock["skills"][name] = {
        "version": index[name]["version"],
        "tree": index[name]["tree"],
        "content": content_hash(dest),
        "target": targets()[target],
    }
    print(f"+ {name} {index[name]['version']} -> {dest}")


def ask(prompt):
    # stdin may be the piped script itself, so read the answer from the terminal
    try:
        with open("/dev/tty") as tty:
            print(prompt, end="", flush=True)
            return tty.readline().strip()
    except OSError:
        return input(prompt).strip()


def choose(index):
    names = list(index)
    for i, n in enumerate(names, 1):
        print(f"  {i}) {n} {index[n]['version']}")
    print("  a) all")
    ans = ask("Select (numbers separated by spaces, or a): ").lower()
    if ans in ("a", "all"):
        return names
    return [names[int(x) - 1] for x in ans.split() if x.isdigit() and 0 < int(x) <= len(names)]


def cmd_install(a):
    lock = load_lock()
    source = source_of(a, lock)
    cache = sync(source)
    index = load_index(cache)
    a.names = a.names or choose(index)
    if not a.names:
        sys.exit("nothing selected")
    git("sparse-checkout", "add", *[f"skills/{n}" for n in a.names if n in index], cwd=cache)
    for n in a.names:
        do_install(n, a.target, source, lock, cache, index, a.force)
    save_lock(lock)


def stale(lock, index):
    return {n: index[n] for n, e in lock["skills"].items() if n in index and e["tree"] != index[n]["tree"]}


def cmd_outdated(a):
    lock = load_lock()
    if not lock["skills"]:
        return print("no skills installed")
    index = load_index(sync(source_of(a, lock)))
    old = stale(lock, index)
    for n, e in old.items():
        print(f"{n}: {lock['skills'][n]['version']} -> {e['version']}")
    print(f"{len(old)} skill(s) outdated" if old else "all skills up to date")
    sys.exit(1 if old and a.strict else 0)


def cmd_update(a):
    lock = load_lock()
    source = source_of(a, lock)
    cache = sync(source, list(lock["skills"]))
    index = load_index(cache)
    old = stale(lock, index)
    names = list(old) if a.all or not a.names else [n for n in a.names if n in old]
    for n in names:
        tgt = next(k for k, v in targets().items() if v == lock["skills"][n]["target"])
        do_install(n, tgt, source, lock, cache, index, a.force)
    save_lock(lock)
    if not names:
        print("nothing to update")


def main():
    p = argparse.ArgumentParser(prog="skills")
    p.add_argument("--source", help="git URL or local path of the skills repo")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("list")
    s.add_argument("--names", action="store_true", help="one 'name|name|description' line per skill")
    s.set_defaults(fn=cmd_list)
    s = sub.add_parser("install")
    s.add_argument("names", nargs="*", help="skill names; omit to pick from a menu")
    s.add_argument("--target", choices=list(targets()), default="claude")
    s.add_argument("--force", action="store_true")
    s.set_defaults(fn=cmd_install)
    s = sub.add_parser("outdated")
    s.add_argument("--strict", action="store_true", help="exit 1 if any are outdated")
    s.set_defaults(fn=cmd_outdated)
    s = sub.add_parser("update")
    s.add_argument("names", nargs="*")
    s.add_argument("--all", action="store_true")
    s.add_argument("--force", action="store_true")
    s.set_defaults(fn=cmd_update)
    sub.add_parser("index", help="(CI) regenerate index.json").set_defaults(fn=cmd_index)
    s = sub.add_parser("check", help="(CI) require version bump on changed skills")
    s.add_argument("--base", default="origin/main")
    s.set_defaults(fn=cmd_check)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
