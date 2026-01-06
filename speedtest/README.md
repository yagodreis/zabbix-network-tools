# Monitoramento de Velocidade de Internet (Multi-Link) para Zabbix

Este script automatiza a coleta de métricas de Download e Upload de múltiplos links de internet, tratando instabilidades comuns de rede e enviando os dados diretamente para o Zabbix via `zabbix_sender`.

### 🚀 Funcionalidades
- **Suporte Multi-IP:** Realiza o teste forçando a saída por interfaces/IPs específicos (`--source`).
- **Resiliência:** Implementa lógica de *Retry* (repetição) caso o teste falhe por oscilação do link.
- **Tratamento de Dados:** Utiliza `jq` e `awk` para conversão precisa de bits para Mbps com duas casas decimais.
- **Log Nativo:** Compatível com logs do Crontab para auditoria de falhas.

### 🛠 Pré-requisitos
- `speedtest-cli`
- `zabbix-sender`
- `jq` (Processador de JSON)

### 📋 Instalação e Uso
1. Clone o repositório.
2. Dê permissão de execução: `chmod +x speedtest_zabbix.sh`.
3. Configure as variáveis de IP e chaves do Zabbix no topo do script.
4. Adicione ao Crontab do Root para execuções agendadas.

### Obs.: Este script opera para realizar teste em dois links de internets destintos, isso foi realizado da seguinte forma
1 - No servidor linux VM adicione uma segunda interface de rede, pode trabalhar na mesma faixa de IP da primeira desde que seja IP diferentes.
2 - No firewall onde chega os 2 links, deve se fazer uma regra de roteamento em caso de firewall mais moderno pode se usar a tecnlogia SD-WAN caso não crie regras de encaminhamento fazendo com que o IP da porta 1 destine-se para o link 1 e o IP da porta 2 destine-se para o link 2
3 - No scrip nas linhas 73 e 74 ajuste os endereços de IP.
4 - Já no Zabbix precisa criar os itens conforme os links em questão.

---
**Analista de Redes e Segurança** *Focado em automação e monitoramento inteligente.*