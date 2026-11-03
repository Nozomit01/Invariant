"""Linux cloud verification using separate Godot processes and isolated XDG data.
Usage: python3 tests/run_leave_save_process.py /path/to/godot
All fixtures/logs remain in a newly created temporary directory for inspection.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
engine = sys.argv[1]
root = Path(tempfile.mkdtemp(prefix="invariant-save-process-"))
results = []

def run(label, mode, expected, profile="normal"):
    env = os.environ.copy()
    for key, part in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
        env[key] = str(root / profile / part)
    p = subprocess.run([engine, "--headless", "--path", str(project), "--script", "tests/leave_save_process.gd", "--", mode, str(expected)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    (root / (label + ".log")).write_text(p.stdout)
    result = {"check": label, "exit": p.returncode, "pass": sum(line.startswith("PASS:") for line in p.stdout.splitlines())}
    results.append(result)
    print(json.dumps(result), flush=True)
    assert p.returncode == 0 and "FAIL:" not in p.stdout and "ERROR:" not in p.stdout, p.stdout
    return Path(next(line.removeprefix("USER_DATA_DIR=") for line in p.stdout.splitlines() if line.startswith("USER_DATA_DIR=")))

def snapshot(folder):
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob("*") if p.is_file()}

print("EVIDENCE=" + str(root), flush=True)
user = run("fresh", "inspect", 0)
run("direct-hub", "hub", 0)
run("interrupted", "interrupt", 0)
run("restart-after-interruption", "inspect", 0)
folder = user / "outcomes_v1"
assert not folder.exists(), "unfinished gameplay wrote a save"
run("completed", "complete", 0)
run("restart-after-completion", "inspect", 1)
original = snapshot(folder)
assert len(original) == 1 and next(iter(original)).endswith("confirmed.json")
run("repeated", "complete", 1)
run("restart-after-repeat", "inspect", 1)
assert snapshot(folder) == original, "repeat changed existing save or created duplicates"
for p in folder.rglob("confirmed.json"):
    p.write_text("{broken fixture")
(folder / "personal.txt").write_text("PRESERVE USER FILE")
broken = snapshot(folder)
run("corrupt-load", "inspect", 0)
run("completed-after-corruption", "complete", 0)
run("restart-after-recovery", "inspect", 1)
recovered = snapshot(folder)
assert all(recovered.get(name) == digest for name, digest in broken.items()), "recovery changed existing files"
blocked_user = run("blocked-initial", "inspect", 0, "blocked")
(blocked_user / "outcomes_v1").write_text("KEEP OBSTRUCTING FILE")
run("blocked-completion", "blocked", 0, "blocked")
run("blocked-restart", "inspect", 0, "blocked")
assert (blocked_user / "outcomes_v1").read_text() == "KEEP OBSTRUCTING FILE"
(root / "results.json").write_text(json.dumps(results, indent=2))
print("PASS: independent processes, interruption, deduplication, corruption recovery and non-destructive failure")
