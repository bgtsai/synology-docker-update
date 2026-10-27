# CLAUDE.md — synology-docker-update

給 Claude 看的。互動原則另見 `bgtsai/claude-knowledge-base` 的 `01_與我互動的原則.html`；流程紀錄在知識庫 14 號。

- `nas-update.sh` 是**所有容器共用**的一份，裡面不能寫任何特定容器的資訊；容器從所在資料夾 `compose_<名稱>` 推出來，例外用指令前的 `CONTAINER=`。
- NAS 每次執行都會抓 main 上最新的 `nas-update.sh` 直接以 root 執行——推送等於立即發布到使用者所有容器，推送前一定跑 `bash test/run.sh`（全部通過）、`bash -n`、`shellcheck -S warning`。
- DSM 7 的 `synodsmnotify` 不收自訂文字（標題要系統郵件字串代碼、內容要 JSON）：用 `DSMSupportFormCustomMessage`／`DSMSupportFormCustomFailure` 帶 `{"%CUSTOM_MSG%":"…"}` 送自訂文字（2026-10-28 DSM 7.4.1 實測，細節見腳本註解與知識庫 14 號）。測試的假通知指令照同樣規矩檢查。
- 不建立容器或專案（指令列建的 compose 專案 Container Manager 不認得），找不到只提示。
- 新功能先加測試案例到 `test/run.sh`，並用改壞的腳本反證測試抓得到。
- README.md（英文）與 README.zh-TW.md（繁中）逐段對應，改一份要改另一份。
