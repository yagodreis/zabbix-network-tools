#!/bin/bash

# Define os caminhos de busca para o script
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# --- Configuracoes Zabbix ---
ZABBIX_SERVER="[IP DO SEU SERVIDOR ZABBIX]"
ZABBIX_HOST="Velocidade Links"
ZABBIX_SENDER_PATH="/usr/bin/zabbix_sender"
ZABBIX_SPEEDTEST="/usr/local/bin/speedtest-cli"

# --- Configurcoes de Retry (Repeticoes) ---
MAX_RETRIES=5       # Tenta ate 5 vezes se falhar
SLEEP_TIME=30       # Aguarda 30 segundos entre as tentativas]

# --- Funcoes ---
status() {
    echo -e "\n\e[1m>>> $1 <<<\e[0m"
}

send_to_zabbix() {
    local source_ip=$1
    local zabbix_key_download=$2
    local zabbix_key_upload=$3
    local attempt=1
    local success=false

    status "Iniciando teste de velocidade para o Link com IP: $source_ip"

    while [ $attempt -le $MAX_RETRIES ]; do
        echo "Tentativa $attempt de $MAX_RETRIES..."

        # Executa o speedtest e captura a saida
        TEST_RESULT=$("$ZABBIX_SPEEDTEST" --source "$source_ip" --json 2>/dev/null)

        if [ -n "$TEST_RESULT" ]; then
            DOWNLOAD_MBPS=$(echo "$TEST_RESULT" | jq -r '.download // empty' | awk '{printf "%.2f", $1 / 1000000}' 2>/dev/null)
            UPLOAD_MBPS=$(echo "$TEST_RESULT" | jq -r '.upload // empty' | awk '{printf "%.2f", $1 / 1000000}' 2>/dev/null)

            # Verifica se os valores sao numericos e nao vazios
            if [[ -n "$DOWNLOAD_MBPS" && -n "$UPLOAD_MBPS" ]]; then
                echo "Sucesso! Download: $DOWNLOAD_MBPS Mbps | Upload: $UPLOAD_MBPS Mbps"
                
                # Envia para o Zabbix
                "$ZABBIX_SENDER_PATH" -c /etc/zabbix/zabbix_agent2.conf -s "$ZABBIX_HOST" -k "$zabbix_key_download" -o "$DOWNLOAD_MBPS"
                "$ZABBIX_SENDER_PATH" -c /etc/zabbix/zabbix_agent2.conf -s "$ZABBIX_HOST" -k "$zabbix_key_upload" -o "$UPLOAD_MBPS"
                
                success=true
                break # Sai do loop while
            fi
        fi

        echo "Erro na tentativa $attempt. O link pode estar instavel."
        ((attempt++))
        [ $attempt -le $MAX_RETRIES ] && sleep $SLEEP_TIME
    done

    if [ "$success" = false ]; then
        echo "Falha critica: Nao foi possivel realizar o teste apos $MAX_RETRIES tentativas para o IP $source_ip."
        return 1
    fi
}

# --- Verificacao de Requisito ---
if ! command -v jq &> /dev/null; then
    echo "Erro: O utilitario 'jq' nao foi encontrado. Instale-o com: sudo apt install jq"
    exit 1
fi

# --- Execucao dos Testes ---

#IP DAS PLACAS DE REDE EM CASO DE DOIS LINKS DE INTERNET
IP_LINK1="IP ETH0"
IP_LINK2="IP ETH1"

send_to_zabbix "$IP_LINK1" "link1.speedtest.download" "link1.speedtest.upload"
send_to_zabbix "$IP_LINK2" "link2.speedtest.download" "link2.speedtest.upload"

status "Processo finalizado."