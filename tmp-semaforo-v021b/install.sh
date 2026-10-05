#!/usr/bin/env bash
set -Eeuo pipefail

BASE="https://raw.githubusercontent.com/adrianfabianferrer05-dot/atlas-piloto/main/tmp-semaforo-v021b"
EXPECTED_SHA="a9a0ac702e5c3963974090375398f074b4d27a8344181672db7d87a96597ac77"

CID="$(docker ps --format '{{.ID}} {{.Image}}' | awk '$2 ~ /^gmag11\/metatrader5_vnc/ {print $1; exit}')"
if [ -z "$CID" ]; then
  echo "ERROR: no encuentro el contenedor gmag11/metatrader5_vnc en ejecucion."
  docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}'
  exit 20
fi

echo "[1/5] Contenedor MT5: $CID"

docker exec -u 0 "$CID" bash -lc "
set -Eeuo pipefail
TMP=/tmp/semaforo-v021b
DEST='/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Semaforo'
rm -rf \"\$TMP\"
mkdir -p \"\$TMP\" \"\$DEST\"
: > \"\$TMP/Semaforo_XAUUSD_MT5_v021b.mq5\"
for n in 01 02 03 04 05 06 07; do
  curl -fsSL '$BASE/part'\"\$n\"'.txt' >> \"\$TMP/Semaforo_XAUUSD_MT5_v021b.mq5\"
done
echo '$EXPECTED_SHA  '\"\$TMP/Semaforo_XAUUSD_MT5_v021b.mq5\" | sha256sum -c -
cp -f \"\$TMP/Semaforo_XAUUSD_MT5_v021b.mq5\" \"\$DEST/Semaforo_XAUUSD_MT5_v021b.mq5\"
chown -R abc:abc \"\$DEST\" 2>/dev/null || true
chmod 0644 \"\$DEST/Semaforo_XAUUSD_MT5_v021b.mq5\"
echo '[2/5] Fuente instalada en MQL5/Experts/Semaforo.'
"

echo "[3/5] Intentando compilar con MetaEditor..."
set +e
docker exec -u abc "$CID" bash -lc "
export WINEPREFIX=/config/.wine
export DISPLAY=${DISPLAY:-:1}
META='/config/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe'
SRC='/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Semaforo/Semaforo_XAUUSD_MT5_v021b.mq5'
if [ ! -f \"\$META\" ]; then
  echo 'NO_COMPILER: metaeditor64.exe no encontrado.'
  exit 30
fi
timeout 120s wine \"\$META\" /compile:\"C:\\Program Files\\MetaTrader 5\\MQL5\\Experts\\Semaforo\\Semaforo_XAUUSD_MT5_v021b.mq5\" /log
RC=\$?
sleep 3
EX5='/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Semaforo/Semaforo_XAUUSD_MT5_v021b.ex5'
if [ -f \"\$EX5\" ]; then
  echo 'COMPILE_OK'
  ls -lh \"\$EX5\"
  exit 0
fi
echo \"COMPILE_NO_EX5 rc=\$RC\"
find '/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Semaforo' -maxdepth 1 -type f -printf '%f %s bytes\n' 2>/dev/null
exit 31
"
COMPILE_RC=$?
set -e

echo "[4/5] Verificacion final..."
docker exec -u 0 "$CID" bash -lc "
SRC='/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Semaforo/Semaforo_XAUUSD_MT5_v021b.mq5'
EX5='/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Semaforo/Semaforo_XAUUSD_MT5_v021b.ex5'
sha256sum \"\$SRC\"
if [ -f \"\$EX5\" ]; then
  echo 'EX5_PRESENTE=SI'
else
  echo 'EX5_PRESENTE=NO'
fi
"

echo "[5/5] Terminado."
if [ "$COMPILE_RC" -eq 0 ]; then
  echo "RESULTADO: INSTALADO_Y_COMPILADO"
  echo "MODO_DEL_EA: solo senales por defecto (InpExecuteDemoOrders=false)."
  echo "SIGUIENTE: en MT5, abre XAUUSD, refresca Expert Advisors y arrastra Semaforo_XAUUSD_MT5_v021b al grafico."
else
  echo "RESULTADO: FUENTE_INSTALADA_PERO_COMPILACION_NO_VERIFICADA"
  echo "SIGUIENTE: abre IDE/MetaEditor y compila Semaforo_XAUUSD_MT5_v021b.mq5; no actives operaciones."
fi
