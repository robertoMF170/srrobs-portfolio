[CmdletBinding()]
param(
    [ValidateRange(30, 86400)]
    [int] $IntervalSeconds = 300,
    [switch] $Once
)

$ErrorActionPreference = 'Stop'
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
[Console]::OutputEncoding = $script:Utf8NoBom
[Console]::InputEncoding = $script:Utf8NoBom
$OutputEncoding = $script:Utf8NoBom
$script:GitHubTokenPrompted = $false
$script:GitHubTokenSecure = $null
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo

$descriptionPath = 'todo/repository-description.txt'
$descriptionMaxLength = 350
$expectedCommitSubject = 'chore: update redacted repository description'
$protectedPaths = @(
    'index.html', 'app.js', 'style.css', 'favicon.svg', 'og-image.svg',
    '404.html', 'robots.txt', 'sitemap.xml', '.nojekyll', 'README.md',
    'src/', 'tests/', '.github/', 'visitas_totals.json'
)

function Invoke-NativeCommand([string] $FilePath, [string[]] $Arguments) {
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string] $_ })
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 1 }
        return [pscustomobject]@{ ExitCode = [int] $code; Output = $output }
    } catch {
        return [pscustomobject]@{ ExitCode = 1; Output = @() }
    } finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Write-LoopError([System.Management.Automation.ErrorRecord] $Record) {
    $message = $Record.Exception.Message
    if ($message.StartsWith('AUTOPUSH:')) {
        Write-Host $message.Substring(9).Trim() -ForegroundColor Red
        return
    }
    Write-Host ("Erro: {0}. Não foram apresentados detalhes que possam conter dados pessoais; verifique git status e a identidade Git." -f $Record.Exception.GetType().Name) -ForegroundColor Red
}

function Get-RedactedReadmeDescription {
    # Only fixed technology labels from this allowlist can leave the README.
    $readme = Get-Content -LiteralPath (Join-Path $repo 'README.md') -Raw -Encoding UTF8
    $allowedTerms = @(
        @{ Pattern = '(?i)\bPython\b'; Label = 'Python' },
        @{ Pattern = '(?i)\bHTML\b'; Label = 'HTML' },
        @{ Pattern = '(?i)\bCSS\b'; Label = 'CSS' },
        @{ Pattern = '(?i)\bJavaScript\b'; Label = 'JavaScript' },
        @{ Pattern = '(?i)\bNode(?:\.js)?\b'; Label = 'Node.js' },
        @{ Pattern = '(?i)\bFlask\b'; Label = 'Flask' },
        @{ Pattern = '(?i)\bFastAPI\b'; Label = 'FastAPI' },
        @{ Pattern = '(?i)\bSQLite\b'; Label = 'SQLite' },
        @{ Pattern = '(?i)\bPine(?:\s*v\d+)?\b'; Label = 'Pine Script' },
        @{ Pattern = '(?i)\bMQL5\b'; Label = 'MQL5' },
        @{ Pattern = '(?i)\bOpenCV\b'; Label = 'OpenCV' },
        @{ Pattern = '(?i)\bArduino\b'; Label = 'Arduino' },
        @{ Pattern = '(?i)\bCCXT\b'; Label = 'CCXT' }
    )
    $technologies = @(
        foreach ($term in $allowedTerms) {
            if ([regex]::IsMatch($readme, $term.Pattern)) { $term.Label }
        }
    ) | Select-Object -Unique
    if ($technologies.Count -eq 0) { $technologies = @('desenvolvimento de software') }
    $description = 'Portfolio de projetos de software e automação com ' + ($technologies -join ', ') + '.'
    if ($description.Length -gt $descriptionMaxLength) {
        $description = $description.Substring(0, $descriptionMaxLength).TrimEnd()
    }
    return $description
}

function Invoke-GitChecked([string[]] $Arguments) {
    $result = Invoke-NativeCommand 'git' $Arguments
    if ($result.ExitCode -ne 0) {
        if ($Arguments[0] -eq 'commit') {
            $message = (($result.Output -join ' ') -replace '[\r\n]+', ' ')
            $identityPattern = '(?i)Author identity unknown|unable to auto-detect email|please tell me who you are|fatal:.*user\.email'
            if ([regex]::IsMatch($message, $identityPattern)) {
                throw [System.InvalidOperationException]::new("AUTOPUSH: O commit falhou por falta da identidade Git. Configure 'git config --global user.name' e 'git config --global user.email' com os seus dados Git e reinicie. O valor/email não foi apresentado.")
            }
            throw [System.InvalidOperationException]::new("AUTOPUSH: O commit falhou (código $($result.ExitCode)); confira 'git status'. Detalhes ocultos para proteger dados pessoais.")
        }
        throw [System.InvalidOperationException]::new("AUTOPUSH: O comando Git '$($Arguments[0])' falhou (código $($result.ExitCode)); confirme a autenticação/ligação e tente de novo.")
    }
}

function Get-ChangedEntries {
    $result = Invoke-NativeCommand 'git' @('status', '--porcelain=v1', '--untracked-files=all')
    if ($result.ExitCode -ne 0) { throw [System.InvalidOperationException]::new('Não foi possível ler o estado do Git.') }
    $entries = @()
    foreach ($line in $result.Output) {
        if ($line.Length -ge 3) {
            $entries += [pscustomobject]@{
                Code = $line.Substring(0, 2)
                Path = $line.Substring(3).Trim('"').Replace('\', '/')
            }
        }
    }
    return $entries
}

function Test-ProtectedPath([string] $Path) {
    foreach ($protected in $protectedPaths) {
        if ($protected.EndsWith('/')) {
            if ($Path.StartsWith($protected, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        } elseif ($Path.Equals($protected, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-SafePathLabel([string] $Path) {
    $extension = [IO.Path]::GetExtension($Path)
    if (-not $extension) { $extension = '[sem extensão]' }
    return "[caminho censurado] $extension"
}

function Write-SafeChangeSummary($Entries) {
    Write-Host ("Alterações detetadas: {0} ficheiro(s); nomes e conteúdos ocultos para proteger contas, nicks e dados pessoais." -f $Entries.Count) -ForegroundColor Yellow
    $groups = @($Entries | ForEach-Object {
        [pscustomobject]@{ Code = $_.Code; Label = Get-SafePathLabel $_.Path }
    } | Group-Object Code, Label | Sort-Object Name)
    foreach ($group in $groups) {
        $entry = $group.Group[0]
        Write-Host ("  estado {0}, {1}: {2} ficheiro(s)" -f $entry.Code, $entry.Label, $group.Count)
    }
    Write-Host 'Diffs brutos não são mostrados porque podem conter credenciais ou dados pessoais.' -ForegroundColor DarkGray
}

function Get-GitHubRepositorySlug {
    $remote = Invoke-NativeCommand 'git' @('remote', 'get-url', 'origin')
    if ($remote.ExitCode -ne 0 -or $remote.Output.Count -eq 0) { return $null }
    $url = $remote.Output[0].Trim()
    $pattern = '^(?:https?://(?:[^/@]+@)?|ssh://(?:[^/@]+@)?|(?:[^@]+@)?)github\.com[:/]([^/]+)/([^/?#]+?)(?:\.git)?/?$'
    $match = [regex]::Match($url, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return $null }
    return ($match.Groups[1].Value + '/' + $match.Groups[2].Value)
}

function Get-GitHubTokenSecure {
    if (-not $script:GitHubTokenPrompted) {
        $script:GitHubTokenPrompted = $true
        Write-Host 'Para atualizar a descrição, use gh auth login ou forneça um token fine-grained com permissões Administration: write no repositório.' -ForegroundColor Yellow
        $script:GitHubTokenSecure = Read-Host 'Token GitHub (Enter para saltar; entrada oculta)' -AsSecureString
    }
    if ($null -eq $script:GitHubTokenSecure -or $script:GitHubTokenSecure.Length -eq 0) { return $null }
    return $script:GitHubTokenSecure
}

function Update-GitHubDescriptionWithToken([string] $Slug, [string] $Description) {
    $secureToken = Get-GitHubTokenSecure
    if ($null -eq $secureToken) {
        Write-Host 'Descrição remota não alterada. Configure gh auth login e reinicie, ou volte a iniciar para introduzir um token.' -ForegroundColor Yellow
        return
    }

    $pointer = [IntPtr]::Zero
    $tokenText = $null
    $headers = $null
    $oldProtocols = [Net.ServicePointManager]::SecurityProtocol
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $tokenText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $headers = @{
            Authorization = "Bearer $tokenText"
            Accept = 'application/vnd.github+json'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $uri = 'https://api.github.com/repos/' + $Slug
        $body = @{ description = $Description } | ConvertTo-Json -Compress
        $null = Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body $body -ContentType 'application/json; charset=utf-8' -UseBasicParsing -ErrorAction Stop
        Write-Host 'Descrição remota do GitHub atualizada com sucesso.' -ForegroundColor Green
    } catch {
        $status = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -in @(401, 403)) {
            Write-Host ("GitHub recusou a autenticação (HTTP {0}). Confirme o token e a permissão Administration: write." -f $status) -ForegroundColor Red
        } elseif ($status) {
            Write-Host ("A atualização da descrição falhou (HTTP {0}); o detalhe foi ocultado." -f $status) -ForegroundColor Red
        } else {
            Write-Host 'Não foi possível contactar a API do GitHub; confirme a ligação à Internet.' -ForegroundColor Red
        }
    } finally {
        if ($headers) { $headers.Clear() }
        $tokenText = $null
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        [Net.ServicePointManager]::SecurityProtocol = $oldProtocols
    }
}

function Set-GitHubRepositoryDescription([string] $Description) {
    $slug = Get-GitHubRepositorySlug
    if (-not $slug) {
        Write-Host 'Remote origin não é um URL GitHub reconhecido; descrição remota não alterada.' -ForegroundColor Yellow
        return
    }

    $gh = Get-Command 'gh' -ErrorAction SilentlyContinue
    if ($gh) {
        $current = Invoke-NativeCommand $gh.Source @('repo', 'view', $slug, '--json', 'description', '--jq', '.description')
        if ($current.ExitCode -eq 0) {
            $remoteDescription = ($current.Output -join "`n").Trim()
            if ($remoteDescription -ceq $Description) {
                Write-Host 'Descrição do GitHub já está atualizada.' -ForegroundColor Green
                return
            }
            $edit = Invoke-NativeCommand $gh.Source @('repo', 'edit', $slug, '--description', $Description)
            if ($edit.ExitCode -eq 0) {
                Write-Host 'Descrição remota do GitHub atualizada com sucesso.' -ForegroundColor Green
                return
            }
            Write-Host 'GitHub CLI não autenticado ou sem permissão; a pedir autenticação segura.' -ForegroundColor Yellow
        } else {
            Write-Host 'GitHub CLI sem sessão autenticada; a pedir autenticação segura.' -ForegroundColor Yellow
        }
    }

    # Check whether a public repository already has this description without prompting for a token.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $publicRepo = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $slug) -Method Get -Headers @{ Accept = 'application/vnd.github+json' } -UseBasicParsing -ErrorAction Stop
        if ([string]$publicRepo.description -ceq $Description) {
            Write-Host 'Descrição do GitHub já está atualizada.' -ForegroundColor Green
            return
        }
    } catch {
        # Private repositories need authentication; do not echo HTTP/body details.
    }
    Update-GitHubDescriptionWithToken $slug $Description
}

function Get-Upstream {
    $result = Invoke-NativeCommand 'git' @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}')
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) { return $null }
    return $result.Output[0].Trim()
}

function Get-AheadCount([string] $Upstream) {
    $result = Invoke-NativeCommand 'git' @('rev-list', '--count', ($Upstream + '..HEAD'))
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) { return $null }
    $count = 0
    if (-not [int]::TryParse($result.Output[0].Trim(), [ref]$count)) { return $null }
    return $count
}

function Test-PendingCommitSafe([string] $Upstream, [string] $Description) {
    if ((Get-AheadCount $Upstream) -ne 1) { return $false }
    $subject = Invoke-NativeCommand 'git' @('log', '-1', '--format=%s')
    if ($subject.ExitCode -ne 0 -or $subject.Output.Count -eq 0 -or $subject.Output[0] -cne $expectedCommitSubject) { return $false }
    $paths = Invoke-NativeCommand 'git' @('diff', '--name-only', ($Upstream + '..HEAD'))
    if ($paths.ExitCode -ne 0 -or $paths.Output.Count -ne 1 -or $paths.Output[0] -cne $descriptionPath) { return $false }
    $committed = Invoke-NativeCommand 'git' @('show', ('HEAD:' + $descriptionPath))
    if ($committed.ExitCode -ne 0) { return $false }
    return (($committed.Output -join "`n").Trim() -ceq $Description)
}

function Update-Description([string] $Description) {
    $path = Join-Path $repo $descriptionPath
    [IO.File]::WriteAllText($path, $Description + "`n", $script:Utf8NoBom)
    Write-Host ("Descrição censurada gerada a partir do README: {0} termos permitidos, {1} caracteres." -f (($Description -split ', ').Count), $Description.Length) -ForegroundColor Green
    Set-GitHubRepositoryDescription $Description
}

function Invoke-AuditCycle {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host ("[{0}] Auditoria" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan

    $description = Get-RedactedReadmeDescription
    Update-Description $description
    $entries = @(Get-ChangedEntries)
    if ($entries.Count -gt 0) { Write-SafeChangeSummary $entries }

    $upstream = Get-Upstream
    if (-not $upstream) {
        Write-Host 'Sem upstream Git; commit/push automáticos desativados.' -ForegroundColor Yellow
        return
    }

    if (Test-PendingCommitSafe $upstream $description) {
        Write-Host 'Commit pendente confirmado: contém apenas a descrição censurada gerada.' -ForegroundColor Cyan
        $push = Invoke-NativeCommand 'git' @('push')
        if ($push.ExitCode -eq 0) { Write-Host 'Push concluído.' -ForegroundColor Green }
        else { Write-Host ("Push falhou (código {0}); será tentado novamente no próximo ciclo." -f $push.ExitCode) -ForegroundColor Yellow }
        return
    }

    if ($entries.Count -eq 0) {
        Write-Host 'Sem alterações locais.' -ForegroundColor DarkGray
        $ahead = Get-AheadCount $upstream
        if ($null -ne $ahead -and $ahead -gt 0) {
            Write-Host ("Existem {0} commits locais não reconhecidos como seguros; não serão enviados." -f $ahead) -ForegroundColor Yellow
        }
        return
    }

    # Site, README, and all user-created files remain untouched. Only the generated text file
    # can be committed; unknown personal data cannot accidentally enter a push.
    if ($entries.Count -ne 1 -or $entries[0].Path -cne $descriptionPath) {
        Write-Host 'Commit bloqueado: há alterações além da descrição gerada. Nada foi staged, commitado ou enviado.' -ForegroundColor Yellow
        return
    }
    if (Test-ProtectedPath $entries[0].Path) {
        Write-Host 'Commit bloqueado por proteção de caminho.' -ForegroundColor Yellow
        return
    }

    $stagedCheck = Invoke-NativeCommand 'git' @('diff', '--cached', '--quiet')
    if ($stagedCheck.ExitCode -ne 0) {
        Write-Host 'Há alterações staged preexistentes; não serão alteradas nem incluídas.' -ForegroundColor Yellow
        return
    }
    $ahead = Get-AheadCount $upstream
    if ($null -eq $ahead -or $ahead -ne 0) {
        Write-Host 'Existem commits locais pendentes ou não foi possível confirmar a branch; nada será enviado.' -ForegroundColor Yellow
        return
    }

    Invoke-GitChecked @('add', '--', $descriptionPath)
    $staged = Invoke-NativeCommand 'git' @('diff', '--cached', '--name-only')
    if ($staged.ExitCode -ne 0 -or $staged.Output.Count -ne 1 -or $staged.Output[0] -cne $descriptionPath) {
        Write-Host 'Verificação do staging falhou; não foi criado commit.' -ForegroundColor Yellow
        return
    }
    $stagedContent = Invoke-NativeCommand 'git' @('show', (':' + $descriptionPath))
    if ($stagedContent.ExitCode -ne 0 -or (($stagedContent.Output -join "`n").Trim() -cne $description)) {
        Write-Host 'Conteúdo staged não corresponde à descrição censurada; commit bloqueado.' -ForegroundColor Yellow
        return
    }

    Write-Host 'Commit seguro: apenas a descrição gerada a partir de tecnologias permitidas.' -ForegroundColor Cyan
    Invoke-GitChecked @('commit', '-m', $expectedCommitSubject)
    Write-Host 'Commit criado. A enviar para o remote...' -ForegroundColor Green
    $push = Invoke-NativeCommand 'git' @('push')
    if ($push.ExitCode -eq 0) {
        Write-Host 'Push concluído.' -ForegroundColor Green
    } else {
        Write-Host ("Push falhou (código {0}); autentique o Git com o gestor de credenciais ou tente 'git push' manualmente. Será tentado novamente se o commit passar as verificações." -f $push.ExitCode) -ForegroundColor Yellow
    }
}

Write-Host 'Loop seguro iniciado. O site e README nunca são commitados ou enviados. Ctrl+C para parar.' -ForegroundColor Green
Write-Host ("Ciclo: {0} segundos. Usa -Once para executar apenas um ciclo." -f $IntervalSeconds) -ForegroundColor Green
if ($Once) {
    try { Invoke-AuditCycle } catch { Write-LoopError $_; exit 1 }
    exit 0
}
while ($true) {
    try { Invoke-AuditCycle } catch { Write-LoopError $_ }
    Write-Host ("Próxima verificação em {0} minuto(s). Ctrl+C para parar." -f [math]::Round($IntervalSeconds / 60, 1)) -ForegroundColor DarkGray
    Start-Sleep -Seconds $IntervalSeconds
}
