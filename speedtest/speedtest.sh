#!/bin/bash

# Define os caminhos de busca para o script, caminhos absolutos do PATCH para evitar falha na chamada.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

# --- Configuracoes Zabbix ---
ZABBIX_SERVER="192.168.0.73"
ZABBIX_HOST="Velocidade Links"
ZABBIX_SENDER_PATH="/usr/bin/zabbix_sender"
ZABBIX_SPEEDTEST="/usr/local/bin/speedtest-cli"

# Defini os valores para tentativas evitando o travamento do contrab
MAX_RETRIES=5       # Tenta ate 5 vezes se falhar
SLEEP_TIME=30       # Aguarda 30 segundos entre as tentativas

# Função para impressão dos logs em /var/log
status() {
    echo -e "\n\e[1m>>> $1 <<<\e[0m"
}

send_to_zabbix() {
    #variaveis locais que são recebidas na chama do script
    local source_ip=$1
    local zabbix_key_download=$2
    local zabbix_key_upload=$3
    local attempt=1
    local success=false
    
    status "Iniciando teste de velocidade para o Link com IP: $source_ip"
    
    #repetição responsável por controlar quantas vezes testar antes de finalizar.
    while [ $attempt -le $MAX_RETRIES ]; do
        echo "Tentativa $attempt de $MAX_RETRIES..."

        # Executamos o teste capturando TUDO (saída e erro)
        # Adicionamos o --secure para evitar erros de certificados SSL no Cron
        RAW_OUT=$("$ZABBIX_SPEEDTEST" --source "$source_ip" --json --secure 2>&1)

        # Filtramos a saída para pegar APENAS o que parece um JSON (começa com { e termina com })
        TEST_RESULT=$(echo "$RAW_OUT" | grep -o '{.*}' | tail -n 1)

        if [ -z "$TEST_RESULT" ]; then
            echo "Erro: Saída não contém JSON válido. O que foi recebido: $RAW_OUT"
        else
            # extrair os valores apenas se o JSON for válido
            DOWNLOAD_RAW=$(echo "$TEST_RESULT" | jq -r '.download // empty' 2>/dev/null)
            UPLOAD_RAW=$(echo "$TEST_RESULT" | jq -r '.upload // empty' 2>/dev/null)

            if [[ -n "$DOWNLOAD_RAW" && "$DOWNLOAD_RAW" =~ ^[0-9.]+$ ]]; then
                DOWNLOAD_MBPS=$(awk "BEGIN {printf \"%.2f\", $DOWNLOAD_RAW / 1000000}")
                UPLOAD_MBPS=$(awk "BEGIN {printf \"%.2f\", $UPLOAD_RAW / 1000000}")

                echo "Sucesso! Download: $DOWNLOAD_MBPS Mbps | Upload: $UPLOAD_MBPS Mbps"
                
                "$ZABBIX_SENDER_PATH" -c /etc/zabbix/zabbix_agent2.conf -s "$ZABBIX_HOST" -k "$zabbix_key_download" -o "$DOWNLOAD_MBPS"
                "$ZABBIX_SENDER_PATH" -c /etc/zabbix/zabbix_agent2.conf -s "$ZABBIX_HOST" -k "$zabbix_key_upload" -o "$UPLOAD_MBPS"
                
                success=true
                break
            else
                echo "Erro: Valores de download/upload inválidos no JSON."
            fi
        fi

        echo "Aguardando para reprocessar..."
        ((attempt++))
        [ $attempt -le $MAX_RETRIES ] && sleep $SLEEP_TIME
    done
    
    if [ "$success" = false ]; then
        echo "Falha critica: Nao foi possivel realizar o teste apos $MAX_RETRIES tentativas para o IP $source_ip."
        return 1
    fi
}

# Verificacao de Requisito
if ! command -v jq &> /dev/null; then
    echo "Erro: O utilitario 'jq' nao foi encontrado. Instale-o com: sudo apt install jq"
    exit 1
fi

# Execucao dos Testes
IP_LINK1="192.168.0.73"
IP_LINK2="192.168.0.74"

send_to_zabbix "$IP_LINK1" "link1.speedtest.download" "link1.speedtest.upload"
send_to_zabbix "$IP_LINK2" "link2.speedtest.download" "link2.speedtest.upload"

status "Processo finalizado."