import json
import os
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import srrobs_visitas as sv  # noqa: E402

AGORA = 1_000_000.0


class TestCarregarGuardar(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.caminho = os.path.join(self.tmp.name, "db.json")

    def test_carregar_inexistente(self):
        dados = sv.carregar(self.caminho)
        self.assertEqual(dados, {"ips": {}, "devices": {}})
        self.assertFalse(os.path.exists(self.caminho))

    def test_carregar_corrompido(self):
        with open(self.caminho, "w", encoding="utf-8") as f:
            f.write("isto nao e json{{{")
        self.assertEqual(sv.carregar(self.caminho), {"ips": {}, "devices": {}})

    def test_guardar_e_recarregar(self):
        dados = {"ips": {}, "devices": {}}
        sv.registar(dados, "1.1.1.1", "dev-a", "visit", agora=AGORA)
        sv.guardar(self.caminho, dados)
        re = sv.carregar(self.caminho)
        self.assertEqual(re["ips"]["1.1.1.1"]["visitas"], 1)
        self.assertEqual(re["devices"]["dev-a"]["visitas"], 1)


class TestRegistar(unittest.TestCase):
    def setUp(self):
        self.dados = {"ips": {}, "devices": {}}

    def test_primeiro_ping_conta_visita(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "ping", agora=AGORA)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["visitas"], 1)
        self.assertEqual(self.dados["devices"]["dev-a"]["visitas"], 1)

    def test_mesma_sessao_nao_duplica(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "visit", agora=AGORA)
        sv.registar(self.dados, "1.1.1.1", "dev-a", "ping", agora=AGORA + 60)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["visitas"], 1)

    def test_heartbeat_fora_de_ordem_noop(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "ping", agora=AGORA + 100)
        sv.registar(self.dados, "1.1.1.1", "dev-a", "ping", agora=AGORA)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["visitas"], 1)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["last"], AGORA + 100)

    def test_gap_grande_nova_visita(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "visit", agora=AGORA)
        sv.registar(self.dados, "1.1.1.1", "dev-a", "ping", agora=AGORA + sv.SESSAO_SEGUNDOS + 5)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["visitas"], 2)

    def test_visit_nao_duplica_na_mesma_sessao(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "visit", agora=AGORA)
        sv.registar(self.dados, "1.1.1.1", "dev-a", "visit", agora=AGORA + 30)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["visitas"], 1)

    def test_evento_invalido_vira_ping(self):
        sv.registar(self.dados, "1.1.1.1", None, "hacker", agora=AGORA)
        rec = self.dados["ips"]["1.1.1.1"]
        self.assertEqual(rec["visitas"], 1)
        self.assertEqual(rec["github"], 0)

    def test_github_click_incrementa_ip_e_device(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "github_click", agora=AGORA)
        self.assertEqual(self.dados["ips"]["1.1.1.1"]["github"], 1)
        self.assertEqual(self.dados["devices"]["dev-a"]["github"], 1)

    def test_associacoes_cruzadas(self):
        sv.registar(self.dados, "1.1.1.1", "dev-a", "visit", agora=AGORA)
        sv.registar(self.dados, "2.2.2.2", "dev-a", "visit", agora=AGORA + 10)
        self.assertIn("dev-a", self.dados["ips"]["1.1.1.1"]["devices"])
        self.assertIn("1.1.1.1", self.dados["devices"]["dev-a"]["ips"])
        self.assertIn("2.2.2.2", self.dados["devices"]["dev-a"]["ips"])

    def test_device_vazio_somente_ip(self):
        sv.registar(self.dados, "1.1.1.1", "", "visit", agora=AGORA)
        self.assertIn("1.1.1.1", self.dados["ips"])
        self.assertEqual(self.dados["devices"], {})

    def test_device_longo_truncado(self):
        sv.registar(self.dados, "1.1.1.1", "x" * 200, "visit", agora=AGORA)
        self.assertEqual(len(self.dados["devices"]), 1)
        chave = next(iter(self.dados["devices"]))
        self.assertLessEqual(len(chave), 64)

    def test_associacao_limite(self):
        dados = self.dados
        for i in range(60):
            sv.registar(dados, f"10.0.0.{i}", "dev-a", "ping", agora=AGORA + i)
        rec = dados["devices"]["dev-a"]
        self.assertLessEqual(len(rec["ips"]), sv.LIMITE_ASSOC)


class TestStats(unittest.TestCase):
    def test_stats_totais_e_tabelas(self):
        dados = {"ips": {}, "devices": {}}
        sv.registar(dados, "1.1.1.1", "dev-a", "visit", agora=AGORA)
        sv.registar(dados, "1.1.1.1", "dev-a", "github_click", agora=AGORA + 1)
        sv.registar(dados, "2.2.2.2", None, "visit", agora=AGORA + 2)
        s = sv._escrever_stats(dados)
        self.assertEqual(s["total_visitas"], 2)
        self.assertEqual(s["total_github"], 1)
        self.assertEqual(len(s["por_ip"]), 2)
        self.assertEqual(len(s["por_device"]), 1)
        ip1 = next(r for r in s["por_ip"] if r["id"] == "1.1.1.1")
        self.assertEqual(ip1["github"], 1)
        self.assertEqual(ip1["devices"], ["dev-a"])


class TestServidorHTTP(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name) / "site"
        cls.root.mkdir()
        (cls.root / "index.html").write_text("<html>portfolio</html>", encoding="utf-8")
        cls.db = str(Path(cls.tmp.name) / "db.json")
        cls.srv = sv.arrancar(porta=0, root=str(cls.root), db=cls.db)
        cls.porta = cls.srv.server_address[1]
        cls.base = f"http://127.0.0.1:{cls.porta}"
        cls.thread = threading.Thread(target=cls.srv.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.server_close()
        cls.srv.shutdown()
        cls.tmp.cleanup()

    def _pedido(self, rota, corpo=None, metodo=None, headers=None):
        data = json.dumps(corpo).encode() if corpo is not None else None
        req = urllib.request.Request(
            self.base + rota, data=data, method=metodo or ("POST" if data else "GET")
        )
        if data:
            req.add_header("Content-Type", "application/json")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, r.read().decode("utf-8"), dict(r.headers)

    def _pedido_erro(self, rota, metodo="GET"):
        req = urllib.request.Request(self.base + rota, method=metodo)
        try:
            urllib.request.urlopen(req, timeout=5)
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8")
        self.fail(f"esperava erro em {rota}")

    def test_options_cors(self):
        _, _, headers = self._pedido("/api/visitas", metodo="OPTIONS")
        self.assertEqual(headers.get("Access-Control-Allow-Origin"), "*")

    def test_post_visit(self):
        codigo, texto, _ = self._pedido("/api/visitas", corpo={"device": "dev-1", "event": "visit"})
        self.assertEqual(codigo, 200)
        payload = json.loads(texto)
        self.assertTrue(payload["ok"])
        self.assertGreaterEqual(payload["stats"]["total_visitas"], 1)

    def test_get_stats(self):
        self._pedido("/api/visitas", corpo={"device": "dev-2", "event": "ping"})
        _, texto, _ = self._pedido("/api/visitas")
        payload = json.loads(texto)
        self.assertTrue(payload["ok"])
        # API publica nao expõe por_ip/por_device (privacidade)
        self.assertNotIn("por_ip", payload["stats"])
        self.assertNotIn("por_device", payload["stats"])
        self.assertIn("total_visitas", payload["stats"])
        self.assertIn("total_ips", payload["stats"])
        self.assertIn("total_devices", payload["stats"])

    def test_post_github_click(self):
        _, antes, _ = self._pedido("/api/visitas")
        g0 = json.loads(antes)["stats"]["total_github"]
        self._pedido("/api/visitas", corpo={"device": "dev-1", "event": "github_click"})
        _, depois, _ = self._pedido("/api/visitas")
        g1 = json.loads(depois)["stats"]["total_github"]
        self.assertEqual(g1, g0 + 1)

    def test_index(self):
        for rota in ("/", "/index.html"):
            codigo, corpo, _ = self._pedido(rota)
            self.assertEqual(codigo, 200)
            self.assertIn("portfolio", corpo)

    def test_traversal_proibido(self):
        codigo, corpo = self._pedido_erro("/../db.json")
        self.assertEqual(codigo, 403)
        self.assertIn("proibido", corpo)

    def test_404(self):
        codigo, corpo = self._pedido_erro("/nao-existe.txt")
        self.assertEqual(codigo, 404)
        self.assertIn("nao encontrado", corpo)

    def test_post_rota_errada(self):
        codigo, corpo = self._pedido_erro("/api/outra", metodo="POST")
        self.assertEqual(codigo, 404)
        self.assertIn("rota desconhecida", corpo)

    def test_x_forwarded_for(self):
        self._pedido(
            "/api/visitas",
            corpo={"device": "dev-xff", "event": "ping"},
            headers={"X-Forwarded-For": "9.9.9.9, 10.0.0.1"},
        )
        # API publica nao expõe IPs — verifica no ficheiro interno
        import time as _time  # noqa: F401
        dados = sv.carregar(self.db)
        interno = sv._escrever_stats(dados)
        ids = [r["id"] for r in interno["por_ip"]]
        self.assertIn("9.9.9.9", ids)
        # API continua a responder só agregados
        _, texto, _ = self._pedido("/api/visitas")
        pub = json.loads(texto)["stats"]
        self.assertNotIn("por_ip", pub)
        self.assertGreaterEqual(pub["total_ips"], 1)

    def test_json_invalido_vira_ping(self):
        req = urllib.request.Request(
            self.base + "/api/visitas", data=b"nao-json", method="POST"
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            payload = json.loads(r.read().decode("utf-8"))
        self.assertTrue(payload["ok"])


if __name__ == "__main__":
    unittest.main()
