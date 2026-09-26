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
        # autopush.log é gitignored — nunca vai para o git
        with LOG.open("a", encoding="utf-8", errors="ignore") as fh:
            fh.write(line)
    except Exception:
        pass
    # também stdout para quem vê a janela
    try:
        print(line, end="", flush=True)
    except Exception:
        pass


def _run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore", **kw)


def _git_ls_tracked() -> list[str]:
    r = _run(["git", "ls-files", "-z"], cwd=str(ROOT))
    if r.returncode != 0 or not r.stdout:
        return []
    # -z separa por \0
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
    """True só se contadores reais mudaram (ignora 'agora' que muda sempre).
    Evita push infinito só por causa do timestamp."""
    import tempfile

    try:
        # snapshot actual no disco
        actual = json.loads((ROOT / "visitas_totals.json").read_text(encoding="utf-8"))
        # snapshot que seria gerado
        sys.path.insert(0, str(AQUI))
        import srrobs_visitas as sv  # type: ignore

        sv._DB_PATH[0] = str(ROOT / "var" / "visitas_portfolio.json")
        dados = sv.carregar(sv._db())
        snap = sv._public_stats(dados)
        # compara só contadores, ignora 'agora'
        keys = ("total_visitas", "total_github", "total_ips", "total_devices", "ips_online", "online_agora")
        for k in keys:
            if actual.get(k) != snap.get(k):
                return True
        # também detecta se o ficheiro não existe ou está corrompido
        return False
    except Exception:
        # se não consegue ler actual, força um _snapshot e verifica diff
        try:
            _snapshot()
            r = _run(["git", "diff", "--quiet", "--", "visitas_totals.json"], cwd=str(ROOT))
            return r.returncode != 0
        except Exception:
            return False


def _guard_blocked() -> bool:
    """True se staged diff contém identificador pessoal fora de autopush.*"""
    r = _run(["git", "diff", "--cached", "--no-color", "--"], cwd=str(ROOT))
    diff = (r.stdout or "").lower()
    if not diff:
        return False
    # se o diff só mexe em autopush.*, ignora (o ficheiro contém os b64)
    rn = _run(["git", "diff", "--cached", "--name-only", "-z"], cwd=str(ROOT))
    names = (rn.stdout or "").split("\0") if rn.stdout else []
    # filtra ficheiros autopush do diff para não auto-bloquear
    # re-calcula diff sem eles
    non_auto = [n for n in names if n and "autopush" not in n.lower()]
    if non_auto:
        r2 = _run(["git", "diff", "--cached", "--no-color", "--"] + non_auto, cwd=str(ROOT))
        diff2 = (r2.stdout or "").lower()
    else:
        diff2 = "" if any("autopush" in (n or "").lower() for n in names) and len(names) == 1 else diff
        # se só autopush mudou, considera limpo
        if diff2 == "" and names:
            return False
        diff2 = diff if not non_auto else diff2
    hits = [b for b in _BAD if b in diff2]
    if hits:
        _log(f"BLOCKED personal no staged diff: {hits}")
        return True
    return False


def _once() -> bool:
    """Um ciclo: snapshot + add + guard + commit + pull/push. Devolve True se fez push."""
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
            # mesmo abortado, tenta pull/push na mesma (pode haver commits locais antigos já seguros)
            _run(["git", "pull", "--rebase", "--autostash", "origin", "main"], cwd=str(ROOT))
            _run(["git", "push", "origin", "main"], cwd=str(ROOT))
            _log("ciclo concluido (bloqueado)")
            return False

    r = _run(["git", "diff", "--cached", "--quiet"], cwd=str(ROOT))
    has_staged = r.returncode != 0
    if has_staged:
        _run(["git", "commit", "-m", f"auto: sync {time.strftime('%d/%m/%Y %H:%M:%S')}"], cwd=str(ROOT))
    # pull rebase antes de push para não criar merges
    _run(["git", "pull", "--rebase", "--autostash", "origin", "main"], cwd=str(ROOT))
    pr = _run(["git", "push", "origin", "main"], cwd=str(ROOT))
    if pr.returncode != 0 and has_staged:
        _log("aviso: push falhou (sem net ou conflito)")
    _log("ciclo concluido")
    return has_staged or pr.returncode == 0


def _collect_watched() -> list[Path]:
    tracked = _git_ls_tracked()
    # sempre inclui visitas_totals.json mesmo que não esteja tracked? já está, mas garante
    extra = ["visitas_totals.json"]
    out: list[Path] = []
    seen = set()
    for rel in tracked + extra:
        if not rel or rel in seen:
            continue
        seen.add(rel)
        p = (ROOT / rel).resolve()
        # só ficheiros existentes; pastas ignoradas já não estão no ls
        if p.is_file():
            out.append(p)
    # também vigia index.html/app.js/etc mesmo se git ainda não os conhece?
    # git add -u já cobre, então só precisamos dos tracked
    return out


def watch(poll: float = 0.8, debounce: float = 4.0) -> int:
    print(f"[watch] repo: {ROOT}", flush=True)
    print(f"[watch] a vigiar {_collect_watched().__len__()} ficheiros tracked + visitas_totals.json", flush=True)
    print(f"[watch] poll {poll}s  debounce {debounce}s  — grava um ficheiro e eu faço push. Ctrl+C para parar.", flush=True)
    _log(f"watch iniciado poll={poll}s debounce={debounce}s")

    # estado mtime/size
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
    # push inicial se já há diff tracked por comitar (ex: abriste já com alterações)
    # NÃO conta ?? untracked — evita push espúrio por ficheiros novos não adicionados (leak-proof: add -u)
    try:
        r1 = _run(["git", "diff", "--quiet"], cwd=str(ROOT))
        r2 = _run(["git", "diff", "--cached", "--quiet"], cwd=str(ROOT))
        has_tracked_diff = (r1.returncode != 0) or (r2.returncode != 0)
        # snapshot: só considera diff real em contadores (ignora 'agora' que muda sempre)
        needs_snapshot = _snapshot_needs_push()
        if has_tracked_diff or needs_snapshot:
            _log("diff inicial detectado — push imediato")
            _once()
            watched = _collect_watched()
            state = {p: _stat(p) for p in watched}
    except Exception:
        pass

    try:
        while True:
            time.sleep(poll)
            now = time.time()
            # re-scan lista de tracked a cada 10s (caso faças git add de ficheiro novo)
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
            for p in list(watched):
                cur = _stat(p)
                prev = state.get(p)
                if cur != prev:
                    # ignora mudanças só de leitura do log / var (já não vigiados, mas por precaução)
                    # e ignora visitas_totals.json tocado pelo nosso próprio _once? Não — queremos push,
                    # mas evita loop: _once já atualiza visitas_totals; detectamos e debouncamos.
                    state[p] = cur
                    changed = True

            # também detecta ficheiro novo/removido
            for p in watched:
                if p not in state:
                    state[p] = _stat(p)
                    changed = True

            if changed:
                if pending_since is None:
                    _log("watch: alteração detectada — a aguardar debounce...")
                pending_since = now

            # snapshot externo: se visitas mudaram no disco fora do watch (raro), também pending
            # já está coberto por watched incluindo visitas_totals.json

            if pending_since is not None and (now - pending_since) >= debounce:
                _log("watch: debounce expirado — a fazer push")
                pending_since = None
                _once()
                watched = _collect_watched()
                state = {p: _stat(p) for p in watched}
                last_rescan = now
                last_snapshot_check = now

            # watchdog de visitas: só faz push se contadores reais mudarem (ignora 'agora')
            if now - last_snapshot_check > 30 and pending_since is None:
                last_snapshot_check = now
                try:
                    if _snapshot_needs_push():
                        _log("watch: visitas novas — a fazer push do snapshot")
                        _once()
                        watched = _collect_watched()
                        state = {p: _stat(p) for p in watched}
                        last_rescan = now
                except Exception:
                    pass
    except KeyboardInterrupt:
        _log("watch parado (Ctrl+C)")
        print("\n[watch] parado.", flush=True)
        return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Vigia e faz auto-push até parares (Ctrl+C)")
    ap.add_argument("--poll", type=float, default=0.8, help="segundos entre varrimentos de mtime (def: 0.8)")
    ap.add_argument("--debounce", type=float, default=4.0, help="segundos a esperar após última gravação antes de fazer push (def: 4)")
    ap.add_argument("--once", action="store_true", help="faz só um ciclo e sai (sem vigiar)")
    args = ap.parse_args(argv)
    if args.once:
        _once()
        return 0
    return watch(poll=args.poll, debounce=args.debounce)


if __name__ == "__main__":
    raise SystemExit(main())
