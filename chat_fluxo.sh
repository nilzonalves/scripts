#!/bin/bash

if [ -z "$1" ]; then
    read -p "Informe o protocolo: " protocolo_completo
else
    protocolo_completo="$1"
fi

var="${protocolo_completo:8}"

read -p "Informe o número de dias anteriores [data]: " dias
dias="${dias:-0}"  # Se vazio, assume 0

# Define o caminho do arquivo de log
if [[ "$dias" -eq 0 ]]; then
    log_file="/var/log/asterisk/ffpainel_chat.log"
elif [[ "$dias" -eq 1 ]]; then
    log_file="/var/log/asterisk/ffpainel_chat.log.1"
else
    log_file="/var/log/asterisk/ffpainel_chat.log.$dias.zst"
fi

if [ ! -f "$log_file" ]; then
    echo "Arquivo de log não encontrado: $log_file"
    exit 1
fi

# Define o comando correto (grep normal ou zstdcat)
case "$log_file" in
    *.zst) cmd="zstdcat \"$log_file\"" ;;
    *) cmd="cat \"$log_file\"" ;;
esac

# Processamento do log
eval "$cmd" | grep -iF "$var" | awk -v var="$var" '
    {
        # Captura a data e hora no início da linha
        if (match($0, /^\[([0-9]{2}\/[0-9]{2}\/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2})\]/, arr)) {
            data_hora = arr[1]
        }

        # Captura a hash após [CHAT] (formato esperado: [CHAT][67c8542a6e04c])
        if (match($0, /\[CHAT\]\[([a-f0-9]{12,16})\]/, hash_arr)) {
            hash = hash_arr[1]
        } else {
            hash = "SEM_HASH"  # Se não encontrar hash, coloca um marcador
        }

        # Filtra as linhas que contêm o padrão desejado e exibe a hash corretamente
        if ($0 ~ var) {
            if (match($0, /(Processando o contexto .*|Gerando a tomada de decisão .*|Tomada de decisão: .*|Processando o menu .*)/)) {
                print data_hora, hash, substr($0, RSTART, RLENGTH)
            }
        }
    }
' || echo "Nenhuma correspondência encontrada para: $var"
