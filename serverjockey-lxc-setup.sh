#!/usr/bin/env bash
###############################################################################
# ServerJockey setup for a Proxmox LXC container
#
# Runs INSIDE the container as root. Normally invoked by
# proxmox-create-serverjockey-lxc.sh, but safe to re-run to repair/update:
#   bash /root/serverjockey-lxc-setup.sh
#
# ServerJockey is a web panel + Discord bot for managing game servers
# (Project Zomboid and others). It installs SteamCMD and the sjgms .deb,
# auto-creates its own systemd service, and runs the webapp on port 6164.
#
# Once installed, you create/launch/configure game servers and manage mods
# entirely from the ServerJockey web UI - no per-game install scripts needed.
###############################################################################
set -euo pipefail

SJ_PORT="${SJ_PORT:-6164}"   # ServerJockey webapp port (informational; sj uses 6164)
DEB_URL="https://dl.serverjockey.net/sjgms-master-latest.deb"

if [[ $EUID -ne 0 ]]; then echo "Please run as root." >&2; exit 1; fi

echo "==> Installing base dependencies..."
export DEBIAN_FRONTEND=noninteractive
dpkg --add-architecture i386
apt-get update -qq
apt-get install -y -qq locales curl wget ca-certificates software-properties-common \
  python3 unzip >/dev/null
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- SteamCMD via apt (the Debian-correct way; avoids tarball perm issues) ---
echo "==> Enabling non-free repo and installing SteamCMD..."
# Add contrib/non-free across whatever apt source format is present
if [[ -f /etc/apt/sources.list ]] && grep -q '^deb ' /etc/apt/sources.list; then
  # classic format - handle 'main', 'main contrib', etc. by ensuring both comps
  sed -i -E '/^deb .*debian/ { /non-free/! s/$/ contrib non-free non-free-firmware/ }' /etc/apt/sources.list
fi
if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
  sed -i 's/^Components:.*/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
fi
apt-get update -qq
echo steam steam/question select "I AGREE" | debconf-set-selections
echo steam steam/license note '' | debconf-set-selections
apt-get install -y -qq lib32gcc-s1 steamcmd >/dev/null
if [[ ! -x /usr/games/steamcmd ]]; then
  echo "steamcmd apt package did not install - check contrib/non-free are enabled." >&2
  exit 1
fi

echo "==> Downloading and installing ServerJockey (.deb)..."
TMP_DEB="$(mktemp /tmp/sjgms.XXXXXX.deb)"
if ! wget -qO "${TMP_DEB}" "${DEB_URL}"; then
  echo "Failed to download ServerJockey deb from ${DEB_URL}." >&2
  exit 1
fi
# apt install resolves the deb's own dependencies (python deps etc.)
apt-get install -y "${TMP_DEB}"
rm -f "${TMP_DEB}"

echo "==> Ensuring ServerJockey service is enabled and running..."
systemctl enable serverjockey.service >/dev/null 2>&1 || true
systemctl restart serverjockey.service 2>/dev/null || systemctl start serverjockey.service 2>/dev/null || true

# Give it a moment to come up, then fetch the login token
sleep 5
SJ_TOKEN="$(serverjockey_cmd.pyz -nc showtoken 2>/dev/null || true)"
CT_IP="$(hostname -I | awk '{print $1}')"

cat <<EOM

=============================================================================
 ServerJockey setup complete!
=============================================================================
 Web panel : http://${CT_IP}:${SJ_PORT}
EOM
if [[ -n "${SJ_TOKEN}" ]]; then
  cat <<EOM
 Login token:
   ${SJ_TOKEN}
EOM
else
  cat <<EOM
 Get your login token with:
   serverjockey_cmd.pyz -nc showtoken
EOM
fi
cat <<EOM

 In the web panel you can create + launch game servers (Project Zomboid and
 others), edit their settings, manage mods, view the live console, and more -
 all from the browser. No per-game install scripts needed.

 To create a Project Zomboid server: log in -> add instance -> choose
 "projectzomboid" -> configure -> deploy. ServerJockey handles the SteamCMD
 download and config for you.

 Forward each game server's own ports on your router as you create them
 (e.g. Project Zomboid 16261-16262/udp). The panel port ${SJ_PORT} should stay
 LAN-only or behind your VPN - do NOT expose it to the internet.
=============================================================================
EOM
