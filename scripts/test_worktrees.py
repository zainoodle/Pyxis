#!/usr/bin/env python3
"""Run independent worktree checks with isolated SwiftPM caches and logs."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def git(root, *arguments):
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True).strip()


def linked_worktrees(root):
    output = git(root, "worktree", "list", "--porcelain")
    return [Path(line.removeprefix("worktree ")).resolve()
            for line in output.splitlines() if line.startswith("worktree ")
            and (Path(line.removeprefix("worktree ")) / ".git").exists()]


def check(root, cache_root):
    key = hashlib.sha256(str(root).encode()).hexdigest()[:12]
    cache = cache_root / key
    cache.mkdir(parents=True, exist_ok=True)
    result = {
        "path": str(root), "branch": git(root, "branch", "--show-current") or "(detached)",
        "head": git(root, "rev-parse", "HEAD"), "log": str(cache / "checks.log"),
        "scratch_path": str(cache / "swiftpm"),
    }
    with (cache / "checks.lock").open("w") as lock:
        # Two runner instances must not build the same worktree cache at once.
        fcntl.flock(lock, fcntl.LOCK_EX)
        with (cache / "checks.log").open("w") as log:
            for command in [
                ["git", "diff", "--check"],
                ["swift", "test", "--scratch-path", str(cache / "swiftpm")],
            ]:
                log.write("$ " + " ".join(command) + "\n")
                log.flush()
                process = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
                if process.returncode:
                    result.update(status="failed", exit_code=process.returncode)
                    break
            else:
                result.update(status="passed", exit_code=0)
        contents = (cache / "checks.log").read_text(errors="replace")
        summaries = list(re.finditer(
            r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures", contents
        ))
        if summaries:
            count, skipped, failures = summaries[-1].groups()
            result.update(reported_tests=int(count), skipped=int(skipped or 0), failures=int(failures))
        if result["status"] == "failed":
            result["diagnostic"] = "\n".join(contents.splitlines()[-10:])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Check every existing worktree linked to this repository")
    parser.add_argument("--worktree", type=Path, action="append", help="Check an explicit worktree; repeat as needed")
    parser.add_argument("--jobs", type=int, default=2, help="Maximum simultaneous checks (default: 2)")
    parser.add_argument("--cache-root", type=Path, default=Path(tempfile.gettempdir()) / "pyxis-worktree-checks")
    parser.add_argument("--output", type=Path, help="Write the results as JSON")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be at least 1")
    if args.all and args.worktree:
        parser.error("Choose --all or explicit --worktree paths")
    root = Path(__file__).resolve().parents[1]
    roots = linked_worktrees(root) if args.all else (args.worktree or [root])
    roots = list(dict.fromkeys(path.resolve() for path in roots))
    for path in roots:
        if not (path / "Package.swift").is_file() or not (path / ".git").exists():
            parser.error(f"Not a Pyxis Swift package checkout: {path}")
    cache_root = args.cache_root.resolve()
    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = {executor.submit(check, path, cache_root): path for path in roots}
        for future in as_completed(futures):
            try:
                result = future.result()
            except Exception as error:
                result = {"path": str(futures[future]), "status": "failed", "diagnostic": str(error)}
            results.append(result)
            print(json.dumps(result), flush=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(sorted(results, key=lambda item: item["path"]), indent=2) + "\n")
    return int(any(result["status"] != "passed" for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
