# ServerJockey LXC for Proxmox — one-command game-server panel

Spin up a Proxmox LXC running [ServerJockey](https://serverjockey.net/) — a web
panel (and optional Discord bot) for creating, launching, configuring, and
modding multiple game servers, **Project Zomboid and others**, all from one
browser UI. One pasted command, then everything else happens in the panel.

## Usage

Paste into the **Proxmox node shell** (as root):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/blake165/project-zomboid-launcher/main/proxmox-create-serverjockey-lxc.sh | sed 's|serverjockey-lxc-creator|project-zomboid-launcher|')"
```

The wizard asks for container settings, then:

- downloads the Debian 12 LXC template (if missing)
- creates + starts an unprivileged container (autostart on boot)
- installs SteamCMD (via the Debian non-free apt package — the reliable way)
- installs ServerJockey from its official `.deb`, which auto-creates its own
  systemd service and runs the webapp on port `6164`
- prints the panel URL and login token when done

## After install

1. Open `http://<container-ip>:6164`
2. Get your login token:
   ```bash
   pct exec <CTID> -- serverjockey_cmd.pyz -nc showtoken
   ```
3. Log in, then **create a game server** (Project Zomboid, etc.) → configure →
   deploy. ServerJockey handles the SteamCMD download, config files, mods, and
   live console for each server you create — no per-game install scripts.

## Why ServerJockey instead of per-game scripts

One panel manages many servers and many games. Instead of maintaining a
separate installer + systemd service + config-editing workflow for each game,
ServerJockey gives you create/start/stop/configure/mod/console for all of them
in a browser. For Project Zomboid specifically it covers launching servers,
editing `server.ini` and sandbox vars, and managing mods through the UI.

## Settings the wizard sets

| Prompt | Default | Notes |
|---|---|---|
| Container ID | `160` | unused (FiveM 110, MC 130, PZ 140, Necesse 150) |
| Hostname | `serverjockey` | |
| CPU cores | `4` | it runs the game servers too — give it room |
| Memory | `12288` MB | sized to host multiple game servers |
| Disk | `80` GB | all game-server files live here — size generously |
| Network | `dhcp` | or static `IP/CIDR` + gateway |
| Container root password | — | prompted, hidden |
| SSH root login | `yes` | |
| Panel port | `6164` | ServerJockey's webapp port |

### Scripted install

```bash
NONINTERACTIVE=1 CTID=161 MEMORY=16384 DISK_GB=120 \
CT_ROOT_PASSWORD='root-pass' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/blake165/serverjockey-lxc-creator/main/proxmox-create-serverjockey-lxc.sh)"
```

## Ports & security

- **Panel `6164`** — keep this **LAN-only or behind your VPN**. It controls game
  servers; do not port-forward it to the internet.
- **Game servers** — forward each one's ports as you create them, e.g. Project
  Zomboid `16261-16262/udp`. The panel tells you each server's ports.
- Set a DHCP reservation (or static IP) so the container address stays put.

## Updating

Re-run the setup script in the container to pull the latest ServerJockey `.deb`:

```bash
pct exec <CTID> -- bash /root/serverjockey-lxc-setup.sh
```

## Notes

- Container is unprivileged with `nesting=1` and `onboot=1`.
- SteamCMD is installed from Debian's `contrib/non-free` apt package, which
  avoids the permission problems the raw Valve tarball causes in LXC containers.
- ServerJockey supports several games beyond Project Zomboid — check the panel's
  options once you're in.
