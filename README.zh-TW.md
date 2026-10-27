[Switch to English](README.md)

# synology-docker-update

在 Synology NAS 上用工作排程器一鍵更新指定的 Docker 容器：用 [Watchtower](https://github.com/containrrr/watchtower) 只更新這一個容器——拉新映像、有變才重建、清掉舊映像，停止中的容器也處理。同一支腳本給所有容器共用，不用填任何設定。

## 命名規則

| 項目 | 格式 | 例子 |
|---|---|---|
| compose 專案資料夾 | `/volume1/docker/compose/compose_<名稱>` | `compose_calibre-web-foliate` |
| 容器名稱 | `<流水號>_<名稱>` | `11_calibre-web-foliate` |

腳本放在專案資料夾裡，從資料夾名稱取出 `<名稱>`，自動找到 `數字_<名稱>` 的容器，流水號不用知道。

## 設定（每個容器一次）

DSM「控制台 → 工作排程器 → 新增 → 排定的任務 → 使用者定義的指令碼」：

- 「一般」分頁：使用者選 **root**（Docker 需要）
- 「排程」：平常不用跑，可以設成很少執行；要更新時按「執行」
- 「任務設定」的指令欄只放這一行，把 `<名稱>` 換成那個容器的名稱：

```
F=/volume1/docker/compose/compose_<名稱>/nas-update.sh; curl -fsSL -o "$F.new" https://raw.githubusercontent.com/bgtsai/synology-docker-update/main/nas-update.sh && head -1 "$F.new" | grep -q '^#!/bin/bash' && bash -n "$F.new" && mv "$F.new" "$F"; rm -f "$F.new"; bash "$F"
```

例如 `11_calibre-web-foliate`：

```
F=/volume1/docker/compose/compose_calibre-web-foliate/nas-update.sh; curl -fsSL -o "$F.new" https://raw.githubusercontent.com/bgtsai/synology-docker-update/main/nas-update.sh && head -1 "$F.new" | grep -q '^#!/bin/bash' && bash -n "$F.new" && mv "$F.new" "$F"; rm -f "$F.new"; bash "$F"
```

> [!IMPORTANT]
> 指令欄只放這一行，不要把整支腳本貼進去：工作排程器的指令欄內容太長時，存檔後會整段消失。

## 執行時做什麼

1. 從 GitHub 下載最新版 `nas-update.sh`，確認是腳本（第一行 `#!/bin/bash`、語法正確）才替換資料夾裡那份；下載失敗或內容不對，就照跑現有那份。第一次執行會自動把腳本放進資料夾
2. 找容器：剛好找到一個 → 交給 Watchtower 更新；已經是最新版就什麼都不動
3. 結果寫在同資料夾的 `nas-update.log`

## 找不到容器時

**腳本不會建立容器或專案。** 從指令列建立的 compose 專案，Container Manager 不會把它列在「專案」裡，所以新裝一律在 Container Manager「專案 → 新增」用資料夾裡的 `compose.yaml` 建立。

找不到容器、或找到多個同名容器時，會同時：

- 在 `nas-update.log` 寫原因和該怎麼做
- 讓工作排程器顯示這次執行失敗
- 在 DSM 右上角跳通知（DSM 內建的通知指令存在時；不存在就略過）

## 不照命名規則的容器

在指令最後的 `bash` 前面指定容器名稱：`... ; CONTAINER=實際名稱 bash "$F"`。設定不要改在腳本檔裡——下次執行會被最新版覆蓋。

## 注意

- 每次執行都會以 root 跑 GitHub 上當下的腳本內容
- Watchtower 重建容器時是照抄現有容器的設定，不讀 `compose.yaml`；改了 `compose.yaml`（例如環境變數）要在 Container Manager 重建專案
- log 裡 `Scanned=1 Updated=0` 表示找到容器、已是最新版；`Updated=1` 表示更新了。開頭的 `404 Not Found` 警告是 Watchtower 先試的輕量查詢被拒絕，會自動改用一般下載，無害

## 測試

`bash test/run.sh`：用假的 docker 指令跑每種情況（找到、找不到、找到多個、名稱只有前綴相同、指定 `CONTAINER=`、名稱含 `.`），不碰真的 Docker。

## 授權

MIT
