# Apresentações Privadas — SrRobs Virtual Ai

Site com as duas apresentações de financiamento, **cifradas com AES-256-GCM**.
Sem a palavra-passe certa, o conteúdo é **indecifrável** — mesmo lendo o código-fonte.

- **index.html** — escolha da área (Família / Investidores)
- **familia.html** — versão família/padrinho (sem juros)
- **investidores.html** — versão investidores (com contrato)

## ⚠️ Avisos de honestidade
- A cifra é real (AES-256, chave derivada da palavra-passe com PBKDF2, 100k iterações).
  O que NÃO é protegido: o título das páginas e a existência do site.
- As **palavras-passe nunca ficam neste repositório** — enviam-se por canal à parte
  (WhatsApp, telefone, presencialmente).
- Não meter aqui nada além destas páginas.

## Como mudar as palavras-passe (para o Fundador)
1. Correr o construtor com as passwords novas:
   ```bash
   python ferramentas/cripto_apresentacoes.py --familia NOVA1 --investidores NOVA2
   ```
2. Copiar os ficheiros gerados para esta pasta (o construtor já escreve aqui).
3. Publicar:
   ```bash
   git add -A && git commit -m "novas passwords" && git push
   ```
4. Enviar as novas passwords aos destinatários por canal privado.

## Nota
As fontes em claro (`.md` e `conteudo-*.html`) vivem no workspace e num repositório
**privado** — nunca neste.
