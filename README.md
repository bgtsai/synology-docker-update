[切換中文](README.zh-TW.md)

# synology-docker-update

One-click update of a specific Docker container on a Synology NAS from Task Scheduler: [Watchtower](https://github.com/containrrr/watchtower) updates just that one container — pull, recreate only if the image changed, remove the old image, stopped containers included. One script shared by every container, nothing to configure.

## Naming convention

| Item | Format | Example |
|---|---|---|
| Compose project folder | `/volume1/docker/compose/compose_<name>` | `compose_calibre-web-foliate` |
| Container name | `<number>_<name>` | `11_calibre-web-foliate` |

The script lives in the project folder, takes `<name>` from the folder name and finds the container `<number>_<name>` by itself — you don't need to know the number.

## Setup (once per container)

DSM "Control Panel → Task Scheduler → Create → Scheduled Task → User-defined script":

- General tab: set the user to **root** (Docker needs it)
- Schedule: it doesn't need to run regularly; set it rarely and press "Run" when you want to update
- Task Settings: put only this line in the command box, replacing `<name>` with the container's name:

```
F=/volume1/docker/compose/compose_<name>/nas-update.sh; OK=0; curl -fsSL -o "$F.new" https://raw.githubusercontent.com/bgtsai/synology-docker-update/main/nas-update.sh && head -1 "$F.new" | grep -q '^#!/bin/bash' && bash -n "$F.new" && mv "$F.new" "$F" && OK=1; rm -f "$F.new"; FRESH=$OK bash "$F"
```

For example, `11_calibre-web-foliate`:

```
F=/volume1/docker/compose/compose_calibre-web-foliate/nas-update.sh; OK=0; curl -fsSL -o "$F.new" https://raw.githubusercontent.com/bgtsai/synology-docker-update/main/nas-update.sh && head -1 "$F.new" | grep -q '^#!/bin/bash' && bash -n "$F.new" && mv "$F.new" "$F" && OK=1; rm -f "$F.new"; FRESH=$OK bash "$F"
```

> [!IMPORTANT]
> Put only this line in the command box, not the whole script: Task Scheduler silently drops command-box content that is too long when you save.

## What a run does

1. Downloads the latest `nas-update.sh` from GitHub and replaces the copy in the folder only if it really is the script (first line `#!/bin/bash`, valid syntax); if the download fails or looks wrong, the existing copy runs. The first run puts the script into the folder for you
2. Finds the container: exactly one match → Watchtower updates it; nothing changes if it is already up to date
3. Writes the result to `nas-update.log` in the same folder
4. Sends a DSM notification at every stage: checking started → container found, pulling the new image → updated / already up to date; any error is notified too. If this run could not download the latest script (and ran the existing copy), an extra "download failed" notification comes first — this relies on `FRESH=$OK` in the command; older commands without it skip this check. Notifications appear in DSM's top-right Messages under the "System" category, starting with "Docker 更新 <name>："; stages are "Info", errors are "Critical" (red)

## When the container isn't found

**The script never creates a container or project.** Compose projects created from the command line are not listed under Container Manager's Projects, so new installs are always created in Container Manager ("Project → Create") from the folder's `compose.yaml`.

If no container matches, or several do, it will:

- write the reason and what to do to `nas-update.log`
- make Task Scheduler show the run as failed
- show a DSM notification (when DSM's built-in notify command exists; skipped otherwise)

## Containers that don't follow the convention

Set the container name before the final `bash`: `... ; CONTAINER=actual-name bash "$F"`. Don't edit settings inside the script file — the next run replaces it with the latest version.

## Notes

- Every run executes whatever the script on GitHub currently is, as root
- Watchtower recreates the container by copying the existing container's settings, not by reading `compose.yaml`; if you change `compose.yaml` (e.g. environment variables), recreate the project in Container Manager
- `Scanned=1 Updated=0` in the log means the container was found and is already up to date; `Updated=1` means it was updated. The `404 Not Found` warning at the start is Watchtower's lightweight check being refused; it falls back to a normal pull and is harmless

## Tests

`bash test/run.sh`: runs every case against a fake docker command (found, not found, several found, prefix-only match, `CONTAINER=`, names containing `.`) without touching real Docker.

## License

MIT
