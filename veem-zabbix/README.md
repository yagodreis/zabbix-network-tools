# Monitoramento dos status dos JOBS de Backup do Veeam Backup & Replication

Esse script automatiza a coleta de status de JOBS importantes de backup do Veeam através de API protegida por token, com ele
é possível saber quantos Backups rodou com Sucesso, Avisou ou Falha e também com um pouco de trabalho é possível juntamente do Zabbix e Grafana não só contar mais monitorar o status individual de cada JOBS, para isso ainda é exigido trabalho manual. Todos os valores são enviados por `Zabbix Sender`

### 🚀 Funcionalidades
**Coleta quantitativa por Status:** Percorre todos os JOBS ativos verificando seu status e somando conforme Sucesso, Aviso ou Falha, criando uma pontuação importante para o monitoramento ativo.
**Coleta de status por JOB:** Coleta o Status indivual de cada JOB enviando a informação para o Zabbix podendo ser acompanhado no grafana o status atual do dia referente a cada JOB.
**Usuário e Senha de Geração de Token Criptografada em arquivo:** Para o não armazenamento de senha em texto puro, o script `gerar_crypt_crend.ps1` consegue utilizar o usuário do Active Directory para armazenar a senha criptografa em um aqruivo .xml e ser solicitada pelo script de status quando necessário, sem a necessidade de transitar a senha em texto puro.

### 🛠 Pré-requisitos
- `powershell`
- `zabbix-sender`
- `Active Directory`
- `Windows Server >= 2016 `

### 📋 Instalação e Uso
1. Clone o repositório em C:\Script\VeeamZabbix\ a modo dos arquivos ficarem exatamente neste caminho.
2. Crie o Usuário no Active Directory para consultar a API do Veeam, por exemplo `api.veeam` coloque apenas permissão de `Usuário do dominio` coloque uma senha forte.
3. Acesse o painel do Veeam Backup vá para `Users and Roles` adicione o usuário do domain criado no passo 2 com a permissão `Veeam Backup Viewer`.
4. No navegador acesse `https://SEU_SERVER_VEEAM:9419/swagger` e verifique se a API está acessível.
5. Abra `Windows PowerShell ISE` como Administrador dentro do servidor do Veeam, abra o script C:\Script\VeeamZabbix\gerar_crypt_crend.ps1 e o execute, de cara ele vai pedir o usuário que vai ser utilizado para rodar o script de criptografia, `esse usuário precisa ser exatamente o mesmo que vai rodar o script através da (Task Scheduler) do Windows, ele precisa ser Administrador pois o script contem comando de rede que dependem de ser administrador` após colocar e apertar enter, depois de alguns segundos ele vai pedir novamente o usuário `esse usuário é o usuário que você criou no passo 2 e configurou no passo 3 ele vai ser utilizado na API`, após isso o arquivo com sua senha criptografada surge em `C:\Script\VeeamZabbix\veeam_api_cred.xml`
6. No zabbix é necessário criar os seguinte itens dentro do seu host, o host precisa ser o mesmo do Veeam já que está usando o agente instalado para fazer o sender:
- Nome: Success Status Veeam Job | Tipo: Zabbix trapper | Chave: veeam.backup.success.today
- Nome: Warning Status Veeam Job | Tipo: Zabbix trapper | Chave: veeam.backup.warning.today
- Nome: Failled Status Veeam Job | Tipo: Zabbix trapper | Chave: veeam.backup.failed.today
7. Enfim, quando o script rodar já é possível receber o quantitativo de status referentes, caso queira monitorar o status por JOB é necessário criar um item para cada JOB no zabbix usando o nome real do JOB dentro do Veeam, não garantimos que o nome com caracters especiais possa quebrar o script... Exemplo do item de Job no Zabbix:
- Nome: A - BACKUP SERVIDOR-ARQUIVOS | Tipo: Zabbix trapper | Chave: veeam.job.status[A - BACKUP SERVIDOR-ARQUIVOS]
8. Todos os tipos de Item no Zabbix devem ser com a informação Numérico (inteiro sem sinal).

### Sugestão de automação usando Task Scheduler
- Acesse o Task Scheduler do Windows, add uma nova Task, em Geral o usuário que vai rodar deve ser um com permissão administrador e o mesmo usuário que utilizou no passo 5 para criar o arquivo de criptografia, marque a opção rodar com o usuário logado ou não. Em ações Gatilhos tente usar o gatilho de tempo, equilibrando entre o começo e fim das suas tarefas, por exemplo: todos os dias a cada 30 minutos. Em Ações requer mais atenção para executar scripts PowerShell é necessário colocar em Progama/Script o seguinte: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` já em Argumentos colocar: `-ExecutionPolicy Bypass -File "C:\Script\VeeamZabbix\veeam_api_health.ps1"` o resto das configurações é intuitivo e pessoal de cada ambiente.

**Analista de Redes e Segurança** *Focado em automação e monitoramento inteligente.*