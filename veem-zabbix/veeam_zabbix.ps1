#INICIO DO SCRIPT
# CONFIGURAÇÕES
$veeamServer = "https://SEU-SERVER-VEEAM:9419"
$zabbixServer = "IP_DO_ZABBIX"
$zabbixHost = "NOME_DO_HOST_NO_ZABBIX"
$zabbixSender = "C:\Program Files\Zabbix Agent\zabbix_sender.exe"

# IGNORAR SSL (se Veeam usar cert self-signed)
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#Importa usuário e senha criptografa do arquivo .xml gerado atravez do xport-Clixml
$cred = Import-Clixml "C:\Scripts\VeeamZabbix\veeam_api_cred.xml"

#Gera o token via POST ao veeam bakcup necessário toda vez que for realizar qualquer comando via API, dura em torno de 900sec
#Consulta o XML descriptografa a senha do usuário AD e fornece ao body para solicitar o Token
$body = "grant_type=password&username=$($cred.UserName)&password=$($cred.GetNetworkCredential().Password)"

#Solicita o token via POST na API.
$tokenResponse = Invoke-RestMethod -Method Post `
    -Uri "$veeamServer/api/oauth2/token" `
    -Body $body `
    -ContentType "application/x-www-form-urlencoded"

#Armazena o token.
$accessToken = $tokenResponse.access_token

#Criar o header com o Token
$headers = @{
    Authorization = "Bearer $accessToken"
}

#Busca a sessões (resumido é os jobs de backup que já rodaram com status: success, warning ou fail).
$sessions = Invoke-RestMethod -Method Get `
    -Uri "$veeamServer/api/v1/sessions" `
    -Headers $headers

#Inicio do processo dos dados e tratativas para envios ao zabbix
$today = (Get-Date).Date

$success = 0
$warning = 0
$failed = 0

$resultByJob = @{}

#Percorre todos os JOBS retornados do GET da API do Veeam, realiza o Trim removendo o tipo do Bakcup Job que é anexado no final do nome.
#E add dentro do objeto Name colocando como deafult o valor 0 para seu status, pois caso ele não rodou ainda no dia corrente ele é tratado no Grafana como Pending.
foreach ($item in $sessions.data) {

    $jobNameRaw = $item.name

    $jobName = $jobNameRaw `
        -replace '\s*\(.*?\)$', '' `
        -replace '\s+(Offload|Copy|Retry)$', ''

    $jobName = $jobName.Trim()

    # Inicializa como Pending se ainda não existir
    if (-not $resultByJob.ContainsKey($jobName)) {
        $resultByJob[$jobName] = 0
    }
}

#percorrer os jobs que retornaram do GET da API para tratar os status
foreach ($item in $sessions.data) {

    #Captura a Data de criação do ultimo running do JOB do backup para verificar se o bate com a data do dia atual.
    $sessionDate = ([DateTime]::Parse($item.creationTime)).ToLocalTime().Date

    #Se a data do dia atual for igual a data do JOB segue:
    if ($sessionDate -eq $today) {

        #Captura o nome do Job
        $jobNameRaw = $item.name

        #Remove qualquer valores que não condiz com o nome do job vindo do veeam
        $jobName = $jobNameRaw `
            -replace '\s*\(.*?\)$', '' `
            -replace '\s+(Offload|Copy|Retry)$', ''
        $jobName = $jobName.Trim()

        #Captura o STATUS atual do Job
        $status = $item.result.result

        #Verifica o status e seta o valor somando quando JOBS de sucesso, aviso ou falha.
        switch ($status) {
            "Success" { $value = 1; $success++ }
            "Warning" { $value = 2; $warning++ }
            "Failed" { $value = 3; $failed++ }
            default { $value = 0 }
        }

        #Se o status atual for pior que o que já está salvo, então atualiza.
        if ($value -gt $resultByJob[$jobName]) {
            $resultByJob[$jobName] = $value
        }
    }
}


#Inicia o envio ao zabbix aos itens cirados dentro do host também criado no Zabbix Server
& "$zabbixSender" -z $zabbixServer -s $zabbixHost -k veeam.backup.success.today -o $success
& "$zabbixSender" -z $zabbixServer -s $zabbixHost -k veeam.backup.warning.today -o $warning
& "$zabbixSender" -z $zabbixServer -s $zabbixHost -k veeam.backup.failed.today  -o $failed

#envia o status por job no zabbix, para cada JOB do veeam deve existe o job criado como item no zabbix para receber o status.
foreach ($job in $resultByJob.Keys) {
    $key = "veeam.job.status[$job]"
    $val = $resultByJob[$job]

    & "$zabbixSender" -z $zabbixServer -s $zabbixHost -k $key -o $val

    #Write-Output $key
    #Write-Output $val
}
