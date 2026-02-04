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
$cred = Import-Clixml "C:\Monitorar\Veeam Zabbix\veeam_api_cred.xml"

#Gera o token via POST ao veeam bakcup necessário toda vez que for realizar qualquer comando via API
#Dura em torno de 900sec
#Consulta o XML descriptografa a senha do usuário AD e fornece ao body para solicitar o Token
$body = "grant_type=password&username=$($cred.UserName)&password=$($cred.GetNetworkCredential().Password)"

$tokenResponse = Invoke-RestMethod -Method Post `
    -Uri "$veeamServer/api/oauth2/token" `
    -Body $body `
    -ContentType "application/x-www-form-urlencoded"

$accessToken = $tokenResponse.access_token

$headers = @{
    Authorization = "Bearer $token"
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

foreach ($item in $sessions.data) {

    $sessionDate = ([DateTime]::Parse($item.creationTime)).ToLocalTime().Date

    if ($sessionDate -eq $today) {

        $jobName = $item.name
        $status = $item.result.result

        switch ($status) {
            "Success" { $value = 1; $success++ }
            "Warning" { $value = 2; $warning++ }
            "Failed" { $value = 3; $failed++ }
            default { $value = 0 }
        }

        # Se rodar mais de uma vez no dia, prioriza o pior status
        #Caso exista alguma valor já atualiza para o pior status
        if ($resultByJob.ContainsKey($jobName)) {
            if ($value -gt $resultByJob[$jobName]) {
                $resultByJob[$jobName] = $value
            }
        }
        #se não seta o pior status
        else {
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
}

Write-Output "Envio para Zabbix concluído com sucesso!"
