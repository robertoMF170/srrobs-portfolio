# Dev Portfolio — ewan-kerboas.fr inspired

> Portfolio brutalista **preto / branco / vermelho** para Utilizador (Dev) — Operação **Mainframe / Control-M**, Python & Web nos tempos livres.

![Design](https://img.shields.io/badge/design-brutalist_OS-black) ![Colors](https://img.shields.io/badge/preto-%23070707-black) ![Red](https://img.shields.io/badge/vermelho-%23E30613-red) ![Lenis](https://img.shields.io/badge/Lenis-smooth_scroll-blue)

Live: `https://SEU_USER.github.io/SEU_REPO` (após ativar GitHub Pages)

## O que tem

- **Loader** `DEV_OS — BOOT` com barra + `%` + wipe.
- **Taskbar** fixa + **marquee** de stack + **scroll-progress** vermelho.
- **Hero** com tipografia `Space Grotesk` + **Stagger** linha a linha.
- **13 projetos** em grelha filtrável (`TODOS / TRADING / GAMES / BOTS / UTILS`) + **modal** com “O que faz + Arquitetura + ficheiros-chave” — tudo já documentado do `D:\`.
- **Animações premium**: Lenis smooth scroll, parallax grid, cursor custom (anel+dot), magnetic nos botões, tilt 3D nas janelas, reveals por `IntersectionObserver`.

## Stack

HTML + CSS + JS vanilla, Lenis 1.1.18 (smooth scroll), Space Grotesk + JetBrains Mono + Instrument Serif, GitHub Pages

## Como correr local

```bash
git clone https://github.com/SEU_USER/SEU_REPO.git
cd SEU_REPO
# Sem build — só abrir
start index.html        # Windows
open index.html         # Mac
# ou com servidor local (evita CORS do Lenis CDN)
npx serve .
# ou
python -m http.server 8000
```

## Como publicar no GitHub Pages

1. No repo `SEU_REPO` → `Settings` → `Pages`.
2. `Source: Deploy from a branch` → `Branch: main` → `/ (root)` → Save.
3. Aguarda 1–2 min → URL aparece no topo de `Pages`.

## Estrutura

```
index.html      # 4 janelas: hero, sobre, projetos (12 cards + filtros), stack, contacto + modal
style.css       # brutalist OS: --black #070707, --white #F4F4F2, --red #E30613
app.js          # Lenis + reveals + cursor + magnetic + filtros + PLACEHOLDER_DATA (12) + tilt
```

## Projetos documentados (12)

| # | Nome | Badge | Stack |
|---|---|---|---|
| 01 | Skin Trader Pro | CS2 SNIPRE | Flask, SQLite WAL |
| 02 | Free Games | STEAM GAMES | Node 20, discord.js |
| 03 | Farmer Bot — CS2 | DEV FARMER | CustomTkinter, Arduino |
| 04 | OKX SuperTrend AI Scanner | OKX SCANNER | FastAPI, OKX |
| 05 | Confluence Engine | PINE CODE | Pine v5, MQL5, Tampermonkey |
| 06 | Kronos — K-Lines | KRONOS | Transformer, CCXT |
| 07 | Fimathe Cycle + PCM | FIMAYHE | Pine v6, ATR, PCM |
| 08 | PokeMMO Bot | POKEMMO | Tkinter, pytesseract |
| 09 | Bets Converter | BETS CONVERTER | Flask, BS4, Paqbet |
| 10 | MT2Bot Lite | MT2DEV | eXLib.mix, Gameforge |
| 11 | TaskBarHero Toolkit | TBH TOOLKIT | Sandboxie, mss |
| 12 | MT2Guide — Quest Helper | MT2GUIDE | eXLib.mix, Python, Client-side |
| 13 | Laboratório de Testes e Análises — CSGO500 (Casino) | CSGO500 — CASINO | Tampermonkey, OpenCV |

> Cada card → `VER DETALHES ↗` → modal com bullets do que cada projeto **é e faz** (sem `D:\`, sem lore de disco).

## Autor

Utilizador (Dev) — https://github.com/SEU_USER · Inspirado em https://ewan-kerboas.fr
