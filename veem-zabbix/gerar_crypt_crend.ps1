$caminhoArquivo = "C:\Script\VeeamZabbix\veeam_api_cred.xml"

# O comando abaixo abre a janela pedindo a senha do USER_AD_ADMIN primeiro, depois aguarde algum tempo, que ele vai solicitar o usuário e senha 
#que vai ser criptografado no XML esse é o usuário que você utiliza no veeam como consulta API.
Start-Process powershell.exe -Credential "DOMAIN\USER_AD_ADMIN -ArgumentList "-NoExit", "-Command", "& { Get-Credential | Export-Clixml -Path '$caminhoArquivo' }"