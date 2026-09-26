#!/usr/bin/env python3
"""Servidor de visitas do portfolio (srrobs-portfolio).

Regista visitas e cliques em repos GitHub por IP e por "device id"
(UUID gerado no browser — aproximação de HWID, já que o browser não
expõe HWID real). Serve o site estático e expõe /api/visitas.

Só usa a biblioteca padrão do Python.
"""

import argparse
import json
import os
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

AQUI = Path(__file__).resolve().parent
ROOT = AQUI.parent

PORTA_BASE = 8766
ONLINE_SEGUNDOS = 60
SESSAO_SEGUNDOS = 1800
LIMITE_ASSOC = 50

_LOCK = threading.RLock()
_DB_PATH = [None]

_EVENTOS = ("visit", "ping", "github_click")

_CONTENT_TYPES = {
    ".css": "text/css; charset=utf-8",
    ".gif": "image/gif",
    ".html": "text/html; charset=utf-8",
    ".ico": "image/x-icon",
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".txt": "text/plain; charset=utf-8",
    ".webp": "image/webp",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
}


def _db_padrao():
    return ROOT / "var" / "visitas_portfolio.json"


def _db():
    return Path(_DB_PATH[0]) if _DB_PATH[0] else _db_padrao()


def carregar(caminho):
    caminho = Path(caminho)
    if not caminho.exists():
        return {"ips": {}, "devices": {}}
    try:
        with caminho.open("r", encoding="utf-8") as fh:
            dados = json.load(fh)
    except (OSError, ValueError):
        return {"ips": {}, "devices": {}}
    if not isinstance(dados, dict):
        return {"ips": {}, "devices": {}}
    for campo in ("ips", "devices"):
        if not isinstance(dados.get(campo), dict):
            dados[campo] = {}
    return dados


def guardar(caminho, dados):
    caminho = Path(caminho)
    caminho.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(caminho.parent), prefix=".visitas-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(dados, fh, ensure_ascii=False, indent=2, sort_keys=True)
        os.replace(tmp, caminho)
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def _registo(dados, grupo, chave, agora):
    tabela = dados.setdefault(grupo, {})
    rec = tabela.get(chave)
    if not isinstance(rec, dict):
        rec = {
            "visitas": 0,
            "github": 0,
            "online": agora,
            "last": agora,
            "_contou": False,
            "devices": {},
            "ips": {},
        }
        tabela[chave] = rec
    return rec


def _associa(rec, campo, valor, limite=LIMITE_ASSOC):
    mapa = rec.setdefault(campo, {})
    if valor:
        mapa[valor] = mapa.get(valor, 0) + 1
        while len(mapa) > limite:
            rec[campo] = dict(sorted(mapa.items(), key=lambda kv: kv[1])[:limite])
            mapa = rec[campo]
            break
    return rec


def _aplica(rec, agora, evento):
    if agora < float(rec.get("last", agora)):
        return  # heartbeat antigo, fora de ordem: no-op
    if agora - float(rec.get("last", agora)) > SESSAO_SEGUNDOS:
        rec["_contou"] = False
    if not rec.get("_contou"):
        rec["visitas"] = int(rec.get("visitas", 0)) + 1
        rec["_contou"] = True
    if evento == "github_click":
        rec["github"] = int(rec.get("github", 0)) + 1
    rec["online"] = agora
    rec["last"] = agora


def registar(dados, ip, device, evento, agora=None):
    """Regista um evento (visit|ping|github_click) para ip/device."""
    if evento not in _EVENTOS:
        evento = "ping"
    if agora is None:
        agora = time.time()
    agora = float(agora)
    chave_ip = str(ip or "desconhecido")
    chave_device = str(device or "").strip()[:64]
    ip_rec = _registo(dados, "ips", chave_ip, agora)
    alvos = [ip_rec]
    if chave_device:
        dev_rec = _registo(dados, "devices", chave_device, agora)
        alvos.append(dev_rec)
        _associa(ip_rec, "devices", chave_device)
        _associa(dev_rec, "ips", chave_ip)
    for rec in alvos:
        _aplica(rec, agora, evento)
    return dados


def _escrever_stats(dados):
    agora = time.time()

    def tabela(grupo):
        saida = []
        for chave, rec in (dados.get(grupo) or {}).items():
            links = rec.get("devices") or rec.get("ips") or {}
            saida.append(
                {
                    "id": chave,
                    "visitas": int(rec.get("visitas", 0)),
                    "github": int(rec.get("github", 0)),
                    "online": bool(agora - float(rec.get("online", 0)) <= ONLINE_SEGUNDOS),
                    "last": float(rec.get("last", 0)),
                    "devices": sorted(str(k) for k in links.keys()),
                }
            )
        saida.sort(key=lambda r: r["last"], reverse=True)
        return saida

    por_ip = tabela("ips")
    por_device = tabela("devices")
    return {
        "agora": agora,
        "online_agora": sum(1 for r in por_device if r["online"]),
        "ips_online": sum(1 for r in por_ip if r["online"]),
        "total_visitas": sum(r["visitas"] for r in por_ip),
        "total_github": sum(r["github"] for r in por_ip),
        "por_ip": por_ip,
        "por_device": por_device,
    }


def stats(caminho=None):
    with _LOCK:
        dados = carregar(caminho or _db())
        return _escrever_stats(dados)


class VisitasHandler(BaseHTTPRequestHandler):
    server_version = "srrobsVisitas/1.0"

    def log_message(self, fmt, *args):  # pragma: no cover
        if getattr(self.server, "srrobs_verbose", False):
            super().log_message(fmt, *args)

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def _json(self, payload, codigo=200):
        corpo = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self._cors()
        self.end_headers()
        self.wfile.write(corpo)

    def _ip(self):
        host = self.client_address[0] if self.client_address else ""
        xff = self.headers.get("X-Forwarded-For") if self.headers else ""
        if xff:
            return str(xff.split(",")[0].strip())
        return str(host) or "desconhecido"

    def _ficheiro(self, caminho):
        raiz = Path(getattr(self.server, "srrobs_root", ROOT)).resolve()
        alvo = (raiz / caminho.lstrip("/")).resolve()
        try:
            alvo.relative_to(raiz)
        except ValueError:
            return self._json({"erro": "caminho proibido"}, 403)
        if alvo.is_dir():
            alvo = alvo / "index.html"
        if not alvo.is_file():
            return self._json({"erro": "nao encontrado"}, 404)
        tipo = _CONTENT_TYPES.get(alvo.suffix.lower(), "application/octet-stream")
        try:
            corpo = alvo.read_bytes()
        except OSError:
            return self._json({"erro": "nao encontrado"}, 404)
        self.send_response(200)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        self._cors()
        self.end_headers()
        self.wfile.write(corpo)

    def _responder_stats(self):
        with _LOCK:
            dados = carregar(_db())
            payload = _escrever_stats(dados)
        self._json({"ok": True, "stats": payload})

    def do_GET(self):
        rota = self.path.split("?", 1)[0]
        if rota == "/api/visitas":
            return self._responder_stats()
        if rota in ("/", "/index.html"):
            return self._ficheiro("index.html")
        return self._ficheiro(rota)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        rota = self.path.split("?", 1)[0]
        if rota != "/api/visitas":
            return self._json({"erro": "rota desconhecida"}, 404)
        tamanho = int(self.headers.get("Content-Length") or 0)
        bruto = self.rfile.read(tamanho) if tamanho > 0 else b""
        device = ""
        evento = "ping"
        try:
            corpo = json.loads(bruto.decode("utf-8") or "{}")
            if isinstance(corpo, dict):
                device = str(corpo.get("device") or "")
                evento = str(corpo.get("event") or corpo.get("evento") or "ping")
        except (ValueError, UnicodeDecodeError):
            corpo = {}
        with _LOCK:
            dados = carregar(_db())
            registar(dados, self._ip(), device[:64], evento)
            guardar(_db(), dados)
            payload = _escrever_stats(dados)
        self._json({"ok": True, "stats": payload})


def arrancar(porta=PORTA_BASE, root=None, db=None, verbose=False):
    _DB_PATH[0] = str(db) if db else None
    servidor = ThreadingHTTPServer(("0.0.0.0", porta), VisitasHandler)
    servidor.srrobs_root = Path(root).resolve() if root else ROOT
    servidor.srrobs_verbose = bool(verbose)
    return servidor


def main(argv=None):
    parser = argparse.ArgumentParser(description="Servidor de visitas do portfolio")
    parser.add_argument("--port", type=int, default=PORTA_BASE)
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--db", default=str(_db_padrao()))
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv)
    servidor = arrancar(porta=args.port, root=args.root, db=args.db, verbose=args.verbose)
    print(f"srrobs visitas a escutar em http://0.0.0.0:{args.port} (db={args.db})")
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        servidor.server_close()


if __name__ == "__main__":
    main()
