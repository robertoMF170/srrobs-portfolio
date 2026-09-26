// ========== LOADER ==========
(function loader(){
  const loaderEl = document.getElementById('loader');
  const bar = document.getElementById('loaderBar');
  const pct = document.getElementById('loaderPercent');
  const cnt = document.getElementById('loaderCount');
  if(!loaderEl || !bar) return;
  let p = 0;
  const target = 100;
  const tick = () => {
    p += Math.random()*16 + 7;
    if(p >= target) p = target;
    const ip = Math.floor(p);
    bar.style.width = ip + '%';
    if(pct) pct.textContent = String(ip).padStart(3,'0') + '%';
    if(cnt) cnt.textContent = String(ip).padStart(3,'0');
    if(p < target){
      setTimeout(tick, 42 + Math.random()*88);
    } else {
      setTimeout(()=>{
        loaderEl.classList.add('hidden');
        document.body.classList.add('loaded');
        const heroTitle = document.querySelector('.hero-title');
        if(heroTitle) heroTitle.classList.add('is-in');
        const heroProg = document.getElementById('heroProgress');
        const heroNum = document.getElementById('heroProgressNum');
        if(heroProg) setTimeout(()=> heroProg.style.width='68%', 240);
        if(heroNum){
          let n=0; const iv=setInterval(()=>{ n+=2; if(n>=68){n=68; clearInterval(iv);} heroNum.textContent=n; }, 22);
        }
        setTimeout(()=> loaderEl.remove(), 950);
      }, 380);
    }
  };
  setTimeout(tick, 180);
})();

// ========== LENIS SMOOTH SCROLL ==========
let lenis = null;
(function initLenis(){
  const hasLenis = typeof window.Lenis !== 'undefined';
  if(hasLenis){
    lenis = new window.Lenis({
      duration: 1.05,
      easing: (t)=> Math.min(1, 1.001 - Math.pow(2, -10*t)),
      smoothWheel: true,
      smoothTouch: false,
      touchMultiplier: 1.4,
    });
    document.documentElement.classList.add('lenis');
    function raf(time){
      lenis.raf(time);
      requestAnimationFrame(raf);
    }
    requestAnimationFrame(raf);
  }
})();

// ========== CLOCK ==========
function tickClock(){
  const t = new Date().toLocaleTimeString('pt-PT',{hour12:false});
  const el = document.getElementById('clock');
  const foot = document.getElementById('footerClock');
  if(el) el.textContent = t;
  if(foot) foot.textContent = t;
}
setInterval(tickClock,1000); tickClock();

// ========== SCROLL PROGRESS + TASKBAR + PARALLAX ==========
const scrollBar = document.getElementById('scrollProgress');
const taskbar = document.getElementById('taskbar');
const parallaxGrid = document.getElementById('parallaxGrid');
const bigType = document.getElementById('bigType');
function onScrollProgress(){
  const y = window.scrollY;
  const h = document.documentElement.scrollHeight - window.innerHeight;
  const p = h > 0 ? (y / h) * 100 : 0;
  if(scrollBar) scrollBar.style.width = p + '%';
  if(taskbar) taskbar.classList.toggle('scrolled', y > 16);
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(!prefersReduced){
    if(parallaxGrid) parallaxGrid.style.transform = `translateY(${y * 0.12}px)`;
    if(bigType) bigType.style.transform = `translateY(${y * 0.18}px) translateX(${y * -0.02}px)`;
  }
}
window.addEventListener('scroll', onScrollProgress, {passive:true});
if(lenis) lenis.on('scroll', onScrollProgress);
onScrollProgress();

document.querySelectorAll('a[href^="#"]').forEach(a=>{
  a.addEventListener('click', e=>{
    const href = a.getAttribute('href');
    if(!href || href==='#') return;
    const target = document.querySelector(href);
    if(!target) return;
    e.preventDefault();
    if(lenis){
      lenis.scrollTo(target, { offset: -64, duration: 1.0 });
    } else {
      target.scrollIntoView({behavior:'smooth', block:'start'});
    }
  });
});

// ========== REVEAL OBSERVER ==========
const revealEls = document.querySelectorAll('.reveal');
const io = new IntersectionObserver((entries)=>{
  entries.forEach(entry=>{
    if(entry.isIntersecting){
      entry.target.classList.add('in');
      const nums = entry.target.querySelectorAll('[data-count]');
      nums.forEach(n=> animateCount(n));
      if(entry.target.id==='hero'){
        const ht = entry.target.querySelector('.hero-title');
        if(ht && !ht.classList.contains('is-in')){
          setTimeout(()=> ht.classList.add('is-in'), 120);
        }
      }
      io.unobserve(entry.target);
    }
  });
}, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
revealEls.forEach(el=> io.observe(el));
setTimeout(()=>{
  revealEls.forEach(el=>{
    const r=el.getBoundingClientRect();
    if(r.top < window.innerHeight * 0.9) el.classList.add('in');
  });
  const ht=document.querySelector('.hero-title');
  if(ht) setTimeout(()=>ht.classList.add('is-in'), 800);
}, 900);

// ========== COUNT-UP ==========
function animateCount(el){
  if(el.dataset.done) return;
  el.dataset.done='1';
  const target = parseInt(el.getAttribute('data-count'),10);
  if(isNaN(target)) return;
  let cur=0;
  const steps=28;
  let i=0;
  const iv=setInterval(()=>{
    i++;
    cur = Math.round((i/steps)*target);
    if(i>=steps){ cur=target; clearInterval(iv); }
    el.textContent = cur;
  }, 28);
}
document.querySelectorAll('.stat-num[data-count]').forEach(el=>{
  const r=el.getBoundingClientRect();
  if(r.top < window.innerHeight) setTimeout(()=>animateCount(el), 1400);
});

// ========== CUSTOM CURSOR ==========
(function cursor(){
  const cursor = document.getElementById('cursor');
  const dot = document.getElementById('cursorDot');
  if(!cursor || !dot) return;
  if(window.matchMedia('(hover:none)').matches || window.innerWidth <= 860) return;
  document.body.classList.add('has-cursor');
  let mx=0,my=0, cx=0,cy=0;
  let hovering=false;
  window.addEventListener('mousemove', e=>{
    mx=e.clientX; my=e.clientY;
    dot.style.transform = `translate(${mx}px, ${my}px)`;
  });
  function raf(){
    cx += (mx - cx) * 0.14;
    cy += (my - cy) * 0.14;
    cursor.style.transform = `translate(${cx}px, ${cy}px)` + (hovering ? ' scale(1.6)' : '');
    requestAnimationFrame(raf);
  }
  raf();
  const hovers = document.querySelectorAll('a, button, .window, .project-card, .contact-card, .filter-btn');
  hovers.forEach(el=>{
    el.addEventListener('mouseenter', ()=>{ hovering=true; cursor.classList.add('hover'); });
    el.addEventListener('mouseleave', ()=>{ hovering=false; cursor.classList.remove('hover'); });
  });
  document.addEventListener('mouseleave', ()=>{ cursor.style.opacity='0'; dot.style.opacity='0'; });
  document.addEventListener('mouseenter', ()=>{ cursor.style.opacity='1'; dot.style.opacity='1'; });
})();

// ========== MAGNETIC BUTTONS ==========
(function magnetic(){
  const els = document.querySelectorAll('[data-magnetic]');
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(reduced) return;
  els.forEach(el=>{
    let bounds=null;
    el.addEventListener('mouseenter', ()=>{ bounds=el.getBoundingClientRect(); });
    el.addEventListener('mousemove', e=>{
      if(!bounds) bounds=el.getBoundingClientRect();
      const x = e.clientX - (bounds.left + bounds.width/2);
      const y = e.clientY - (bounds.top + bounds.height/2);
      const mx = x * 0.18;
      const my = y * 0.28;
      el.style.transform = `translate(${mx}px, ${my}px)`;
    });
    el.addEventListener('mouseleave', ()=>{
      el.style.transform = 'translate(0,0)';
    });
  });
})();

// ========== PROJECT FILTERS ==========
const filterBtns = document.querySelectorAll('.filter-btn');
const filterIndicator = document.getElementById('filterIndicator');
const projectCards = document.querySelectorAll('.project-card');
const filterCountEl = document.getElementById('filterCount');
function updateFilterIndicator(){
  const active = document.querySelector('.filter-btn.active');
  const bar = document.querySelector('.filter-bar');
  if(!active || !bar || !filterIndicator) return;
  const barRect = bar.getBoundingClientRect();
  const rect = active.getBoundingClientRect();
  const w = rect.width;
  const x = rect.left - barRect.left + bar.scrollLeft;
  filterIndicator.style.width = w + 'px';
  filterIndicator.style.transform = `translateX(${x}px)`;
}
function applyFilter(filter){
  let visible=0;
  projectCards.forEach(card=>{
    const cats = (card.getAttribute('data-category')||'').split(/\s+/);
    const show = filter==='all' || cats.includes(filter);
    card.classList.toggle('hidden', !show);
    if(show) visible++;
  });
  if(filterCountEl){
    // animate count
    filterCountEl.style.transform='scale(1.15)';
    filterCountEl.style.color='var(--red)';
    filterCountEl.textContent=visible;
    setTimeout(()=>{ filterCountEl.style.transform=''; filterCountEl.style.color=''; }, 260);
  }
  // stagger in visible cards
  projectCards.forEach((card,i)=>{
    if(card.classList.contains('hidden')) return;
    card.style.opacity='0'; card.style.transform='translateY(10px)';
    setTimeout(()=>{
      card.style.transition='opacity .4s var(--ease), transform .4s var(--ease)';
      card.style.opacity='1'; card.style.transform='none';
    }, i*28);
    setTimeout(()=>{ card.style.transition=''; }, 600+i*28);
  });
}
filterBtns.forEach(btn=>{
  btn.addEventListener('click',()=>{
    filterBtns.forEach(b=>{b.classList.remove('active'); b.setAttribute('aria-selected','false')});
    btn.classList.add('active'); btn.setAttribute('aria-selected','true');
    updateFilterIndicator();
    applyFilter(btn.dataset.filter);
  });
});
window.addEventListener('resize', updateFilterIndicator);
window.addEventListener('load', updateFilterIndicator);
setTimeout(updateFilterIndicator, 320);
if(document.fonts && document.fonts.ready) document.fonts.ready.then(()=>setTimeout(updateFilterIndicator, 100));
document.querySelector('.filter-bar')?.addEventListener('scroll', ()=>requestAnimationFrame(updateFilterIndicator), {passive:true});

// ========== PROJECT MODAL ==========
const PROJECT_DATA = {
  "skin-trader": {
    num:"01", path:"CS2 SNIPRE", status:"● EM DESENVOLVIMENTO", title:"Skin Trader Pro",
    desc:"Dashboard Flask que só existe para uma coisa: transformar diferença de preços em trades com expectativa positiva. Não compra por ti — calcula, classifica e deixa-te clicar para comprar na fonte certa.",
    bullets:[
      "Polling em Steam (priceoverview + pricehistory), CSFloat (listings com float real), Skinport bulk e DMarket assinado HMAC — tudo com rate-limit e backoff exponencial.",
      "Engine determinística: contratos 10× de uma coleção + mixes k×A + (10−k)×B, float ratio normalizado, distribuição de output por wear e EV líquido com fee Steam 15% / terceiros 5%.",
      "Risco por σ 30/60/90d: robusto quando EV ≥ 2×σ ponderada e histórico suficiente (≥3 pontos, ≥50% cobertura). Sem dados suficientes nunca assume robustez.",
      "Posições com lock de 7 dias + sugestão vender/tradear/segurar após o lock; Telegram (Roco) para oportunidades robustas e fim de lock; IA local opcional via LM Studio.",
      "Acesso remoto privado só via tailscale serve (nunca funnel). 600+ linhas de README + AGENTS.md com contrato de engenharia."
    ],
    arch:"app.py • scheduler.py (APScheduler) • db.py (SQLite WAL) • collectors/{steam,csfloat,skinport,dmarket}.py • engine/{tradeup,risk,opportunities}.py • data/importer.py (ByMykel/CSGO-API ~2000 skins) • portfolio.py • notifier.py • insights.py • seed.py",
    pills:["FLASK","APSCHEDULER","SQLITE WAL","PYTHON 3.11","TAILSCALE","TELEGRAM","LM STUDIO"],
    pathFull:"CS2 SNIPRE — Flask • APScheduler • SQLite WAL • Python 3.11"
  },
  "free-games": {
    num:"02", path:"STEAM GAMES", status:"● ATIVO — DISCORD", title:"Free Games",
    desc:"Bot Discord que faz exactamente o que a malta quer: avisos de jogos pagos que ficaram gratuitos temporariamente (licença permanente) + arbitragem de trading cards quando o retorno em cartas compensa o preço.",
    bullets:[
      "Ciclo a cada 30 min: specials=1 sorted Price_ASC → appdetails para confirmar preço original > 0 (F2P de origem fora).",
      "Modo cartas: até 3€, calcula drops × preço médio ÷ 1.15 e só anuncia se recuperar custo + margem configurável; mostra set completo e previsão conservadora.",
      "Nunca repete (dedupe por appid), apaga a mensagem quando a promoção acaba (após 2 ciclos sem ver), histórico arquivado 30 dias.",
      "Comandos /ofertas, /status, /verificar, /help; ~100 MB RAM; zero ASF, zero conta Steam, zero farm.",
      "Package: discord.js 14, better-sqlite3, winston; Docker + deploy/install.sh; wizard npm run setup + invite + deploy-commands."
    ],
    arch:"src/index.js • src/discord/deploy-commands.js • src/steam/* (search + appdetails + market) • src/db (better-sqlite3) • Dockerfile + docker-compose.yml • deploy/install.sh",
    pills:["NODE 20","DISCORD.JS 14","BETTER-SQLITE3","DOCKER","STEAM STORE","WINSTON"],
    pathFull:"STEAM GAMES — Node 20 • discord.js 14 • better-sqlite3 • Docker"
  },
  "dev-farmer": {
    num:"03", path:"DEV FARMER", status:"● ATIVO — DESKTOP APP", title:"Farmer Bot — CS2",
    desc:"App desktop para CS2 com UI dedicada, hotkey global e input via hardware real (Arduino) ou virtual — built para correr horas sem ficar robótico.",
    bullets:[
      "janela 900×650 em CustomTkinter, dark (#16161b), psutil para detectar CS2, hotkey F8 (WM_HOTKEY) para ciclo rápido.",
      "input_sim.py com SCAN codes + arduino_link.py (Leonardo) ou vgamepad como fallback; movimento e ritmo humanizados.",
      "Modo remoto via socket (farmer_config.json: destino Local/Remoto, host, token), vídeo opcional e gestão multi-processo.",
      "Build via build_exe.bat / .spec → dist, .ino incluído para o Leonardo, iniciar.bat para arranque."
    ],
    arch:"main.py (App ctk.CTk) • agent.py (daemon remoto) • input_sim.py • arduino_link.py • vgamepad/ • farmer_config.json • Farmer Agent.spec / CS2 Farmer Bot.spec • farmer.ino",
    pills:["CUSTOMTKINTER","ARDUINO LEONARDO","VGAMEPAD","PYINSTALLER","CTYPES","PSUTIL"],
    pathFull:"DEV FARMER — CustomTkinter • Arduino Leonardo • vgamepad • PyInstaller"
  },
  "okx": {
    num:"04", path:"OKX SCANNER", status:"● PAPER-SCANNER", title:"OKX SuperTrend AI Scanner",
    desc:"Scanner paper-only que reimplementa em Python puro dois indicadores pesados (LuxAlgo SuperTrend AI + Fibonacci Golden Wave) e devolve sinais com SL/TP prontos a colar no broker.",
    bullets:[
      "SuperTrend AI: ATR + n SuperTrends + K-means de 3 clusters — port fiel do Pine Script.",
      "Golden Zone Flux Charts: highest/lowest N bars → zona 0.5–0.618; lógica LONG/SHORT com recuo + rejeição nos últimos 5 bars + confirmação de candle.",
      "Output por sinal: entrada (close de confirmação), SL (limite oposto ou SuperTrend + 0.2% buffer), TP1 RR 1.5×, TP2 micro swing high/low.",
      "Sem ordens, só sugestões clicáveis (copy broker-ready com casas decimais por tiers) + dashboard responsivo e via Tailscale."
    ],
    arch:"app/{dashboard,config,indicators,okx_client,signal_engine}.py • golden_scalp_hybrid.pine (ref) • templates/ + static/ • FastAPI + Uvicorn • httpx + pandas/numpy",
    pills:["FASTAPI","UVICORN","SUPERTREND AI","FIBONACCI","OKX API","NUMPY","TAILSCALE"],
    pathFull:"OKX SCANNER — FastAPI • SuperTrend AI • Fibonacci • Tailscale"
  },
  "confluence": {
    num:"05", path:"PINE CODE", status:"● PINE + MQL5 + USER.JS", title:"Confluence Engine — RebelsFunding",
    desc:"Motor de confluência 4 pernas usado para enfrentar contas de prop firm: trend, momentum, volume e structure somados com filtro HTF como 5ª perna quando o preset é dual-timeframe.",
    bullets:[
      "Scoring: Trend 30% + Momentum 25% + Volume 15% + Structure 30% → bull/bear scores; sinal só se gap mínimo + volatilidade OK + barras de gap.",
      "Presets 1m até 1d + duais 15m+4H, 30m+4H, 1H+4H, 5m+1H, 3m+30m, 1m+15m com parâmetros dedicados por TF (EMA/MACD/ATR/pivot/gap/TP).",
      "Risk: saldo + % risco → lote auto, SL = max(ATR TF × mult, ATR HTF ×0.6), 3 TPs com RR configurável, BE após TP1 + trailing.",
      "Dashboard flutuante arrastável via Tampermonkey que intercepta fetch/XHR do TradingView para roubar OHLC sem API."
    ],
    arch:"Confluence_Engine.pine (master) • Confluence_Engine.mq5 (MT5) • Confluence_Engine.user.js (Tampermonkey) • Dev_Dashboard.pine",
    pills:["PINE SCRIPT v5","MQL5","TAMPERMONKEY","EMA/RSI/MACD/ATR","TRADINGVIEW"],
    pathFull:"PINE CODE — Pine v5 • MQL5 • Tampermonkey • TradingView"
  },
  "kronos": {
    num:"06", path:"KRONOS", status:"◐ LAB — FOUNDATION MODEL", title:"Kronos — K-Lines Foundation Model",
    desc:"Research lane da casa: wrapper Robs por cima do Kronos (NeoQuasar) — foundation model treinado em K-lines de 45 exchanges para prever e gerar sinais de crypto.",
    bullets:[
      "Tokenização hierárquica de OHLCV + Transformer autorregressivo; modelos mini (4.1M, ctx 2048) e small (24.7M, ctx 512) no HF.",
      "ia_signal.py + crypto_signals.py: fetch via CCXT Binance, load_kronos, run_kronos_prediction → sinais COMPRA/VENDA/NEUTRO.",
      "web_dashboard.py: Flask + Plotly interativo, accessível via Tailscale :5050, alterna Confluence Engine ↔ Kronos IA.",
      "signal_watcher.py vigia sinais fora do dashboard; exemplos e finetune com Qlib incluídos."
    ],
    arch:"model/ (Kronos) • ia_signal.py • crypto_signals.py / crypto_scanner.py / forex_scanner.py • web_dashboard.py (Flask/Plotly) • finetune/ + examples/ + webui/",
    pills:["KRONOS HF","TRANSFORMER","CCXT","BINANCE","PLOTLY","FLASK","QLIB"],
    pathFull:"KRONOS — Foundation Model K-lines • Transformer • HuggingFace"
  },
  "fimathe": {
    num:"07", path:"FIMAYHE", status:"● STRATEGY PINE v6", title:"Fimathe Cycle + PCM",
    desc:"Formalização objetiva do método discricionário Fimathe (Teoria dos Ciclos): canal + zona neutra + arming + disparo + PCM congelado no sinal.",
    bullets:[
      "Canal rolling highest/lowest (inclui barra atual), zona neutra 35–65% centrada na midline, tolerância de toque 8–20% dependendo do TF.",
      "Ciclo armado no toque do extremo, disparo no recross da fronteira near da zona neutra — uma vez por ciclo.",
      "PCM: SL além do extremo + ATR(14)×mult (1.0–3.0×), TP no bound oposto; níveis estáticos após o sinal (sem trailing).",
      "Strategy calc_on_every_tick=false, process_orders_on_close=true (fill no close do sinal → alinhado com {{close}} dos alerts)."
    ],
    arch:"fimathe-pcm-strategy.pine (Pine v6) — inputs por preset: 1m 40b/8%/1.0×, 3m/5m/15m/30m com valores dedicados, max_lines/labels 500",
    pills:["PINE v6","STRATEGY","ATR(14)","NEUTRAL ZONE","PCM","NON-REPAINT"],
    pathFull:"FIMAYHE — Pine v6 • Strategy • ATR • PCM • Non-Repaint"
  },
  "pokemmo": {
    num:"08", path:"POKEMMO", status:"⚠ ALPHA → BETA", title:"PokeMMO Bot",
    desc:"Companion de mesa para PokeMMO: automatização leve de navegação + OCR contínuo do chat para ficar com dataset da sessão em vez de só olhar para o ecrã.",
    bullets:[
      "PokeMMOController (Tkinter 260×420 always-on-top): pesquisa de janelas win32gui, selector dinâmico e log local.",
      "Beta: modo WASD sintético (F10) com checkbox opcional de clique, auto-OCR do chat → events.db (kind='chat'), screenshots automáticos em batalha e snapshot de estado a cada 60s.",
      "Janela 'Análise' com estatísticas por tipo/origem, batalhas, chat OCR e export CSV; shotting em shots/ e config GLM em config/glm.properties.",
      "Integração GLM-4.6 (Z.AI) via glm_api_key() (env ou config) para enriquecer análise; PokeEvents capturado de APK."
    ],
    arch:"pokemmoversaoalpha.py (Alpha) • pokemmoversaobeta.py (Beta, ~500 linhas) • config/glm.properties • events.db • shots/ • PokeEvents.apk • tr-TR.zip (mocks)",
    pills:["TKINTER","WIN32GUI","PYAUTOGUI","PILLOW","PYTESSERACT","SQLITE","GLM-4.6"],
    pathFull:"POKEMMO — Tkinter • win32gui • pyautogui • OCR • SQLite"
  },
  "bets": {
    num:"09", path:"BETS CONVERTER", status:"● FLASK — CONVERTER", title:"Bets Converter — Paqbet",
    desc:"Utilitário para quem vive de booking codes: converte um código entre casas de apostas usando o Paqbet como ponte, com carrossel de sessions, CSRF e fallback.",
    bullets:[
      "Flask com CORS aberto, endpoints /api/convert e /health; sessão requests com User-Agent Chrome 120 e Referer paqbet.com.",
      "Fluxo: GET Paqbet → parse csrf_new* input → POST convert/booking_codes → JSON; retries (MAX_ATTEMPTS 3, delay 1s) + cache TTL 600s.",
      "Alias mapping (betandyou→1xbet:xx) + PRETTY_NAMES; view HTML devolvida no JSON.",
      "Frontend dark (var --bg #0f0f0f, gold #d4af37, red #e50914) com ngrok_domain.txt para expor."
    ],
    arch:"app.py (Flask) • index.html (converter-card dark) • start.py • ngrok_domain.txt • BeautifulSoup para CSRF",
    pills:["FLASK","BS4","REQUESTS","PAQBET","CORS","NGROK"],
    pathFull:"BETS CONVERTER — Flask • BeautifulSoup • Paqbet • CORS"
  },
  "mt2": {
    num:"10", path:"MT2DEV", status:"● CLIENT-SIDE MOD", title:"MT2Bot Lite — Energy + Locator",
    desc:"Mod enxuto e honesto para o cliente atual da Gameforge: duas funções, ambas só com o que o jogador já vê — compra/troca de energias e varredura de alvos.",
    bullets:[
      "Energias: junto ao vendedor de armas, auto-buy de facas até encher; anda TU até ao alquimista e ele troca tudo por fragmentos com ritmo humanizado.",
      "Locator: Metins e Bosses com seta direcional, lista de alvos (coord/vivo-morto), 'ir até' autónomo, filtro nível min/max e som opcional.",
      "Instalação: copiar init.py + pasta MT2Bot para raiz do cliente + eXLib.mix compatível; hotkeys +/INSERT para barra, ↓ para stealth; log em mt2dev.txt.",
      "Mapa Pyungmoo mapeado (Vendedor 430,607 → Alquimista 292,812 via 383,640 centro) + ferramentas marcar_zonas.py e recortemapa.py (OpenCV)."
    ],
    arch:"MT2Bot-Lite/init.py + MT2Bot/{EnergyBot, Locator…}.py • eXLib.mix • MT2Guide + MT2Bot-IPC (canal) • MT2Bot/ClientGuide",
    pills:["EXLIB.MIX","METIN2","GAMEFORGE","OPENCV","CLIENT-SIDE MOD","PYTHON INJECT"],
    pathFull:"MT2DEV — eXLib.mix • Gameforge • Client-Side Mod • OpenCV"
  },
  "tbh": {
    num:"11", path:"TBH TOOLKIT", status:"● N CONTAS — SANDBOXIE", title:"TaskBarHero Toolkit",
    desc:"Oficina para quem joga TaskBarHero a sério: sandboxes isoladas — quantas quiseres (a minha está com 5 para testar várias farms). Leitura de saves, gestão de baús e geração de assets sem sair do sistema.",
    bullets:[
      "Sandboxie com N sandboxes — quantas quiseres (ex.: 5 para testar várias farms). Cada save .es3 fica isolado na sua sandbox, sem misturar contas.",
      "Baús em baus.json/history/cache com monitor lock + alerts (min 0.8 / 1 dia), builds em builds.json (tbhindex.com/252/324/338 + mixes 214+153).",
      "analyze_tbh.py: EnumWindows de taskbarhero.exe, GetWindowRect + WS_EX_LAYERED/TRANSPARENT + mss screenshot para % pixels pretos.",
      "extract_*.py para chars/passivos/sprites, icons por tier e _farm_preview.html para pré-visualizar."
    ],
    arch:"baus.json/history/cache • builds.json • baus_para_importar/ • analyze_tbh.py + extract_{chars,passivos,sprites}.py • abrir_conta*.bat + abrir_steam.py • icons* / _farm_preview.html",
    pills:["SANDBOXIE","TASKBAR HERO","MSS","NUMPY","WIN32","PYINSTALLER"],
    pathFull:"TBH TOOLKIT — Sandboxie • N Sandboxes • MSS • Numpy"
  },
  "mt2guide": {
    num:"12", path:"MT2GUIDE", status:"◐ BETA FINAL — BUGFIXES", title:"MT2Guide — Quest Helper",
    desc:"Quest helper 100% client-side (estilo RestedXP) para qualquer cliente oficial Gameforge (TR, EU, ...) via eXLib.mix. Tu jogas; o guia aponta: passo-a-passo com avanço automático, seta 3D, mira vermelha nos mobs e sync com o estado real das quests.",
    bullets:[
      "Avanço automático dos passos: kill conta mortes sozinho (vnum do mob), talk/turnin avança no diálogo do NPC, goto ao chegar ao destino — collect/texto com botão +1.",
      "Mira vermelha (anel + cruz) desenhada pelo próprio cliente sobre CADA mob-alvo da missão, com contador real (“Cachorro 3/10”) no mob mais próximo; fallback sem miras se o cliente não projetar instâncias (nunca bloqueia cliques: not_pick).",
      "Missões de caça (AVLANMA GÖREVİ): as 118 da wiki oficial (Lv2→119) — escolha de 1 entre 2 mobs detetada automaticamente pelo alvo/1ª morte, ou botões Op.1/Op.2; pesquisa por nome do mob.",
      "Zona de spawn dos mobs por centroides oficiais (por reino nos mapas 1/2) + trava de alvo e apontador 3D; estado gravado em quest_state.txt entre sessões.",
      "Instalador troca o init.py e guarda o dos bots; comandos .g .q .qdiag .qkey .qpos .qstate .qdump e teclas INSERT/F7 + N/F8."
    ],
    arch:"init_guide.py (BOOTSTRAP+LOADER) • MT2Guide/__init__.py • Modules/GuideData.py • GuideDialog.py • GuideNav.py • GuideMark.py • GuideQuestSync.py • GuideUI.py • GuideLib.py • Data/quests_{wiki,caca,premium,yohara,extra}.txt • instalar-guia.bat • Jogar-Guia.bat",
    pills:["EXLIB.MIX","METIN2","GAMEFORGE","CLIENT-SIDE","PYTHON","WIKI DATA"],
    pathFull:"MT2GUIDE — eXLib.mix • Client-side • Python • Wiki data"
  },
  "sessao500": {
    num:"13", path:"CSGO500 CASINO", status:"◐ EM CRIAÇÃO — ALPHA", title:"Laboratório de Testes e Análises — CSGO500 (Casino)",
    desc:"O projeto mais disciplinar e mais testado: banca pequena, edge conhecido — sem botão mágico, só matemática, freios de mão e leitura de ecrã sem precisar da API do casino.",
    bullets:[
      "painel-sessao.html offline num ficheiro: P/L, meta, volume (banca/edge → ex: $5 /1% = $500 ~1667 rondas $0.30), guardrails, coach por rotação (dice/mines), TiltGuard (a cada 25 rondas, 5 defeats seguidas, win ≥$1).",
      "Monte Carlo 10k simulações ~250ms no browser + gráfico canvas vs E[saldo]=banca−edge×volume; export JSON/CSV e localStorage.",
      "painel-500.user.js HUD em Shadow DOM: lê saldo/URL, edge por jogo, recomendação; 414 testes (fuzz 1680 estados).",
      "vigia-500.py: OpenCV sem API — lê saldo/multiplicador/minas/tabuleiro por cor; 209 testes de paridade com o JS; simuladores Python para custo real."
    ],
    arch:"painel-sessao.html • painel-500.user.js (Shadow DOM) • teste-hud.js (414) • vigia-500.py + vigia_{motor,visao}.py + teste-vigia.py (209) • simulador_diversao/desafio.py • mock-casino.html",
    pills:["TAMPERMONKEY","SHADOW DOM","OPENCV","MONTE CARLO","NODE TEST","PYQT6"],
    pathFull:"CSGO500 CASINO — Tampermonkey • OpenCV • Monte Carlo • Shadow DOM"
  }
};

const modal = document.getElementById('projectModal');
const modalCard = document.getElementById('modalCard');
const modalClose = document.getElementById('modalClose');
const modalClose2 = document.getElementById('modalClose2');
function openProjectModal(key){
  const d = PROJECT_DATA[key];
  if(!d || !modal) return;
  document.getElementById('modalNum').textContent = d.num;
  document.getElementById('modalPath').textContent = d.path;
  document.getElementById('modalStatus').textContent = d.status;
  document.getElementById('modalTitle').textContent = d.title;
  document.getElementById('modalDesc').textContent = d.desc;
  const ul = document.getElementById('modalBullets');
  ul.innerHTML = d.bullets.map(b=>`<li>${b}</li>`).join('');
  document.getElementById('modalArch').textContent = d.arch;
  document.getElementById('modalPills').innerHTML = d.pills.map(p=>`<span class="pill">${p}</span>`).join('');
  document.getElementById('modalPathFull').textContent = d.pathFull;
  modal.classList.remove('hidden');
  modal.setAttribute('aria-hidden','false');
  document.body.style.overflow='hidden';
  if(lenis) lenis.stop();
}
function closeProjectModal(){
  if(!modal) return;
  modal.classList.add('hidden');
  modal.setAttribute('aria-hidden','true');
  document.body.style.overflow='';
  if(lenis) lenis.start();
}
document.querySelectorAll('[data-modal]').forEach(btn=>{
  btn.addEventListener('click', (e)=>{
    e.preventDefault();
    openProjectModal(btn.getAttribute('data-modal'));
  });
});
document.querySelectorAll('.project-card').forEach(card=>{
  card.style.cursor='pointer';
  card.addEventListener('click', (e)=>{
    if(e.target.closest('.card-cta')) return;
    const key = card.getAttribute('data-project');
    if(key) openProjectModal(key);
  });
});
modalClose?.addEventListener('click', closeProjectModal);
modalClose2?.addEventListener('click', closeProjectModal);
modal?.addEventListener('click', (e)=>{ if(e.target===modal) closeProjectModal(); });
document.addEventListener('keydown', (e)=>{ if(e.key==='Escape') closeProjectModal(); });

// ========== NAV HIGHLIGHT ==========
const navLinks=document.querySelectorAll('.taskbar-nav a');
const sections=document.querySelectorAll('.window');
function updateActiveNav(){
  let current='';
  const y = window.scrollY + 110;
  sections.forEach(s=>{
    if(s.offsetTop <= y) current=s.id;
  });
  navLinks.forEach(a=>{
    const isActive = a.getAttribute('href')==='#'+current;
    a.classList.toggle('active', isActive);
  });
}
window.addEventListener('scroll', updateActiveNav, {passive:true});
if(lenis) lenis.on('scroll', updateActiveNav);
updateActiveNav();

// ========== WINDOW TILT (desktop) ==========
(function windowTilt(){
  if(window.matchMedia('(hover:none)').matches) return;
  if(window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  document.querySelectorAll('.window').forEach(win=>{
    win.addEventListener('mousemove', e=>{
      const r=win.getBoundingClientRect();
      const x=(e.clientX - r.left)/r.width -0.5;
      const y=(e.clientY - r.top)/r.height -0.5;
      win.style.transform=`perspective(900px) rotateY(${x*1.2}deg) rotateX(${-y*1.2}deg) translateY(-2px)`;
    });
    win.addEventListener('mouseleave', ()=>{
      win.style.transform='';
      win.style.transition='transform .6s var(--ease)';
      setTimeout(()=> win.style.transition='', 600);
    });
  });
})();

// ========== COPY TOAST + BACK TO TOP ==========
(function copyToast(){
  const toast = document.getElementById('toast');
  const btn = document.getElementById('backToTop');
  function showToast(msg){
    if(!toast) return;
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(()=> toast.classList.remove('show'), 2200);
  }
  async function copyText(t){
    try { await navigator.clipboard.writeText(t); showToast('Copiado: ' + t); }
    catch { showToast('Copia: ' + t); }
  }
  document.querySelectorAll('[data-copy]').forEach(el=>{
    el.addEventListener('click', e=>{
      // Nao bloqueia link externo se for ctrl/cmd
      const val = el.getAttribute('data-copy');
      if(!val) return;
      // Se for link que vai navegar e nao e copy-trigger principal, deixa mas copia tambem
      const isProfileCard = el.classList.contains('discord-profile');
      if(isProfileCard) e.preventDefault();
      copyText(val);
    });
  });
  // Git clone buttons por projeto (gera href se quiseres expandir depois)
  // Back to top visibility
  if(btn){
    const onScroll = ()=> btn.classList.toggle('visible', window.scrollY > 600);
    window.addEventListener('scroll', onScroll, {passive:true});
    if(lenis) lenis.on('scroll', onScroll);
    btn.addEventListener('click', ()=>{
      if(lenis) lenis.scrollTo(0, {duration:1.0});
      else window.scrollTo({top:0, behavior:'smooth'});
    });
    onScroll();
  }
  // Expose for console testing
  window._srCopy = copyText;
  window._srToast = showToast;
})();

// ========== VISITOR COUNTERS (Abacus) ==========
// Serviço gratuito: abacus.jasoncameron.dev
// /hit/<ns>/<name> incrementa e devolve a contagem | /get/<ns>/<name> so le
// Nota: site estatico nao consegue ler IP/HWID real -> "unicos" = localStorage
// + fingerprint leve (ecra/idioma/timezone). E prova social, nao analytics exata.
(function(){
  const NS = 'srrobs-portfolio';
  const BASE = 'https://abacus.jasoncameron.dev';
  const KEY_SEEN = '_srSeen';
  const KEY_GH = '_srGhOpens';

  const pad = (n) => String(n).padStart(3, '0');
  const set = (id, val) => { const el = document.getElementById(id); if(el) el.textContent = val; };

  async function hit(name){
    try{
      const r = await fetch(BASE + '/hit/' + NS + '/' + name, {method:'GET', keepalive:true});
      if(!r.ok) throw 0;
      const t = (await r.text()).trim();
      const n = parseInt(t, 10);
      return isNaN(n) ? null : n;
    }catch(e){ return null; }
  }

  // Fingerprint leve so para distinguir navegadores/dispositivos diferentes
  function fingerprint(){
    const parts = [
      screen.width, screen.height, screen.colorDepth,
      navigator.language, (navigator.languages || []).join(','),
      Intl.DateTimeFormat().resolvedOptions().timeZone || '',
      navigator.hardwareConcurrency || '', navigator.platform || ''
    ];
    return parts.join('|');
  }

  function localSeen(){
    try{
      const raw = localStorage.getItem(KEY_SEEN);
      const fp = fingerprint();
      if(raw && raw === fp) return true;         // ja visitou neste dispositivo
      localStorage.setItem(KEY_SEEN, fp);        // primeira vez (ou fingerprint mudou)
      return false;
    }catch(e){ return false; }                    // localStorage bloqueado -> conta como novo
  }

  function bumpLocal(key){
    let n = 0;
    try{ n = parseInt(localStorage.getItem(key) || '0', 10) || 0; }catch(e){}
    n++;
    try{ localStorage.setItem(key, String(n)); }catch(e){}
    return n;
  }

  function init(){
    // 1) Visitas totais
    hit('visits').then(n => set('visitCount', n !== null ? pad(n) : pad(bumpLocal('visits'))));

    // 2) Visitantes unicos (incrementa so na 1a visita deste navegador)
    if(!localSeen()){
      hit('uniques').then(n => set('uniqueCount', n !== null ? pad(n) : '001'));
    }else{
      fetch(BASE + '/get/' + NS + '/uniques')
        .then(r => r.ok ? r.text() : Promise.reject())
        .then(t => { const n = parseInt(t.trim(), 10); if(!isNaN(n)) set('uniqueCount', pad(n)); })
        .catch(()=> set('uniqueCount', '001')); // chave ainda nao criada ou servico caido
    }

    // 3) Links GitHub abertos -> footer
    fetch(BASE + '/get/' + NS + '/github-opens')
      .then(r => r.ok ? r.text() : Promise.reject())
      .then(t => { const n = parseInt(t.trim(), 10); if(!isNaN(n)) set('githubOpens', pad(n)); })
      .catch(()=>{ // chave ainda nao criada ou servico caido -> mostra contagem local
          let n = 0;
          try{ n = parseInt(localStorage.getItem(KEY_GH) || '0', 10) || 0; }catch(e){}
          set('githubOpens', pad(n));
        });
  }

  function trackGithubOpen(){
    hit('github-opens').then(n => {
      if(n !== null) set('githubOpens', pad(n));
      else set('githubOpens', pad(bumpLocal(KEY_GH)));
    });
  }

  // Cliques em links GitHub: taskbar, cards de projeto, cartao de contacto
  // (nao bloqueia a navegacao; um unico increment por clique — fetch com keepalive)
  document.addEventListener('click', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    if(!a) return;
    const href = a.getAttribute('href') || '';
    if(!/^https?:\/\/github\.com\//i.test(href)) return;
    // dispara sem await — o link abre em nova aba (target=_blank) e a pagina continua viva
    trackGithubOpen();
  }, {passive:true});

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();

  window._srCounters = { hit, trackGithubOpen };
})();

/* ═══ SRR OBS — TRACKING LOCAL (IP + HWID/device-id via servidor python) ═══ */
/* Conta visitas e cliques GitHub por IP e por dispositivo. Offline -> silêncio, */
/* o Abacus em cima continua a funcionar como fallback (GitHub Pages).        */
(function () {
  'use strict';
  var ENDPOINT = 'http://localhost:8766/api/visitas';
  var KEY_DEVICE = '_srDevice';
  var PING_MS = 45000; // < ONLINE_SEG(60s) no servidor -> mantém «online» fresco
  var visitSent = false;

  function deviceId() {
    try {
      var d = localStorage.getItem(KEY_DEVICE);
      if (d) return d;
      d = 'hw-' + (window.crypto && window.crypto.randomUUID
        ? window.crypto.randomUUID()
        : Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10));
      localStorage.setItem(KEY_DEVICE, d);
      return d;
    } catch (e) { return 'hw-anon'; }
  }

  function send(event) {
    try {
      fetch(ENDPOINT, {
        method: 'POST',
        mode: 'cors',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device: deviceId(), event: event })
      }).then(function (r) { return r.ok ? r.json() : null; })
        .then(function (j) { if (j && j.ok) paint(j.stats); })
        .catch(function () {});
    } catch (e) {}
  }

  // Contadores: hero (em cima) + janela visitas (sem tabelas IP/HWID)
  function paint(s) {
    if (!s) return;
    function set(id, v) {
      var el = document.getElementById(id);
      if (el && v !== null && v !== undefined) el.textContent = v;
    }
    var pad = function (n) { return String(n).padStart(3, '0'); };
    set('visitCount', pad(s.total_visitas));
    var uniq = (s.por_device || []).length;
    if (s.total_devices != null) uniq = s.total_devices;
    else if (s.totalDevices != null) uniq = s.totalDevices;
    else if (s.total_ips != null) uniq = s.total_ips;
    set('uniqueCount', pad(uniq));
    set('githubOpens', pad(s.total_github));
    // Janela visitas.log — só números, sem IDs
    if (s.total_ips != null) set('srTotalIps', pad(s.total_ips));
    else if (s.totalIps != null) set('srTotalIps', pad(s.totalIps));
    else if (s.por_ip) set('srTotalIps', pad(s.por_ip.length));
    if (s.total_devices != null) set('srTotalDevices', pad(s.total_devices));
    else if (s.totalDevices != null) set('srTotalDevices', pad(s.totalDevices));
    else if (s.por_device) set('srTotalDevices', pad(s.por_device.length));
    set('srTotalVisitas', pad(s.total_visitas));
    set('srTotalClicks', pad(s.total_github));
    set('srOnlineAgora', String(s.online_agora != null ? s.online_agora : (s.onlineAgora || 0)));
    set('srIpsOnline', String(s.ips_online != null ? s.ips_online : (s.ipsOnline || 0)));
  }

  /* GET inicial: tenta localhost; se offline (GitHub Pages), lê snapshot público */
  var SNAPSHOT_URL = 'visitas_totals.json';
  function paintFromPublic(json){
    // /visitas_totals.json ou {"ok":true,"stats":{...}} ou stats direto
    var s = json && json.stats ? json.stats : json;
    if (s && typeof s.total_visitas !== 'undefined') paint(s);
  }
  function fetchSnapshot(){
    fetch(SNAPSHOT_URL, { cache: 'no-store' })
      .then(function(r){ return r.ok ? r.json() : null; })
      .then(function(j){ if(j) paintFromPublic(j); })
      .catch(function(){});
  }
  function fetchPaint() {
    try {
      fetch(ENDPOINT, { mode: 'cors' })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (j) {
          if (j && j.ok) paint(j.stats);
          else fetchSnapshot();
        })
        .catch(function () { fetchSnapshot(); });
    } catch (e) { fetchSnapshot(); }
  }

  function start() {
    fetchPaint();                                          // estado atual (GET, sem POST)
    if (!visitSent) { visitSent = true; send('visit'); } // 1 visita por load
    send('ping');
    setInterval(function () { send('ping'); }, PING_MS);   // heartbeat «online agora»
  }

  // Clique em qualquer link github.com -> github_click (soma por IP e por HWID)
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (a && /^https?:\/\/github\.com\//i.test(a.getAttribute('href') || '')) send('github_click');
  }, { passive: true });

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();

  window._srLocal = { send: send, deviceId: deviceId };
})();
