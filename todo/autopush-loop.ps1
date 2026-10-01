[CmdletBinding()]
param(
    [ValidateRange(30, 86400)]
    [int] $IntervalSeconds = 300,
    [string] $ProjectsRoot = 'D:\',
    [string] $RepositoryPath,
    [switch] $Once,
    [switch] $ScanCommit
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
$dataPath = 'data/projetos.json'
$generatedPaths = @($descriptionPath, $dataPath)
$countSyncPaths = @('README.md', 'og-image.svg', 'index.html')
$descriptionMaxLength = 350
$expectedCommitSubject = 'chore: update generated redacted portfolio data'
$protectedPaths = @(
    'app.js', 'style.css', 'favicon.svg',
    '404.html', 'robots.txt', 'sitemap.xml', '.nojekyll',
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
    } finally { $ErrorActionPreference = $oldPreference }
}

function Write-LoopError([System.Management.Automation.ErrorRecord] $Record) {
    $message = $Record.Exception.Message
    if ($message.StartsWith('AUTOPUSH:')) {
        Write-Host $message.Substring(9).Trim() -ForegroundColor Red
        return
    }
    Write-Host ("Erro: {0}. Os detalhes foram ocultados para proteger dados pessoais; confirme a rede, o Git e a pasta de projetos." -f $Record.Exception.GetType().Name) -ForegroundColor Red
}

function Get-RedactedReadmeDescription {
    $readme = Get-Content -LiteralPath (Join-Path $repo 'README.md') -Raw -Encoding UTF8
    $allowedTerms = @(
        @{ Pattern = '(?i)\bPython\b'; Label = 'Python' }, @{ Pattern = '(?i)\bHTML\b'; Label = 'HTML' },
        @{ Pattern = '(?i)\bCSS\b'; Label = 'CSS' }, @{ Pattern = '(?i)\bJavaScript\b'; Label = 'JavaScript' },
        @{ Pattern = '(?i)\bNode(?:\.js)?\b'; Label = 'Node.js' }, @{ Pattern = '(?i)\bFlask\b'; Label = 'Flask' },
        @{ Pattern = '(?i)\bFastAPI\b'; Label = 'FastAPI' }, @{ Pattern = '(?i)\bSQLite\b'; Label = 'SQLite' },
        @{ Pattern = '(?i)\bPine(?:\s*v\d+)?\b'; Label = 'Pine Script' }, @{ Pattern = '(?i)\bMQL5\b'; Label = 'MQL5' },
        @{ Pattern = '(?i)\bOpenCV\b'; Label = 'OpenCV' }, @{ Pattern = '(?i)\bArduino\b'; Label = 'Arduino' },
        @{ Pattern = '(?i)\bCCXT\b'; Label = 'CCXT' }
    )
    $technologies = @(
        foreach ($term in $allowedTerms) { if ([regex]::IsMatch($readme, $term.Pattern)) { $term.Label } }
    ) | Select-Object -Unique
    if ($technologies.Count -eq 0) { $technologies = @('desenvolvimento de software') }
    $description = 'Portfolio de projetos de software e automação com ' + ($technologies -join ', ') + '.'
    if ($description.Length -gt $descriptionMaxLength) { $description = $description.Substring(0, $descriptionMaxLength).TrimEnd() }
    return $description
}

function Get-CensoredText([string] $Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $clean = $Text
    $clean = [regex]::Replace($clean, '(?i)-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----', '[CENSURADO]', [Text.RegularExpressions.RegexOptions]::Singleline)
    $clean = [regex]::Replace($clean, '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[A-Za-z0-9-]{15,})\b', '[CENSURADO]')
    $clean = [regex]::Replace($clean, '(?i)(\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password|passwd|secret[_-]?key)\b\s*[:=]\s*["'']?)[^\s,;"''<>]{8,}', '$1[CENSURADO]')
    $clean = [regex]::Replace($clean, '(?i)https?://\S+', ' ')
    $clean = [regex]::Replace($clean, '(?i)\b[A-Za-z]:\\\S*', ' ')
    $clean = [regex]::Replace($clean, '(?i)\b[\w.+-]+@[\w-]+\.[\w.-]+', ' ')
    $clean = [regex]::Replace($clean, '@[\w-]+', ' ')
    $clean = $clean.Replace('\', ' ')
    $clean = [regex]::Replace($clean, '\s+', ' ').Trim()
    if ($clean.Length -gt 120) { $clean = $clean.Substring(0, 120).TrimEnd() }
    $clean = $clean.TrimEnd([char[]]@(',', ';', ':', '•'))
    return $clean
}

function Get-SafeProjectText([string] $Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $clean = $Text
    $clean = [regex]::Replace($clean, '(?i)-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----', '[CENSURADO]', [Text.RegularExpressions.RegexOptions]::Singleline)
    $clean = [regex]::Replace($clean, '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[A-Za-z0-9-]{15,})\b', '[CENSURADO]')
    $clean = [regex]::Replace($clean, '(?i)(\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password|passwd|secret[_-]?key)\b\s*[:=]\s*["'']?)[^\s,;"''<>]{8,}', '$1[CENSURADO]')
    $clean = [regex]::Replace($clean, '(?i)(https?://)[^/\s:@]+:[^/\s@]+@', '$1[CENSURADO]@')
    $clean = [regex]::Replace($clean, '(?i)\b[A-Za-z]:\\[^\s<>]+', '[CAMINHO LOCAL]')
    $clean = [regex]::Replace($clean, '(?i)(/Users/|/home/)[^/\s]+', '[CAMINHO LOCAL]')
    $clean = [regex]::Replace($clean, '(?i)(?:[A-Za-z]:)?[/\\](?:Users|home)[/\\][^/\\\s]+', '[CAMINHO LOCAL]')
    $clean = [regex]::Replace($clean, '(?i)\b[\w.+-]+@[\w-]+\.[\w.-]+', '[EMAIL]')
    $clean = [regex]::Replace($clean, '@[\w-]+', '[UTILIZADOR]')
    $clean = ([regex]::Replace($clean, '\s+', ' ')).Trim()
    return $clean.TrimEnd([char[]]@(',', ';', ':', '•'))
}

function Get-ProjectRepoName($Project) {
    if ($null -eq $Project) { return '' }
    if ($Project.PSObject.Properties.Name -contains 'repo' -and [string]$Project.repo) { return [string]$Project.repo }
    if ($Project.PSObject.Properties.Name -contains 'link' -and ([string]$Project.link -match 'github\.com/[^/]+/([^/?#]+)')) { return ($matches[1] -replace '\.git$', '') }
    return ''
}

function Get-GitHubRepositorySlug {
    $remote = Invoke-NativeCommand 'git' @('remote', 'get-url', 'origin')
    if ($remote.ExitCode -ne 0 -or $remote.Output.Count -eq 0) { return $null }
    $match = [regex]::Match($remote.Output[0].Trim(), '^(?:https?://(?:[^/@]+@)?|ssh://(?:[^/@]+@)?|(?:[^@]+@)?)github\.com[:/]([^/]+)/([^/?#]+?)(?:\.git)?/?$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return $null }
    return ($match.Groups[1].Value + '/' + $match.Groups[2].Value)
}

function Get-GitHubPublicRepos {
    $slug = Get-GitHubRepositorySlug
    if (-not $slug) { return @() }
    $owner = ($slug -split '/')[0]
    $uri = 'https://api.github.com/users/' + $owner + '/repos?per_page=100&sort=full_name&type=owner'
    $previousProtocols = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $allRepos = New-Object System.Collections.ArrayList
        $page = 1
        do {
            $response = @(Invoke-RestMethod -Uri ($uri + '&page=' + $page) -Method Get -Headers @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'srrobs-autopush-loop' } -TimeoutSec 15 -UseBasicParsing)
            foreach ($item in $response) { [void]$allRepos.Add($item) }
            $page++
        } while ($response.Count -eq 100)
        return @($allRepos)
    } catch { return @() }
    finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocols }
}

function Escape-HtmlText([string] $Text) {
    if ($null -eq $Text) { return '' }
    return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

function New-RepoProjectCard($RepoInfo, [string] $Num) {
    $name = [string]$RepoInfo.name
    $displayName = Get-CensoredText $name
    if (-not $displayName) { $displayName = 'Projeto GitHub' }
    $description = Get-CensoredText ([string]$RepoInfo.description)
    if (-not $description) { $description = 'Repositório detetado automaticamente pelo loop.' }
    $language = Get-CensoredText ([string]$RepoInfo.language)
    $pills = @()
    if ($language) { $pills += $language.ToUpperInvariant() }
    foreach ($topic in @($RepoInfo.topics)) {
        $safeTopic = Get-CensoredText ([string]$topic)
        if ($safeTopic) { $pills += $safeTopic.ToUpperInvariant() }
    }
    if ($pills.Count -eq 0) { $pills = @('GITHUB') }
    $suffix = if ($language) { ' • ' + $language } else { '' }
    $title = @(($displayName -replace '[-_]+', ' ').Trim() -split ' ' | Where-Object { $_ } | ForEach-Object { $_.Substring(0,1).ToUpperInvariant() + $_.Substring(1) }) -join ' '
    $categories = @($RepoInfo.topics | ForEach-Object { (Get-CensoredText ([string]$_)).ToLowerInvariant() } | Where-Object { $_ -in @('trading','games','bots','utils') } | Select-Object -Unique)
    if ($categories.Count -eq 0) { $categories = @('utils') }
    return [pscustomobject][ordered]@{
        num=$Num; slug=$name; repo=$name; titulo=$title
        etiqueta=$(if ($language) { $language.ToUpperInvariant() } else { 'GITHUB' })
        status='● NOVO — GITHUB'; categoria=($categories -join ' '); featured=$false
        desc=(Escape-HtmlText $description); arch=(Escape-HtmlText ($displayName + $suffix))
        pills=@($pills); link=[string]$RepoInfo.html_url; descModal=$description
        archModal=($displayName + $suffix); bullets=@(); path=$displayName.ToUpperInvariant(); pathFull=($displayName + $suffix)
    }
}

function Sync-ReadmeTable($Projetos) {
    $readmeFull = Join-Path $repo 'README.md'
    if (-not (Test-Path -LiteralPath $readmeFull)) { return }
    $text = [IO.File]::ReadAllText($readmeFull)
    $heading = [regex]::Match($text, '(?m)^## Projetos documentados \(\d+\)\s*$')
    $tableRows = [regex]::Matches($text, '(?m)^[^\S\r\n]*\|[^\r\n]*(?:\r?\n|$)')
    if ($tableRows.Count -eq 0) { return }
    $known = @{}
    foreach ($row in $tableRows) {
        $cells = [regex]::Match($row.Value, '^\s*\|\s*(\d+)\s*\|')
        if ($cells.Success) { $known[[int]$cells.Groups[1].Value] = $true }
    }
    $newline = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $newRows = @()
    foreach ($entry in $Projetos) {
        if ([string]$entry.num -notmatch '^\d+$' -or $known.ContainsKey([int]$entry.num)) { continue }
        $stack = (@($entry.pills) -join ', ')
        $newRows += ('| ' + $entry.num + ' | ' + ($entry.titulo -replace '\|','/') + ' | ' + ($entry.etiqueta -replace '\|','/') + ' | ' + ($stack -replace '\|','/') + ' |')
        $known[[int]$entry.num] = $true
    }
    if ($newRows.Count -gt 0) {
        $last = $tableRows[$tableRows.Count - 1]
        $insertAt = $last.Index + $last.Length
        $text = $text.Insert($insertAt, (($newRows -join $newline) + $newline))
    }
    if ($heading.Success) { $text = [regex]::Replace($text, '(?m)^## Projetos documentados \(\d+\)', ('## Projetos documentados (' + $Projetos.Count + ')')) }
    if ($text -cne [IO.File]::ReadAllText($readmeFull)) {
        [IO.File]::WriteAllText($readmeFull, $text, $script:Utf8NoBom)
        Write-Host ("README sincronizado: {0} projeto(s)." -f $Projetos.Count) -ForegroundColor Green
    }
}

function ConvertTo-CompactJson($Value) { return ($Value | ConvertTo-Json -Depth 8 -Compress) }
function Get-DiskContent([string]$RelativePath) {
    $full = Join-Path $repo $RelativePath
    if (-not (Test-Path -LiteralPath $full)) { return $null }
    return ([IO.File]::ReadAllText($full)).Trim()
}

function Set-ProjectsData {
    $dataFull = Join-Path $repo $dataPath
    $existingProjetos = @()
    $existingJson = $null
    if (Test-Path -LiteralPath $dataFull) {
        try {
            $existing = Get-Content -LiteralPath $dataFull -Raw -Encoding UTF8 | ConvertFrom-Json
            $existingProjetos = @($existing.projetos)
            $existingJson = ConvertTo-CompactJson ([ordered]@{ projetos_documentados=$existing.projetos_documentados; projetos=$existingProjetos })
        } catch { $existingJson = $null; $existingProjetos = @() }
    }
    $repos = @(Get-GitHubPublicRepos)
    $reposByName = @{}
    foreach ($item in $repos) { $reposByName[[string]$item.name] = $item }
    $covered = @{}
    $projects = New-Object System.Collections.ArrayList
    foreach ($entry in $existingProjetos) {
        $repoName = Get-ProjectRepoName $entry
        if ($repoName) {
            $covered[$repoName] = $true
            if ($entry.PSObject.Properties.Name -contains 'categoria' -and [string]::IsNullOrWhiteSpace([string]$entry.categoria)) { $entry.categoria = 'utils' }
            foreach ($field in @('titulo','etiqueta','status','desc','arch','descModal','archModal','path','pathFull')) {
                if ($entry.PSObject.Properties.Name -contains $field -and $entry.$field -is [string]) {
                    $entry.$field = Get-SafeProjectText ([string]$entry.$field)
                }
            }
            if ($entry.PSObject.Properties.Name -contains 'pills') {
                $entry.pills = @($entry.pills | ForEach-Object { Get-SafeProjectText ([string]$_) })
            }
            if ($entry.PSObject.Properties.Name -contains 'bullets') {
                $entry.bullets = @($entry.bullets | ForEach-Object { Get-SafeProjectText ([string]$_) })
            }
            $info = $reposByName[$repoName]
            if ($null -ne $info -and ($entry.PSObject.Properties.Name -contains 'link')) { $entry.link = [string]$info.html_url }
        }
        [void]$projects.Add($entry)
    }
    $next = 1
    foreach ($entry in $projects) { if ([string]$entry.num -match '^\d+$' -and [int]$entry.num -ge $next) { $next = [int]$entry.num + 1 } }
    foreach ($item in $repos) {
        $name = [string]$item.name
        if ($covered.ContainsKey($name)) { continue }
        [void]$projects.Add((New-RepoProjectCard $item $next.ToString('00')))
        $covered[$name] = $true
        $next++
    }        $count = $projects.Count
        $script:SiteProjects = @($projects)
        $script:SiteCategoryCounts = @{ trading=0; games=0; bots=0; utils=0 }
        foreach ($project in $projects) {
            foreach ($category in ([string]$project.categoria -split '\s+')) {
                if ($script:SiteCategoryCounts.ContainsKey($category)) { $script:SiteCategoryCounts[$category]++ }
            }
        }
        $core = [ordered]@{ projetos_documentados=$count; projetos=$projects }
    Sync-ReadmeTable $projects
    if ($null -ne $existingJson -and $existingJson -ceq (ConvertTo-CompactJson $core)) {
        $script:SiteDocumented = $count
        Write-Host ("Site já atualizado: {0} projeto(s)." -f $count) -ForegroundColor DarkGray
        return
    }
    $script:SiteDocumented = $count
    $payload = [ordered]@{ gerado_em=(Get-Date -Format 'yyyy-MM-dd HH:mm'); projetos_documentados=$count; projetos=$projects }
    [IO.File]::WriteAllText($dataFull, (ConvertTo-CompactJson $payload) + "`n", $script:Utf8NoBom)
    Write-Host ("Lista censurada sincronizada: {0} projeto(s)." -f $count) -ForegroundColor Green
}

function Get-CountSafeNormalized([string]$Text) {
    $lines = @(($Text -replace "`r`n", "`n") -split "`n" | Where-Object { $_ -notmatch '^\s*\|' })
    return (($lines -join "`n") -replace '\d+', '#')
}
function Test-CountOnlyChange([string]$RelativePath) {
    $head = Invoke-NativeCommand 'git' @('show', ('HEAD:' + $RelativePath))
    if ($head.ExitCode -ne 0) { return $false }
    $full = Join-Path $repo $RelativePath
    if (-not (Test-Path -LiteralPath $full)) { return $false }
    $oldText = $head.Output -join "`n"
    $newText = [IO.File]::ReadAllText($full)
    if ($RelativePath -eq 'README.md') {
        $oldRows = @([regex]::Matches($oldText, '(?m)^\|[^\r\n]*$') | ForEach-Object { $_.Value })
        $newRows = @([regex]::Matches($newText, '(?m)^\|[^\r\n]*$') | ForEach-Object { $_.Value })
        if ($newRows.Count -lt $oldRows.Count) { return $false }
        for ($i = 0; $i -lt $oldRows.Count; $i++) { if ($oldRows[$i] -cne $newRows[$i]) { return $false } }
        $expectedRows = @()
        $oldNumbers = @{}
        foreach ($row in $oldRows) {
            $numberMatch = [regex]::Match($row, '^\|\s*(\d+)\s*\|')
            if ($numberMatch.Success) { $oldNumbers[[int]$numberMatch.Groups[1].Value] = $true }
        }
        foreach ($project in @($script:SiteProjects)) {
            if ([string]$project.num -notmatch '^\d+$' -or $oldNumbers.ContainsKey([int]$project.num)) { continue }
            $stack = (@($project.pills) -join ', ')
            $expectedRows += ('| ' + $project.num + ' | ' + ($project.titulo -replace '\|','/') + ' | ' + ($project.etiqueta -replace '\|','/') + ' | ' + ($stack -replace '\|','/') + ' |')
            $oldNumbers[[int]$project.num] = $true
        }
        $addedRows = @($newRows | Select-Object -Skip $oldRows.Count)
        if ($addedRows.Count -ne $expectedRows.Count) { return $false }
        for ($i = 0; $i -lt $expectedRows.Count; $i++) { if ($addedRows[$i] -cne $expectedRows[$i]) { return $false } }
        $oldText = [regex]::Replace($oldText, '(?m)^\|[^\r\n]*(?:\r?\n|$)', '')
        $newText = [regex]::Replace($newText, '(?m)^\|[^\r\n]*(?:\r?\n|$)', '')
        $oldText = [regex]::Replace($oldText, '(## Projetos documentados \()\d+(\))', '$1#$2')
        $newText = [regex]::Replace($newText, '(## Projetos documentados \()\d+(\))', '$1#$2')
        foreach ($pattern in @('(\*\*)\d+( projetos mapeados\*\*)','(\*\*)\d+( projetos\*\*)','(\(\s*)\d+( cards gerados)','(grelha \()\d+(\))')) {
            $oldText = [regex]::Replace($oldText, $pattern, '$1#$2')
            $newText = [regex]::Replace($newText, $pattern, '$1#$2')
        }
    } elseif ($RelativePath -eq 'index.html') {
        foreach ($pattern in @(
            '(content="[^"]*?)\d+( projetos reais)',
            '(content="SrRobs — )\d+( projetos reais)',
            '(content=")\d+( projetos:)',
            '(class="js-doc">)\d+(</span>)',
            '(data-count=")\d+(">)',
            '(id="filterCount">)\d+(</span>)',
            '(TODOS <span>)\d+(</span>)',
            '(data-filter="trading" role="tab">TRADING <span>)\d+(</span>)',
            '(data-filter="games" role="tab">GAMES <span>)\d+(</span>)',
            '(data-filter="bots" role="tab">BOTS <span>)\d+(</span>)',
            '(data-filter="utils" role="tab">UTILS <span>)\d+(</span>)',
            '(id="estadoProjetosFoot">)\d+(</span>)'
        )) {
            $oldText = [regex]::Replace($oldText, $pattern, '$1#$2')
            $newText = [regex]::Replace($newText, $pattern, '$1#$2')
        }
    } elseif ($RelativePath -eq 'og-image.svg') {
        foreach ($pattern in @('\d+( projetos reais)','\d+( projetos documentados)','\d+( PROJETOS MAPEADOS)')) {
            $oldText = [regex]::Replace($oldText, $pattern, '#$1')
            $newText = [regex]::Replace($newText, $pattern, '#$1')
        }
    }
    return ($oldText -ceq $newText)
}

function Sync-CountTexts([int]$Documented) {
    $rules = @{
        'README.md' = @(
            @{ Pattern='(\*\*)\d+( projetos mapeados\*\*)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(\*\*)\d+( projetos\*\*)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(## Projetos documentados \()\d+(\))'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(\(\s*)\d+( cards gerados)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(grelha \()\d+(\))'; Replacement=('${1}'+$Documented+'${2}') }
        )
        'og-image.svg' = @(
            @{ Pattern='\d+( projetos reais)'; Replacement=([string]$Documented+'$1') },
            @{ Pattern='\d+( projetos documentados)'; Replacement=([string]$Documented+'$1') },
            @{ Pattern='\d+( PROJETOS MAPEADOS)'; Replacement=([string]$Documented+'$1') }
        )
        'index.html' = @(
            @{ Pattern='(content="[^"]*?)\d+( projetos reais)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(content="SrRobs — )\d+( projetos reais)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(content=")\d+( projetos:)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(class="js-doc">)\d+(</span>)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(data-count=")\d+(">)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(id="filterCount">)\d+(</span>)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(TODOS <span>)\d+(</span>)'; Replacement=('${1}'+$Documented+'${2}') },
            @{ Pattern='(data-filter="trading" role="tab">TRADING <span>)\d+(</span>)'; Replacement=('${1}'+$script:SiteCategoryCounts.trading+'${2}') },
            @{ Pattern='(data-filter="games" role="tab">GAMES <span>)\d+(</span>)'; Replacement=('${1}'+$script:SiteCategoryCounts.games+'${2}') },
            @{ Pattern='(data-filter="bots" role="tab">BOTS <span>)\d+(</span>)'; Replacement=('${1}'+$script:SiteCategoryCounts.bots+'${2}') },
            @{ Pattern='(data-filter="utils" role="tab">UTILS <span>)\d+(</span>)'; Replacement=('${1}'+$script:SiteCategoryCounts.utils+'${2}') },
            @{ Pattern='(id="estadoProjetosFoot">)\d+(</span>)'; Replacement=('${1}'+$Documented+'${2}') }
        )
    }
    foreach ($relative in $countSyncPaths) {
        if (-not $rules.ContainsKey($relative)) { continue }
        $full = Join-Path $repo $relative
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $text = [IO.File]::ReadAllText($full)
        $updated = $text
        foreach ($rule in $rules[$relative]) { $updated = [regex]::Replace($updated, $rule.Pattern, $rule.Replacement) }
        if ($updated -cne $text) {
            [IO.File]::WriteAllText($full, $updated, $script:Utf8NoBom)
            Write-Host ("Contagens sincronizadas em {0}." -f $relative) -ForegroundColor Green
        }
    }
}

function Test-ProtectedPath([string]$Path) {
    foreach ($protected in $protectedPaths) {
        if ($protected.EndsWith('/')) { if ($Path.StartsWith($protected, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
        elseif ($Path.Equals($protected, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}
function Get-Upstream {
    $r = Invoke-NativeCommand 'git' @('rev-parse','--abbrev-ref','--symbolic-full-name','@{upstream}')
    if ($r.ExitCode -ne 0 -or $r.Output.Count -eq 0) { return $null }
    return $r.Output[0].Trim()
}
function Get-AheadCount([string]$Upstream) {
    $r = Invoke-NativeCommand 'git' @('rev-list','--count',($Upstream+'..HEAD'))
    $n = 0
    if ($r.ExitCode -ne 0 -or $r.Output.Count -eq 0 -or -not [int]::TryParse($r.Output[0].Trim(),[ref]$n)) { return $null }
    return $n
}
function Test-PendingCommitSafe([string]$Upstream,$ExpectedFiles) {
    if ((Get-AheadCount $Upstream) -ne 1) { return $false }
    $subject = Invoke-NativeCommand 'git' @('log','-1','--format=%s')
    if ($subject.ExitCode -ne 0 -or $subject.Output.Count -eq 0 -or $subject.Output[0] -cne $expectedCommitSubject) { return $false }
    $paths = Invoke-NativeCommand 'git' @('diff','--name-only',($Upstream+'..HEAD'))
    if ($paths.ExitCode -ne 0 -or $paths.Output.Count -eq 0) { return $false }
    foreach ($path in $paths.Output) {
        $p = $path.Trim().Replace('\','/')
        if (-not $ExpectedFiles.ContainsKey($p)) { return $false }
        $content = Invoke-NativeCommand 'git' @('show',('HEAD:'+$p))
        if ($content.ExitCode -ne 0 -or (($content.Output -join "`n").Trim() -cne $ExpectedFiles[$p])) { return $false }
    }
    return $true
}
function Invoke-GitChecked([string[]]$Arguments) {
    $r = Invoke-NativeCommand 'git' $Arguments
    if ($r.ExitCode -eq 0) { return }
    if ($Arguments[0] -eq 'commit') {
        $message = $r.Output -join ' '
        if ($message -match '(?i)Author identity unknown|unable to auto-detect email|please tell me who you are|fatal:.*user\.email') {
            throw [System.InvalidOperationException]::new("AUTOPUSH: Falta configurar a identidade Git com 'git config --global user.name' e 'git config --global user.email'; os valores foram ocultados.")
        }
    }
    throw [System.InvalidOperationException]::new(("AUTOPUSH: Git falhou (código {0}); detalhes ocultos para proteger dados." -f $r.ExitCode))
}

function Get-GitHubTokenSecure {
    if (-not $script:GitHubTokenPrompted) {
        $script:GitHubTokenPrompted = $true
        if ([Console]::IsInputRedirected) {
            Write-Host 'Entrada não interativa: descrição do repositório não alterada; usa gh auth login se quiseres sincronizá-la.' -ForegroundColor DarkGray
            return $null
        }
        Write-Host 'Para atualizar a descrição remota, usa gh auth login ou fornece um token fine-grained com permissão Administration: write.' -ForegroundColor Yellow
        $script:GitHubTokenSecure = Read-Host 'Token GitHub (Enter para ignorar; entrada oculta)' -AsSecureString
    }
    if ($null -eq $script:GitHubTokenSecure -or $script:GitHubTokenSecure.Length -eq 0) { return $null }
    return $script:GitHubTokenSecure
}

function Update-GitHubDescriptionWithToken([string]$Slug, [string]$Description) {
    $secureToken = Get-GitHubTokenSecure
    if ($null -eq $secureToken) { return }
    $pointer = [IntPtr]::Zero
    $tokenText = $null
    $headers = $null
    $oldProtocols = [Net.ServicePointManager]::SecurityProtocol
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $tokenText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $headers = @{ Authorization="Bearer $tokenText"; Accept='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28' }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $uri = 'https://api.github.com/repos/' + $Slug
        $body = @{ description=$Description } | ConvertTo-Json -Compress
        $null = Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body $body -ContentType 'application/json; charset=utf-8' -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
        Write-Host 'Descrição do repositório atualizada.' -ForegroundColor Green
    } catch {
        $status = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status) { Write-Host ("Atualização da descrição recusada (HTTP {0}); detalhe ocultado." -f $status) -ForegroundColor Yellow }
        else { Write-Host 'Não foi possível atualizar a descrição; erro ocultado.' -ForegroundColor Yellow }
    } finally {
        if ($headers) { $headers.Clear() }
        $tokenText = $null
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        [Net.ServicePointManager]::SecurityProtocol = $oldProtocols
    }
}

function Set-GitHubRepositoryDescription([string]$Description) {
    $slug = Get-GitHubRepositorySlug
    if (-not $slug) { return }
    $gh = Get-Command 'gh' -ErrorAction SilentlyContinue
    if ($gh) {
        $current = Invoke-NativeCommand $gh.Source @('repo','view',$slug,'--json','description','--jq','.description')
        if ($current.ExitCode -eq 0 -and (($current.Output -join "`n").Trim() -ceq $Description)) { return }
        if ($current.ExitCode -eq 0) {
            $edit = Invoke-NativeCommand $gh.Source @('repo','edit',$slug,'--description',$Description)
            if ($edit.ExitCode -eq 0) { return }
        }
    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $publicRepo = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $slug) -Method Get -Headers @{ Accept='application/vnd.github+json' } -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
        if ([string]$publicRepo.description -ceq $Description) { return }
    } catch { }
    Update-GitHubDescriptionWithToken $slug $Description
}

function Invoke-AuditCycle {
    Write-Host ("`n[{0}] Sincronização" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
    $description = Get-RedactedReadmeDescription
    $descriptionFull = Join-Path $repo $descriptionPath
    [IO.File]::WriteAllText($descriptionFull, $description + "`n", $script:Utf8NoBom)
    Set-GitHubRepositoryDescription $description
    Set-ProjectsData
    Sync-CountTexts $script:SiteDocumented

    $allowedPaths = @($generatedPaths) + @($countSyncPaths)
    $expected = @{}
    foreach ($path in $allowedPaths) { $content = Get-DiskContent $path; if ($null -ne $content) { $expected[$path] = $content } }
    $status = Invoke-NativeCommand 'git' @('status','--porcelain=v1','--untracked-files=all')
    if ($status.ExitCode -ne 0) { throw 'Não foi possível verificar o estado do Git.' }
    $entries = @($status.Output | Where-Object { $_.Length -ge 3 } | ForEach-Object { [pscustomobject]@{ Code=$_.Substring(0,2); Path=$_.Substring(3).Trim('"').Replace('\','/') } })
    $upstream = Get-Upstream
    if (-not $upstream) { Write-Host 'Sem upstream Git; commit/push automáticos desativados.' -ForegroundColor Yellow; return }

    if (Test-PendingCommitSafe $upstream $expected) {
        $push = Invoke-NativeCommand 'git' @('push')
        if ($push.ExitCode -eq 0) { Write-Host 'Push dos dados gerados concluído.' -ForegroundColor Green }
        else { Write-Host 'Push pendente; o loop voltará a tentar.' -ForegroundColor Yellow }
        return
    }
    $generatedChanges = @($entries | Where-Object { $allowedPaths -contains $_.Path })
    if ($generatedChanges.Count -eq 0) { Write-Host 'Sem alterações geradas; restantes alterações preservadas.' -ForegroundColor DarkGray; return }
    if (@($generatedChanges | Where-Object { $_.Code -match 'A|D|R|C|U' }).Count -gt 0) {
        Write-Host 'Commit automático bloqueado para adicionar/remover/renomear ficheiros gerados.' -ForegroundColor Yellow
        return
    }
    foreach ($path in $countSyncPaths) {
        if ($generatedChanges | Where-Object { $_.Path -ceq $path }) {
            if (-not (Test-CountOnlyChange $path)) { Write-Host 'Commit automático bloqueado: ficheiro gerado contém alterações além das contagens.' -ForegroundColor Yellow; return }
        }
    }
    if (@($generatedChanges | Where-Object { Test-ProtectedPath $_.Path }).Count -gt 0) { return }
    $stagedCheck = Invoke-NativeCommand 'git' @('diff','--cached','--quiet')
    if ($stagedCheck.ExitCode -ne 0) { Write-Host 'Alterações staged existentes preservadas; commit automático suspenso.' -ForegroundColor Yellow; return }
    $ahead = Get-AheadCount $upstream
    if ($null -eq $ahead -or $ahead -ne 0) { Write-Host 'Commits locais pendentes; nada será enviado automaticamente.' -ForegroundColor Yellow; return }

    Invoke-GitChecked (@('add','--') + $allowedPaths)
    $staged = Invoke-NativeCommand 'git' @('diff','--cached','--name-only')
    if ($staged.ExitCode -ne 0 -or $staged.Output.Count -eq 0) { return }
    foreach ($path in $staged.Output) {
        $p = $path.Trim().Replace('\','/')
        if (-not $expected.ContainsKey($p)) { Write-Host 'Staging inesperado; commit bloqueado.' -ForegroundColor Yellow; return }
        $content = Invoke-NativeCommand 'git' @('show',(':'+$p))
        if ($content.ExitCode -ne 0 -or (($content.Output -join "`n").Trim() -cne $expected[$p])) { Write-Host 'Staging não corresponde aos dados gerados; commit bloqueado.' -ForegroundColor Yellow; return }
    }
    if (-not (Test-StagedSecrets $repo)) {
        Write-Host 'Commit automático do portfolio bloqueado pela verificação de segurança; nada será enviado.' -ForegroundColor Red
        return
    }
    Invoke-GitChecked @('commit','-m',$expectedCommitSubject)
    $push = Invoke-NativeCommand 'git' @('push')
    if ($push.ExitCode -eq 0) { Write-Host 'Portfolio publicado; GitHub Pages fará o deploy.' -ForegroundColor Green }
    else { Write-Host 'Commit do portfolio criado; push falhou e será repetido após revalidar.' -ForegroundColor Yellow }
}

function Test-StagedSecrets([string]$RepositoryPath) {
    if (-not (Test-Path -LiteralPath $RepositoryPath -PathType Container)) { return $false }
    Push-Location -LiteralPath (Resolve-Path -LiteralPath $RepositoryPath).Path
    try {
        $changed = Invoke-NativeCommand 'git' @('diff','--cached','--name-only','--diff-filter=ACMR')
        if ($changed.ExitCode -ne 0) { return $false }
        $filePattern = '(?i)(^|/)(\.env(?:\.(?!example$|sample$|template$)[^/]*)?|id_(?:rsa|dsa|ed25519)|credentials?\.json|secrets?\.(?:json|ya?ml)|[^/]+\.(?:pem|p12|pfx|key))$'
        foreach ($path in $changed.Output) {
            if ($path.Trim() -match $filePattern) { Write-Host 'COMMIT BLOQUEADO: ficheiro com nome típico de segredo staged; caminho ocultado.' -ForegroundColor Red; return $false }
        }
        $diff = Invoke-NativeCommand 'git' @('diff','--cached','--no-ext-diff','--no-color','--unified=0','--')
        if ($diff.ExitCode -ne 0) { return $false }
        $patterns = @(
            '-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
            '\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[A-Za-z0-9-]{15,})\b',
            '(?i)\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password|passwd|secret[_-]?key)\b\s*[:=]\s*["'']?(?!your[_ -]|example|changeme|change[_ -]me|replace[_ -]me|dummy|placeholder|redacted|censored|xxx|test["'']?\b)[A-Za-z0-9_./+=-]{12,}',
            '(?i)\b[A-Za-z]:\\Users\\[^\s\\]+\\',
            '(?i)\bBearer\s+[A-Za-z0-9._~+/-]{16,}',
            '(?i)https?://(?:discord(?:app)?\.com/api/webhooks|hooks\.slack\.com/services)/\S+',
            '\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}\b',
            '\b(?:npm_[A-Za-z0-9]{30,}|xapp-[A-Za-z0-9-]{20,})\b',
            '\b[\w.+-]+@[\w-]+\.[\w.-]+\b'
        )
        foreach ($line in $diff.Output) {
            if (-not $line.StartsWith('+') -or $line.StartsWith('+++')) { continue }
            $added = $line.Substring(1).Replace('SrRobsParecias@proton.me', '')
            foreach ($pattern in $patterns) {
                if ([regex]::IsMatch($added,$pattern)) { Write-Host 'COMMIT BLOQUEADO: possível segredo ou caminho pessoal detetado; conteúdo ocultado.' -ForegroundColor Red; return $false }
            }
        }
        Write-Host 'Verificação concluída: nenhum padrão conhecido de segredo encontrado.' -ForegroundColor Green
        return $true
    } finally { Pop-Location }
}

function Get-ProjectRepositories([string]$Root) {
    $found = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { Write-Host 'Pasta de projetos não encontrada; scan de commits desativado.' -ForegroundColor Yellow; return @() }
    $excluded = @('node_modules','vendor','.venv','venv','env','__pycache__','.cache','packages','Program Files','Program Files (x86)','Windows','AppData','SteamLibrary','Games','$RECYCLE.BIN','System Volume Information','Recovery','PerfLogs')
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue([pscustomobject]@{ Path=(Resolve-Path -LiteralPath $Root).Path; Depth=0 })
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue(); $directory = [string]$current.Path
        if (Test-Path -LiteralPath (Join-Path $directory '.git')) { [void]$found.Add($directory); continue }
        if ($current.Depth -ge 4) { continue }
        try {
            foreach ($child in Get-ChildItem -LiteralPath $directory -Directory -Force -ErrorAction SilentlyContinue) {
                if ($excluded -contains $child.Name -or ($child.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
                if ($child.Name.StartsWith('.') -and $child.Name -ne '.projects') { continue }
                $queue.Enqueue([pscustomobject]@{ Path=$child.FullName; Depth=$current.Depth+1 })
            }
        } catch { }
    }
    return @($found)
}

function Install-SecretScanHooks([string]$Root) {
    $repositories = @(Get-ProjectRepositories $Root)
    $installed = 0
    $existing = 0
    $failed = 0
    foreach ($repository in $repositories) {
        $result = Invoke-NativeCommand 'git' @('-C', $repository, 'rev-parse', '--git-path', 'hooks/pre-commit')
        if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) { $failed++; continue }
        $hookPath = $result.Output[0].Trim()
        if (-not [IO.Path]::IsPathRooted($hookPath)) { $hookPath = Join-Path $repository $hookPath }
        $hookDirectory = Split-Path -Parent $hookPath
        if (-not (Test-Path -LiteralPath $hookDirectory)) {
            try { New-Item -ItemType Directory -Path $hookDirectory -Force | Out-Null }
            catch { $failed++; continue }
        }
        if (Test-Path -LiteralPath $hookPath) { $existing++; continue }

        $scriptPath = [string]$PSCommandPath
        $repoPath = [string]$repository
        if ($scriptPath -match "'") { $failed++; continue }
        if ($repoPath -match "'") { $failed++; continue }
        $scriptPath = $scriptPath.Replace('\', '/')
        $repoPath = $repoPath.Replace('\', '/')
        $shell = 'powershell.exe'
        if (-not (Get-Command $shell -ErrorAction SilentlyContinue)) { $shell = 'pwsh' }
        $hookLines = @(
            '#!/bin/sh',
            '# SRROBS SECRET SCAN HOOK - managed by autopush-loop',
            "'$shell' -NoLogo -NoProfile -ExecutionPolicy Bypass -File '$scriptPath' -ScanCommit -RepositoryPath '$repoPath'",
            'status=$?',
            'if [ "$status" -ne 0 ]; then exit 1; fi',
            'exit 0'
        )
        try {
            [IO.File]::WriteAllText($hookPath, ($hookLines -join "`n") + "`n", $script:Utf8NoBom)
            $installed++
        } catch { $failed++ }
    }
    Write-Host ("Scan de commits: {0} repositório(s), {1} hook(s) instalado(s), {2} hooks preexistentes preservados, {3} erro(s)." -f $repositories.Count, $installed, $existing, $failed) -ForegroundColor Cyan
}

if ($ScanCommit) {
    if (-not $RepositoryPath) { Write-Host 'Verificação bloqueada: falta caminho do repositório.' -ForegroundColor Red; exit 2 }
    if (Test-StagedSecrets $RepositoryPath) { exit 0 } else { exit 1 }
}
Write-Host 'Loop seguro: sincroniza todos os repositórios públicos no portfolio e as contagens, e instala verificações de segurança nos clones detetados. Não faz commits dos projetos; as tuas alterações alheias são preservadas. Ctrl+C termina.' -ForegroundColor Green
Write-Host ("Intervalo: {0}s. Raiz dos projetos: {1}. Usa -Once para um único ciclo." -f $IntervalSeconds,$ProjectsRoot) -ForegroundColor Green
Install-SecretScanHooks $ProjectsRoot
if ($Once) {
    try { Invoke-AuditCycle } catch { Write-LoopError $_; exit 1 }
    exit 0
}
while ($true) {
    try { Invoke-AuditCycle; Install-SecretScanHooks $ProjectsRoot } catch { Write-LoopError $_ }
    Write-Host ("Próxima verificação em {0} minuto(s). Ctrl+C para parar." -f [math]::Round($IntervalSeconds/60,1)) -ForegroundColor DarkGray
    Start-Sleep -Seconds $IntervalSeconds
}
