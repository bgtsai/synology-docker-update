#!/bin/bash
# Synology Docker 容器一鍵更新（工作排程器用，使用者選 root）
# 放在 compose 專案資料夾 compose_<名稱>/ 裡，自動找「數字_<名稱>」的容器，交給 Watchtower 只更新這一個。
# 不會建立容器或專案：找不到就提示到 Container Manager 建立（指令列建的專案 Container Manager 不認得）。
# 用法：排程指令欄放 README（https://github.com/bgtsai/synology-docker-update）裡那一行——每次先抓 GitHub 最新版、檢查過才替換再執行，抓不到就跑現有這份。
# 不照命名規則的容器：在指令前指定 CONTAINER=實際名稱。設定不要改在這個檔案裡（下次會被最新版覆蓋）。
# 排程指令會帶 FRESH=1（這次下載到最新版）或 FRESH=0（下載失敗，跑的是 NAS 上現有這份）；舊版指令不帶，就不判斷。
# 每個階段都送 DSM 通知：開始 → 找到容器、開始抓映像 → 已更新／已是最新版；任何一步出錯也通知。

DIR="${DIR:-$(cd "$(dirname "$0")" && pwd)}"
LOG="${LOG:-$DIR/nas-update.log}"
NAME="$(basename "$DIR")"; NAME="${NAME#compose_}"

exec > "$LOG" 2>&1                    # 排程沒有畫面，全部輸出寫進 log
echo "== $(TZ=Asia/Taipei date '+%F %T')"

N="${SYNONOTIFY:-/usr/syno/bin/synodsmnotify}"   # 測試時換成假的指令
# DSM 7 的 synodsmnotify 不收自訂文字（標題要是系統郵件字串代碼、內容要是 JSON，否則報
# "is neither mail string key nor i18n format"）。DSM 內建兩個整句都是 %CUSTOM_MSG% 的代碼，
# 拿來送自訂文字：DSMSupportFormCustomMessage＝資訊、DSMSupportFormCustomFailure＝重大（紅）。
# 類別固定顯示「系統」、沒有獨立標題，所以句子開頭帶容器名稱；系統會在句尾自動加「。」。
# 2026-10-28 在 DSM 7.4.1 實測；這兩個代碼若被改版拿掉，log 會出現上面那句錯誤，更新本身不受影響。
send() {                              # send <代碼> <訊息>
    [ -x "$N" ] || return 0
    local m="Docker 更新 $NAME：$2"
    m="${m//\\/\\\\}"; m="${m//\"/\\\"}"   # JSON 字串跳脫：\ 與 "
    "$N" @administrators "$1" "{\"%CUSTOM_MSG%\":\"$m\"}"
}
info() {                              # 階段通知：log＋DSM 通知（資訊），不結束
    echo "$1"
    send DSMSupportFormCustomMessage "$1"
}
notify() {                            # 出錯：log＋DSM 通知（重大）＋失敗結束碼
    echo "$1"; [ -n "$2" ] && echo "$2"; echo "${3:-沒有做任何變更}"
    send DSMSupportFormCustomFailure "$1${2:+ $2}"
    exit 1
}

[ "${FRESH:-}" = 0 ] && info "下載最新腳本失敗，改用 NAS 上現有版本執行"
info "開始執行更新，檢查容器中"

DOCKER=""
for p in /usr/local/bin/docker /usr/bin/docker; do [ -x "$p" ] && DOCKER="$p" && break; done
[ -z "$DOCKER" ] && notify "找不到 docker 指令"
echo "docker: $DOCKER"

if [ -z "$CONTAINER" ]; then
    # 比對「數字_<名稱>」：名稱用字串完全相等比，不用正規表示式（名稱裡的 . 之類才不會變成萬用字元）
    mapfile -t HITS < <("$DOCKER" ps -a --format '{{.Names}}' | awk -v n="$NAME" '{ s = $0; if (sub(/^[0-9]+_/, "", s) && s == n) print }')
    if [ "${#HITS[@]}" -eq 0 ]; then
        notify "找不到符合「數字_${NAME}」的容器" \
            "→ 請到 Container Manager「專案 → 新增」，路徑選 ${DIR#/volume1}，用裡面的 compose.yaml 建立專案"
    elif [ "${#HITS[@]}" -gt 1 ]; then
        notify "找到多個：${HITS[*]}" "→ 請刪掉不用的那個，或在指令前用 CONTAINER= 指定"
    fi
    CONTAINER="${HITS[0]}"
elif [ -z "$("$DOCKER" ps -a -q -f "name=^${CONTAINER}$")" ]; then
    notify "找不到容器 $CONTAINER" "→ 請到 Container Manager 用 ${DIR#/volume1} 的 compose.yaml 建立專案"
fi

info "找到容器 $CONTAINER，開始抓取新映像（Watchtower）"
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
"$DOCKER" run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower \
    --run-once --cleanup --include-stopped "$CONTAINER" 2>&1 | tee "$OUT"
rc=${PIPESTATUS[0]}; echo "Watchtower 結束碼 $rc"
# 結果看 Watchtower 最後的摘要行：Session done Failed=0 Scanned=1 Updated=1 …
SUM="$(grep -o 'Failed=[0-9]* Scanned=[0-9]* Updated=[0-9]*' "$OUT" | tail -1)"
FAILED="$(echo "$SUM" | sed -n 's/.*Failed=\([0-9]*\).*/\1/p')"
UPDATED="$(echo "$SUM" | sed -n 's/.*Updated=\([0-9]*\).*/\1/p')"
if [ "$rc" != 0 ] || [ -z "$SUM" ] || [ "$FAILED" != 0 ]; then
    notify "更新失敗（Watchtower 結束碼 $rc${SUM:+，$SUM}）" "→ 請看 ${LOG#/volume1}" "容器可能沒有更新"
elif [ "$UPDATED" -gt 0 ]; then
    info "已更新完成：$CONTAINER"
else
    info "已是最新版，沒有變更：$CONTAINER"
fi
exit 0
