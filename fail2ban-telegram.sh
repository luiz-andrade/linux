#!/bin/bash

# ---------------------------
# 🚨 Bot notificação telegram FAIL2BAN
# ---------------------------
# Configuração Telegram
TOKEN=""
ID=""

# quebra de linha
NL="
"

ACAO="$1"   # "bloqueado" ou "desbloqueado"
JAIL="$2"   # Nome da regra (Ex: ufw-blocklist)
IP="$3"     # O IP afetado

# Define o emoji e o texto com base na ação
if [ "$ACAO" = "bloqueado" ]; then
    STATUS="🚨 <b>IP Bloqueado</b>"
    MOTIVO="após insistir em portas fechadas do UFW"
else
    STATUS="✅ <b>IP Desbloqueado</b>"
    MOTIVO="pois o tempo de punição expirou"
fi

## Buscar país, cidade e provedor do IP
GEO=$(curl -s "http://ip-api.com/json/$IP")
PAIS=$(echo "$GEO" | grep -oP '"country":"\K[^"]+')
CIDADE=$(echo "$GEO" | grep -oP '"city":"\K[^"]+')
ORG=$(echo "$GEO" | grep -oP '"org":"\K[^"]+')

[ -z "$PAIS" ] && PAIS="Não identificado"
[ -z "$CIDADE" ] && CIDADE="Não identificado"
[ -z "$ORG" ] && ORG="Não identificado"

DATA_ATUAL=$(date +'%d/%m/%Y %H:%M:%S')

MESSAGE="$STATUS ${NL}${NL}"
MESSAGE+="🔒 <b>Jail:</b> $JAIL${NL}"
MESSAGE+="💀 <b>IP Banido:</b> $IP${NL}"
MESSAGE+="🗺️ <b>Cidade/Pais:</b> $CIDADE/$PAIS${NL}"
MESSAGE+="🏢 <b>Provedor/Org:</b> $ORG${NL}"
MESSAGE+="🗓  <i>Data e Hora:</i> $DATA_ATUAL"

curl --silent -X POST \
    --data-urlencode "chat_id=$ID" \
    --data-urlencode "text=${MESSAGE}" \
    --data-urlencode "parse_mode=html" \
    "https://api.telegram.org/bot${TOKEN}/sendMessage" > /dev/null 2>&1