#!/bin/bash
# 回歸測試：用假的 docker 指令跑 nas-update.sh 的每種情況，只檢查它「會下什麼指令、結束碼、log」，不碰真的 Docker。
# 用法：bash test/run.sh   （全部通過時結束碼 0）
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/docker" <<'STUB'
#!/bin/bash
echo "docker $*" >> "$CALLS"
if [ "$1" = ps ]; then
    if [[ "$*" == *--format* ]]; then printf '%s\n' $NAMES
    else for n in $NAMES; do [[ "$*" == *"^$n\$"* ]] && echo id; done; fi
fi
exit 0
STUB
chmod +x "$T/bin/docker"
pass=0; fail=0
# case <資料夾名稱> <現有容器（空白分隔）> <環境變數或 -> <預期結束碼> <預期 log 片段> <預期最後一個 docker 指令片段>
case_() {
    local d="$T/volume1/docker/compose/$1"; mkdir -p "$d"
    sed "s#for p in /usr/local/bin/docker /usr/bin/docker#for p in $T/bin/docker#" "$ROOT/nas-update.sh" > "$d/nas-update.sh"
    : > "$T/calls"
    if [ "$3" = - ]; then CALLS="$T/calls" NAMES="$2" bash "$d/nas-update.sh"; else env CALLS="$T/calls" NAMES="$2" "$3" bash "$d/nas-update.sh"; fi
    local rc=$? log; log="$(cat "$d/nas-update.log")"
    if [ "$rc" = "$4" ] && [[ "$log" == *"$5"* ]] && [[ "$(tail -1 "$T/calls")" == *"$6"* ]]; then
        pass=$((pass+1)); echo "OK   $1 | $2 | $3"
    else
        fail=$((fail+1)); echo "FAIL $1 | $2 | $3 → rc=$rc"; echo "$log" | sed 's/^/     /'; tail -1 "$T/calls" | sed 's/^/     最後指令：/'
    fi
}
case_ compose_calibre-web-foliate "11_calibre-web-foliate 09_huginn" - 0 "Watchtower 更新" "--include-stopped 11_calibre-web-foliate"
case_ compose_calibre-web-foliate "09_huginn"                        - 1 "找不到符合「數字_calibre-web-foliate」" "ps -a --format"
case_ compose_calibre-web-foliate "11_calibre-web-foliate 12_calibre-web-foliate" - 1 "找到多個" "ps -a --format"
case_ compose_calibre-web-foliate "11_calibre-web-foliate-old 11_calibre-web-foliate" - 0 "容器 11_calibre-web-foliate →" "--include-stopped 11_calibre-web-foliate"
case_ compose_calibre-web-foliate "my-cwf"  CONTAINER=my-cwf 0 "容器 my-cwf →" "--include-stopped my-cwf"
case_ compose_calibre-web-foliate "09_huginn" CONTAINER=nope 1 "找不到容器 nope" "name=^nope$"
case_ compose_a.b "11_a.b" - 0 "容器 11_a.b →" "--include-stopped 11_a.b"
case_ compose_a.b "11_axb" - 1 "找不到符合「數字_a.b」" "ps -a --format"
echo "通過 $pass，失敗 $fail"; [ "$fail" = 0 ]
