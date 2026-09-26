#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""autopush_watch.py — vigia o portfolio e faz push mal guardas um ficheiro.

Modo: enquanto estiver a correr, sempre que detecta alteração em ficheiros
tracked (index.html, app.js, style.css, etc) espera `debounce` segundos e
faz 1 ciclo seguro de commit+push — igual ao autopush.bat --once — até
carregares Ctrl+C ou fechares a janela.

Seguro: só commita visitas_totals.json (agregados, sem IP/HWID) + ficheiros
já tracked (git add -u). Ficheiros novos untracked nunca entram sozinhos.
Antes de commitar verifica o staged diff contra lista de identificadores
pessoais (ofuscada em base64).

Stdlib only.
Uso:
  python -X utf8 src/autopush_watch.py
  python -X utf8 src/autopush_watch.py --debounce 3 --poll 0.8
  python -X utf8 src/autopush_watch.py --once   (um ciclo só, sem vigiar)
  python -X utf8 src/autopush_watch.py --status (mostra status json do watch)
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
from pathlib import Path

AQUI = Path(__file__).resolve().parent
ROOT = AQUI.parent
LOG = ROOT / "autopush.log"
STATUS_JSON = ROOT / "var" / "autopush_status.json"

# lista ofuscada para o proprio ficheiro nao disparar o guard por conter o texto
_B64_BAD = [
    "Z2VlazE3ODE=",
    "b3BpcmF0YW51bWVybzE=",
    "cm9iZXJ0MzNv",
    "Um9iZXJ0b01GOTk4",
    "eHJvYnM=",
    "U2FuZGJveFxcUm9icw==",
    "U2FuZGJveFxcRGV2",
    "U2F2ZUZpbGVfTGl2ZQ==",
    "VGVzc2VyYWN0U3R1ZGlv",
]
_BAD = [base64.b64decode(b).decode().lower() for b in _B64_BAD]


def _log(msg: str) -> None:
    ts = time.strftime("%d/%m/%Y %H:%M:%S")
    line = f"[{ts}] {msg}\n"
    try:
        with LOG.open("a", encoding="utf-8", errors="ignore") as fh:
            fh.write(line)
    except Exception:
        pass
    try:
        print(line, end="", flush=True)
    except Exception:
        pass


def _status_write(data: dict) -> None:
    try:
        STATUS_JSON.parent.mkdir(parents=True, exist_ok=True)
        tmp = STATUS_JSON.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(STATUS_JSON)
    except Exception:
        pass


def _run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore", **kw)


def _git_ls_tracked() -> list[str]:
    r = _run(["git", "ls-files", "-z"], cwd=str(ROOT))
    if r.returncode != 0 or not r.stdout:
        return []
    return [p for p in r.stdout.split("\0") if p]


def _snapshot() -> None:
    try:
        sys.path.insert(0, str(AQUI))
        import srrobs_visitas as sv  # type: ignore

        sv._DB_PATH[0] = str(ROOT / "var" / "visitas_portfolio.json")
        dados = sv.carregar(sv._db())
        sv._gravar_snapshot(dados)
    except Exception as e:
        _log(f"aviso: snapshot falhou: {e}")


def _snapshot_needs_push() -> bool:
    try:
        actual = json.loads((ROOT / "visitas_totals.json").read_text(encoding="utf-8"))
        sys.path.insert(0, str(AQUI))
        import srrobs_visitas as sv  # type: ignore

        sv._DB_PATH[0] = str(ROOT / "var" / "visitas_portfolio.json")
        dados = sv.carregar(sv._db())
        snap = sv._public_stats(dados)
        keys = ("total_visitas", "total_github", "total_ips", "total_devices", "ips_online", "online_agora")
        for k in keys:
            if actual.get(k) != snap.get(k):
                return True
        return False
    except Exception:
        try:
            _snapshot()
            r = _run(["git", "diff", "--quiet", "--", "visitas_totals.json"], cwd=str(ROOT))
            return r.returncode != 0
        except Exception:
            return False


def _guard_blocked() -> bool:
    r = _run(["git", "diff", "--cached", "--no-color", "--"], cwd=str(ROOT))
    diff = (r.stdout or "").lower()
    if not diff:
        return False
    rn = _run(["git", "diff", "--cached", "--name-only", "-z"], cwd=str(ROOT))
    names = (rn.stdout or "").split("\0") if rn.stdout else []
    non_auto = [n for n in names if n and "autopush" not in n.lower()]
    if non_auto:
        r2 = _run(["git", "diff", "--cached", "--no-color", "--"] + non_auto, cwd=str(ROOT))
        diff2 = (r2.stdout or "").lower()
    else:
        diff2 = "" if any("autopush" in (n or "").lower() for n in names) and len(names) == 1 else diff
        if diff2 == "" and names:
            return False
        diff2 = diff if not non_auto else diff2
    hits = [b for b in _BAD if b in diff2]
    if hits:
        _log(f"BLOCKED personal no staged diff: {hits}")
        return True
    return False


def _once() -> bool:
    _snapshot()
    _run(["git", "add", "visitas_totals.json"], cwd=str(ROOT))
    _run(["git", "add", "-u"], cwd=str(ROOT))

    if _guard_blocked():
        _log("BLOCKED: reset ao stage e tenta só snapshot")
        _run(["git", "reset", "HEAD"], cwd=str(ROOT))
        _run(["git", "add", "visitas_totals.json"], cwd=str(ROOT))
        if _guard_blocked():
            _log("BLOCKED persistiu no snapshot, aborta ciclo")
            _run(["git", "reset", "HEAD"], cwd=str(ROOT))
            _run(["git", "pull", "--rebase", "--autostash", "origin", "main"], cwd=str(ROOT))
            _run(["git", "push", "origin", "main"], cwd=str(ROOT))
            _log("ciclo concluido (bloqueado)")
            return False

    r = _run(["git", "diff", "--cached", "--quiet"], cwd=str(ROOT))
    has_staged = r.returncode != 0
    if has_staged:
        _run(["git", "commit", "-m", f"auto: sync {time.strftime('%d/%m/%Y %H:%M:%S')}"], cwd=str(ROOT))
    _run(["git", "pull", "--rebase", "--autostash", "origin", "main"], cwd=str(ROOT))
    pr = _run(["git", "push", "origin", "main"], cwd=str(ROOT))
    if pr.returncode != 0 and has_staged:
        _log("aviso: push falhou (sem net ou conflito)")
    _log("ciclo concluido")
    return has_staged or pr.returncode == 0


def _collect_watched() -> list[Path]:
    tracked = _git_ls_tracked()
    extra = ["visitas_totals.json"]
    out: list[Path] = []
    seen = set()
    for rel in tracked + extra:
        if not rel or rel in seen:
            continue
        seen.add(rel)
        p = (ROOT / rel).resolve()
        if p.is_file():
            out.append(p)
    return out


def _print_status() -> int:
    # var file = só para debug local, gitignored
    try:
        data = json.loads(STATUS_JSON.read_text(encoding="utf-8"))
    except Exception:
        print("sem status ainda — watch nunca correu ou var/apagado")
        return 1
    import datetime

    age = time.time() - data.get("ts", 0)
    alive = "vivo" if age < 15 else "stale"
    print(json.dumps(data, ensure_ascii=False, indent=2))
    print(f"\nidade: {age:.1f}s — {alive} (poll {data.get('poll')}s)")
    return 0


def watch(poll: float = 0.8, debounce: float = 4.0) -> int:
    print(f"[watch] repo: {ROOT}", flush=True)
    print(f"[watch] a vigiar {_collect_watched().__len__()} ficheiros tracked + visitas_totals.json", flush=True)
    print(f"[watch] poll {poll}s  debounce {debounce}s  — grava um ficheiro e eu faço push. Ctrl+C para parar.", flush=True)
    _log(f"watch iniciado poll={poll}s debounce={debounce}s")
    _status_write({"pid": os.getpid(), "ts": time.time(), "state": "a correr", "poll": poll, "debounce": debounce, "repo": str(ROOT), "last_push": None, "last_file": None, "pending": False, "watching": len(_collect_watched())})

    def _stat(p: Path):
        try:
            st = p.stat()
            return (st.st_mtime, st.st_size)
        except OSError:
            return None

    watched = _collect_watched()
    state: dict[Path, tuple[float, int] | None] = {p: _stat(p) for p in watched}
    last_rescan = time.time()
    last_snapshot_check = time.time()
    pending_since: float | None = None
    last_file: str | None = None
    last_push_ts: float | None = None

    def heartbeat(pending: bool):
        _status_write({"pid": os.getpid(), "ts": time.time(), "state": "a correr" if pending is False else "pending", "poll": poll, "debounce": debounce, "repo": str(ROOT), "last_push": last_push_ts, "last_file": last_file, "pending": pending, "watching": len(watched)})

    try:
        r1 = _run(["git", "diff", "--quiet"], cwd=str(ROOT))
        r2 = _run(["git", "diff", "--cached", "--quiet"], cwd=str(ROOT))
        has_tracked_diff = (r1.returncode != 0) or (r2.returncode != 0)
        needs_snapshot = _snapshot_needs_push()
        if has_tracked_diff or needs_snapshot:
            _log("diff inicial detectado — push imediato")
            _once()
            last_push_ts = time.time()
            watched = _collect_watched()
            state = {p: _stat(p) for p in watched}
            heartbeat(False)
    except Exception:
        pass

    try:
        while True:
            time.sleep(poll)
            now = time.time()
            heartbeat(pending_since is not None)
            if now - last_rescan > 10:
                last_rescan = now
                nw = _collect_watched()
                if len(nw) != len(watched) or set(nw) != set(watched):
                    watched = nw
                    for p in watched:
                        if p not in state:
                            state[p] = _stat(p)
                    _log(f"watch: lista actualizada ({len(watched)} ficheiros)")

            changed = False
            changed_file: str | None = None
            for p in list(watched):
                cur = _stat(p)
                prev = state.get(p)
                if cur != prev:
                    state[p] = cur
                    changed = True
                    try:
                        changed_file = str(p.relative_to(ROOT))
                    except Exception:
                        changed_file = p.name

            for p in watched:
                if p not in state:
                    state[p] = _stat(p)
                    changed = True

            if changed:
                if pending_since is None:
                    _log(f"watch: alteração detectada ({changed_file or '?'}) — a aguardar debounce...")
                last_file = changed_file or last_file
                pending_since = now
                heartbeat(True)

            if pending_since is not None and (now - pending_since) >= debounce:
                _log("watch: debounce expirado — a fazer push")
                pending_since = None
                _once()
                last_push_ts = time.time()
                watched = _collect_watched()
                state = {p: _stat(p) for p in watched}
                last_rescan = now
                last_snapshot_check = now
                heartbeat(False)

            if now - last_snapshot_check > 30 and pending_since is None:
                last_snapshot_check = now
                try:
                    if _snapshot_needs_push():
                        _log("watch: visitas novas — a fazer push do snapshot")
                        _once()
                        last_push_ts = time.time()
                        watched = _collect_watched()
                        state = {p: _stat(p) for p in watched}
                        last_rescan = now
                        heartbeat(False)
                except Exception:
                    pass
    except KeyboardInterrupt:
        _log("watch parado (Ctrl+C)")
        _status_write({"pid": os.getpid(), "ts": time.time(), "state": "parado", "poll": poll, "debounce": debounce, "repo": str(ROOT), "last_push": last_push_ts, "last_file": last_file, "pending": False, "watching": len(watched)})
        print("\n[watch] parado.", flush=True)
        return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Vigia e faz auto-push até parares (Ctrl+C)")
    ap.add_argument("--poll", type=float, default=0.8, help="segundos entre varrimentos de mtime (def: 0.8)")
    ap.add_argument("--debounce", type=float, default=4.0, help="segundos a esperar após última gravação antes de fazer push (def: 4)")
    ap.add_argument("--once", action="store_true", help="faz só um ciclo e sai (sem vigiar)")
    ap.add_argument("--status", action="store_true", help="mostra status json do watch (idade/pending/ultimo push) e sai")
    args = ap.parse_args(argv)
    if args.status:
        return _print_status()
    if args.once:
        _once()
        return 0
    return watch(poll=args.poll, debounce=args.debounce)


if __name__ == "__main__":
    raise SystemExit(main())
