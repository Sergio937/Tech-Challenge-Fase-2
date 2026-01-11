function Show-Header {
    param([string]$Title)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "[$timestamp]   $Title" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Log-Error {
    param([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][ERRO] $msg" -ForegroundColor Red
}

$global:BASE_URL = ""
$global:API_KEY = ""

try {
    Clear-Host
    Show-Header "TESTE COMPLETO END-TO-END - TOGGLEMASTER"

    # === LOAD BALANCER ===
    Write-Host "[INFO] Obtendo Load Balancer URL..." -ForegroundColor Gray
    $LB_URL = kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    if (-not $LB_URL) { Log-Error "Load Balancer não encontrado!"; throw "LB not found" }
    $global:BASE_URL = "http://$LB_URL"
    Write-Host "[OK] Load Balancer: $global:BASE_URL`n" -ForegroundColor Green

    # === MASTER KEY ===
    $MASTER_KEY = "minhamasterkeysupersecreta"

    # === ETAPA 1 - CRIAR API KEY ===
    Show-Header "ETAPA 1 - CRIAR API KEY"

    $body = '{"name":"teste-end-to-end"}'
    $headers = @{
        "Content-Type"="application/json"
        "Authorization"="Bearer $MASTER_KEY"
    }

    try {
        $response = Invoke-WebRequest -Uri "$global:BASE_URL/auth/admin/keys" -Method POST -Headers $headers -Body $body -UseBasicParsing
        $apiKeyData = $response.Content | ConvertFrom-Json
        $global:API_KEY = $apiKeyData.key
        Write-Host "[OK] API Key criada: $global:API_KEY" -ForegroundColor Green
    }
    catch {
        Log-Error "Falha ao criar API Key"
        throw
    }

    # === ETAPA 2 - VALIDAR API KEY ===
    Show-Header "ETAPA 2 - VALIDAR API KEY"

    try {
        Invoke-WebRequest -Uri "$global:BASE_URL/auth/validate" -Headers @{"Authorization"="Bearer $global:API_KEY"} -UseBasicParsing | Out-Null
        Write-Host "[OK] API Key válida" -ForegroundColor Green
    }
    catch {
        Log-Error "Validação falhou"
        throw
    }

    # === ETAPA 3 - CRIAR FLAG ===
    Show-Header "ETAPA 3 - CRIAR FLAG"

    $flagBody = '{"name":"enable-new-dashboard","description":"Ativa o novo dashboard","is_enabled":true}'
    $flagHeaders = @{
        "Content-Type"="application/json"
        "Authorization"="Bearer $global:API_KEY"
    }

    try {
        Invoke-WebRequest -Uri "$global:BASE_URL/flags/flags" -Method POST -Headers $flagHeaders -Body $flagBody -UseBasicParsing | Out-Null
        Write-Host "[OK] Flag criada" -ForegroundColor Green
    }
    catch {
        $errBody = $null
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
        }
        if ($errBody -like "*já existe*" -or [string]::IsNullOrWhiteSpace($errBody)) {
            Write-Host "[OK] Flag já existia" -ForegroundColor Yellow
        } else {
            Log-Error "Falha ao criar flag: $errBody"
            throw
        }
    }

    # === ETAPA 4 - CRIAR REGRA DE TARGETING ===
    Show-Header "ETAPA 4 - CRIAR REGRA DE TARGETING"

    $ruleBody = '{"flag_name":"enable-new-dashboard","is_enabled":true,"rules":{"type":"PERCENTAGE","value":50}}'

    try {
        Invoke-WebRequest -Uri "$global:BASE_URL/targeting/rules" -Method POST -Headers $flagHeaders -Body $ruleBody -UseBasicParsing | Out-Null
        Write-Host "[OK] Regra criada" -ForegroundColor Green
    }
    catch {
        $errBody = $null
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
        }
        if ($errBody -like "*já existe*" -or [string]::IsNullOrWhiteSpace($errBody)) {
            Write-Host "[OK] Regra já existia" -ForegroundColor Yellow
        } else {
            Log-Error "Falha ao criar regra: $errBody"
            throw
        }
    }

    # === ETAPA 5 - AVALIAR FLAGS ===
    Show-Header "ETAPA 5 - AVALIAR FLAGS (10 usuários)"

    $trueCount = 0
    $falseCount = 0

    for ($i = 1; $i -le 10; $i++) {
        $evalUrl = "$global:BASE_URL/evaluation/evaluate?user_id=user-$i&flag_name=enable-new-dashboard"
        try {
            $evalResponse = Invoke-WebRequest -Uri $evalUrl -Headers @{"Authorization"="Bearer $global:API_KEY"} -UseBasicParsing
            $evalData = $evalResponse.Content | ConvertFrom-Json
            if ($evalData.result -eq $true) {
                Write-Host "[$i] user-$i -> TRUE" -ForegroundColor Green
                $trueCount++
            } else {
                Write-Host "[$i] user-$i -> FALSE" -ForegroundColor Yellow
                $falseCount++
            }
        }
        catch {
            Write-Host "[$i] user-$i -> ERRO" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 300
    }
    Write-Host "`n[RESUMO] TRUE: $trueCount | FALSE: $falseCount (esperado ~50%)" -ForegroundColor Cyan
}
finally {
    Show-Header "FINAL - INFORMAÇÕES IMPORTANTES"
    Write-Host "Load Balancer: $global:BASE_URL" -ForegroundColor Cyan
    Write-Host "API Key usada: $global:API_KEY" -ForegroundColor White
    Write-Host "\n[LOGS analytics-service]\n" -ForegroundColor Yellow
    kubectl logs -n togglemaster -l app=analytics-service --tail=10
}

# === ETAPA 6 - LOGS ANALYTICS ===
Show-Header "ETAPA 6 - LOGS ANALYTICS"

Start-Sleep -Seconds 5
kubectl logs -n togglemaster -l app=analytics-service --tail=10

# === FINAL ===
Show-Header "TESTE FINALIZADO COM SUCESSO"

Write-Host "Load Balancer: $BASE_URL" -ForegroundColor Cyan
Write-Host "API Key usada: $API_KEY" -ForegroundColor White
