FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive 
TERM=xterm-256color 
COLORTERM=truecolor 
TZ=Asia/Dhaka 
PIP_NO_CACHE_DIR=1 
PIP_DISABLE_PIP_VERSION_CHECK=1 
NPM_CONFIG_AUDIT=false 
NPM_CONFIG_FUND=false 
NPM_CONFIG_UPDATE_NOTIFIER=false 
NPM_CONFIG_CACHE=/tmp/.npm-cache

--------------------------------------------------

Base system packages

--------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends 
tzdata openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils 
lsof htop jq speedtest-cli unzip tree python3 python3-pip 
ca-certificates gnupg tmux screen vim zip rsync socat telnet ncdu 
&& ln -snf /usr/share/zoneinfo/$TZ /etc/localtime 
&& echo $TZ > /etc/timezone 
&& curl -fsSL https://tailscale.com/install.sh | sh 
&& mkdir -p /usr/share/keyrings 
&& curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg 
&& echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main" > /etc/apt/sources.list.d/cloudflared.list 
&& apt-get update 
&& apt-get install -y --no-install-recommends cloudflared 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/* /root/.cache/pip

--------------------------------------------------

Install Node.js LTS + Codex

--------------------------------------------------

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 
&& apt-get install -y --no-install-recommends nodejs 
&& npm i -g @openai/codex --cache /tmp/.npm-cache --no-audit --no-fund 
&& npm cache clean --force 
&& rm -rf /tmp/.npm-cache /root/.npm /root/.cache/npm /root/.cache/node-gyp 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

--------------------------------------------------

SSH + users

Password login and SSH key login are both enabled.

StrictModes is disabled as requested.

--------------------------------------------------

RUN mkdir -p /var/run/sshd 
&& useradd -m -s /bin/bash -u 1000 devuser 
&& echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 
&& echo "devuser:123456" | chpasswd 
&& echo "root:123456" | chpasswd 
&& mkdir -p /home/devuser/.ssh /root/.ssh 
&& echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl/8uY6DFHrP7QB/Nowv3oHceyUpq0QjL/lVL A45Vf7 runner@cb615ad88875' > /home/devuser/.ssh/authorized_keys 
&& echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl/8uY6DFHrP7QB/Nowv3oHceyUpq0QjL/lVL A45Vf7 runner@cb615ad88875' > /root/.ssh/authorized_keys 
&& chown -R devuser:devuser /home/devuser/.ssh 
&& chown -R root:root /root/.ssh 
&& chmod 700 /home/devuser/.ssh /root/.ssh 
&& chmod 600 /home/devuser/.ssh/authorized_keys /root/.ssh/authorized_keys 
&& sed -i '/^PasswordAuthentication/d;/^PubkeyAuthentication/d;/^PermitRootLogin/d;/^StrictModes/d;/^UsePAM/d;/^ChallengeResponseAuthentication/d;/^KbdInteractiveAuthentication/d' /etc/ssh/sshd_config 
&& printf '%s\n' 
'PasswordAuthentication yes' 
'PubkeyAuthentication yes' 
'PermitRootLogin yes' 
'StrictModes no' 
'UsePAM no' 
'ChallengeResponseAuthentication no' 
'KbdInteractiveAuthentication no' 
>> /etc/ssh/sshd_config

--------------------------------------------------

Disable default MOTD noise

--------------------------------------------------

RUN rm -rf /etc/update-motd.d/* 
&& rm -f /etc/legal /etc/motd 
&& touch /home/devuser/.hushlogin /root/.hushlogin 
&& chown devuser:devuser /home/devuser/.hushlogin

--------------------------------------------------

Phoenix shell shortcuts

No Dockerfile heredoc is used here, so Railway parser will not fail.

Backup/R2 helpers and virtual-environment helpers are removed.

--------------------------------------------------

RUN printf '%s\n' 
'export PHOENIX_CPU_HISTORY_FILE="/tmp/.phoenix_cpu_history_${USER}"' 
'' 
'alias c="clear"' 
'alias ..="cd .."' 
'alias ...="cd ../.."' 
'alias ll="ls -alF --color=auto"' 
'alias la="ls -A --color=auto"' 
'alias md="mkdir -p"' 
'alias sz="du -sh * 2>/dev/null | sort -hr"' 
'alias tree="tree -C"' 
'alias f="find . -name"' 
'alias grep="grep --color=auto"' 
'alias h="history"' 
'alias dsize="du -h --max-depth=1 | sort -hr"' 
'alias chmodx="chmod +x"' 
'alias chownme="sudo chown -R $USER:$USER ."' 
'alias path="echo -e ${PATH//:/\n}"' 
'alias up="sudo apt-get update && sudo apt-get upgrade -y"' 
'alias clean="sudo apt-get autoremove -y && sudo apt-get clean && reclaimram"' 
'alias mem="ram"' 
'alias hostmem="free -h"' 
'alias cpu="cpuuse"' 
'alias cpu5="cpuuse 5"' 
'alias df="df -h"' 
'alias top="htop"' 
'alias ports="sudo netstat -tulpn"' 
'alias logs="sudo tail -f /var/log/syslog"' 
'alias rst="source ~/.bashrc && echo Terminal Reloaded"' 
'alias sysinfo="cat /etc/os-release"' 
'alias cpuinfo="lscpu"' 
'alias myports="ss -tuln"' 
'alias histg="history | grep"' 
'alias myip="curl -s ipinfo.io; echo"' 
'alias speed="speedtest-cli --simple"' 
'alias ping="ping -c 4"' 
'alias ts="sudo tailscale status"' 
'alias pinger="ping -c 4 8.8.8.8"' 
'alias serve="python3 -m http.server 8000"' 
'alias gs="git status"' 
'alias ga="git add ."' 
'alias gc="git commit -m"' 
'alias gp="git push"' 
'alias gl="git log --oneline --graph -n 10"' 
'alias get="wget -c"' 
'alias api="curl -s"' 
'alias weather="curl -s wttr.in/Dhaka?0"' 
'alias apps="ps -eo pid,user,%cpu,%mem,command | grep -E "[c]odex|[n]ode|[p]ython" || echo None"' 
'alias kn="sudo pkill -f node 2>/dev/null; echo All Node apps stopped"' 
'alias kp="sudo pkill -f python 2>/dev/null; echo All Python apps stopped"' 
'alias kcodex="sudo pkill -f codex 2>/dev/null; echo All Codex processes stopped"' 
'' 
'CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts"' 
'[ -f "$CUSTOM_ALIAS_FILE" ] && source "$CUSTOM_ALIAS_FILE"' 
'' 
'mkcd() { mkdir -p "$1" && cd "$1"; }' 
'findtext() { grep -rnw . -e "$1"; }' 
'gitlog() { git log --oneline --graph --decorate --all -n 20 2>/dev/null || echo "Not a git repository."; }' 
'' 
'addcmd() {' 
'  echo "Create a New Shortcut"' 
'  read -r -p "Shortcut Name: " S_NAME' 
'  [ -z "$S_NAME" ] && echo "Cancelled. Name cannot be empty." && return 1' 
'  if grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then echo "Shortcut already exists."; return 1; fi' 
'  read -r -p "Command to run: " S_CMD' 
'  [ -z "$S_CMD" ] && echo "Cancelled. Command cannot be empty." && return 1' 
'  printf "alias %s="%s"\n" "$S_NAME" "$S_CMD" >> "$CUSTOM_ALIAS_FILE"' 
'  source "$CUSTOM_ALIAS_FILE"' 
'  echo "Shortcut created: $S_NAME"' 
'}' 
'' 
'delcmd() {' 
'  read -r -p "Shortcut Name to delete: " S_NAME' 
'  [ -z "$S_NAME" ] && echo "Cancelled. Name cannot be empty." && return 1' 
'  sed -i "/alias $S_NAME=/d" "$CUSTOM_ALIAS_FILE" 2>/dev/null || true' 
'  unalias "$S_NAME" 2>/dev/null || true' 
'  echo "Shortcut deleted: $S_NAME"' 
'}' 
'' 
'cmds() {' 
'  echo ""' 
'  echo "Phoenix Shortcuts"' 
'  echo "-----------------"' 
'  echo "c, .., ..., ll, la, md, sz, tree, dsize, findtext, findbig"' 
'  echo "ram, ramtop, ramwhy, reclaimram, cachefiles"' 
'  echo "cpu, cpu5, cputop, cpuwhy, cpulive, cginfo"' 
'  echo "DISK, diskwhy, bigfiles, bigdirs, tmpclean"' 
'  echo "NET, netlive, netstats, netports, dnslookup"' 
'  echo "cc, cs, ts, myip, pinger, speed, serve"' 
'  echo "apps, kn, kp, kcodex, kport, dcodex, dpy, dgo, djava"' 
'  echo "addcmd, delcmd, gitlog, uptime2, envlist, syshealth"' 
'  echo ""' 
'}' 
'' 
'_b2h() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1"; }' 
'' 
'ram() {' 
'  echo ""' 
'  echo "RAM Summary"' 
'  echo "-----------"' 
'  free -h' 
'  if [ -f /sys/fs/cgroup/memory.current ]; then echo "Cgroup current: $(_b2h $(cat /sys/fs/cgroup/memory.current))"; fi' 
'  if [ -f /sys/fs/cgroup/memory.max ]; then echo "Cgroup max    : $(cat /sys/fs/cgroup/memory.max)"; fi' 
'  echo ""' 
'}' 
'' 
'ramtop() { ps -eo pid,user,%mem,rss,comm --sort=-rss | head -n 15; }' 
'ramwhy() { ram; echo "Top memory processes:"; ramtop; }' 
'cachefiles() { du -sh /var/cache/apt /var/lib/apt/lists "$HOME/.cache" "$HOME/.npm" /tmp /var/tmp 2>/dev/null | sort -hr; }' 
'reclaimram() { npm cache clean --force >/dev/null 2>&1 || true; python3 -m pip cache purge >/dev/null 2>&1 || true; sudo apt-get clean >/dev/null 2>&1 || true; rm -rf "$HOME/.npm" "$HOME/.cache/npm" "$HOME/.cache/node-gyp" "$HOME/.cache/pip" /tmp/.npm-cache /tmp/pip-* /var/tmp/* 2>/dev/null || true; sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/.bin 2>/dev/null || true; sync; ram; }' 
'' 
'cpuuse() { echo "CPU sample:"; top -bn1 | head -n 5; }' 
'cputop() { ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu | head -n 15; }' 
'cpuwhy() { cpuuse; echo "Top CPU processes:"; cputop; }' 
'cpulive() { while true; do clear; date; cpuuse; cputop; sleep "${1:-2}"; done; }' 
'cpuavg() { cpuuse; }' 
'cginfo() { echo "CPU cgroup:"; [ -f /sys/fs/cgroup/cpu.max ] && cat /sys/fs/cgroup/cpu.max; [ -f /sys/fs/cgroup/cpu.stat ] && cat /sys/fs/cgroup/cpu.stat; echo "Memory cgroup:"; [ -f /sys/fs/cgroup/memory.current ] && cat /sys/fs/cgroup/memory.current; [ -f /sys/fs/cgroup/memory.max ] && cat /sys/fs/cgroup/memory.max; }' 
'' 
'DISK() { df -h; echo ""; du -sh "$HOME" /root /tmp /var/log /var/cache 2>/dev/null | sort -hr; }' 
'diskwhy() { DISK; echo "Top directories:"; du -hx --max-depth=2 / 2>/dev/null | sort -hr | head -n 20; }' 
'bigfiles() { find / -xdev -type f -printf "%s %p\n" 2>/dev/null | sort -rn | head -n 20; }' 
'bigdirs() { du -hx --max-depth=4 / 2>/dev/null | sort -hr | head -n 20; }' 
'tmpclean() { rm -rf /tmp/ /tmp/.[!.]* /var/tmp/* 2>/dev/null || true; sync; df -h /; }' 
'disklive() { while true; do clear; date; DISK; sleep 2; done; }' 
'' 
'NET() { ip -4 addr show; echo ""; ss -tuln; echo ""; cat /proc/net/dev; }' 
'netstats() { ss -tan; echo ""; cat /proc/net/sockstat 2>/dev/null || true; }' 
'netports() { sudo ss -tulpn; }' 
'dnslookup() { [ -z "$1" ] && echo "Usage: dnslookup <domain>" && return 1; host -t A "$1"; host -t MX "$1"; host -t NS "$1"; }' 
'netlive() { while true; do clear; date; cat /proc/net/dev; sleep 2; done; }' 
'' 
'kport() { [ -z "$1" ] && echo "Usage: kport <port>" && return 1; PID=$(sudo lsof -t -i:"$1"); [ -z "$PID" ] && echo "Port $1 is free" || { sudo kill -9 $PID; echo "Killed process on port $1"; }; }' 
'ex() { [ -z "$1" ] && echo "Usage: ex <file>" && return 1; case "$1" in *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;; *.bz2) bunzip2 "$1" ;; .gz) gunzip "$1" ;; .tar) tar xf "$1" ;; .zip) unzip "$1" ;; ) echo "Cannot extract $1" ;; esac; }' 
'' 
'dcodex() { command -v codex >/dev/null 2>&1 && { codex --version 2>/dev/null || echo "Codex installed"; node -v; npm -v; } || echo "Codex not found"; }' 
'dpy() { python3 --version; pip3 --version; }' 
'dgo() { sudo apt-get update && sudo apt-get install -y --no-install-recommends golang && sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/ /var/cache/apt/archives/; go version; }' 
'djava() { sudo apt-get update && sudo apt-get install -y --no-install-recommends openjdk-17-jdk openjdk-17-jre && sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/ /var/cache/apt/archives/; java -version; }' 
'' 
'cc() {' 
'  pgrep -x tailscaled >/dev/null || { nohup sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 >/dev/null 2>&1 & sleep 3; }' 
'  TS_KEY_FILE="$HOME/.ts_auth_key"' 
'  if [ -f "$TS_KEY_FILE" ]; then read -r -p "Use previous Tailscale key? [Y/n]: " USE_OLD; if [ "$USE_OLD" = "n" ] || [ "$USE_OLD" = "N" ]; then read -r -p "New Tailscale Auth Key: " TS_KEY; echo "$TS_KEY" > "$TS_KEY_FILE"; else TS_KEY=$(cat "$TS_KEY_FILE"); fi; else read -r -p "Enter Tailscale Auth Key: " TS_KEY; echo "$TS_KEY" > "$TS_KEY_FILE"; fi' 
'  [ -z "$TS_KEY" ] && echo "No key provided" && return 1' 
'  sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix' 
'}' 
'cs() { sudo tailscale logout 2>/dev/null || true; sudo tailscale down 2>/dev/null || true; sudo pkill -f tailscaled 2>/dev/null || true; echo "Tailscale stopped"; }' 
'' 
'proctree() { ps -eo pid,ppid,user,%cpu,%mem,comm --sort=ppid | head -n 40; }' 
'openfiles() { for pid in $(ls /proc 2>/dev/null | grep -E "^[0-9]+$" | sort -n); do fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l); comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?"); user=$(stat -c "%U" /proc/$pid 2>/dev/null || echo "?"); [ "$fd_count" -gt 5 ] 2>/dev/null && printf "%s %s %s %s\n" "$pid" "$fd_count" "$user" "$comm"; done | sort -k2 -rn | head -n 20; }' 
'uptime2() { uptime; ps -o etimes= -p 1 2>/dev/null | xargs -I{} echo "Container PID1 uptime seconds: {}"; }' 
'envlist() { env | sort; }' 
'syshealth() { uptime2; ram; cpuwhy; DISK; NET; }' 
'' 
'custom_motd() {' 
'  echo "============================================================"' 
'  echo "Phoenix Server"' 
'  echo "OS      : $(grep PRETTY_NAME /etc/os-release | cut -d " -f 2)"' 
'  echo "Kernel  : $(uname -r)"' 
'  echo "User    : $USER"' 
'  echo "Time    : $(date)"' 
'  echo "============================================================"' 
'}' 
'' 
'if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then' 
'  clear' 
'  custom_motd' 
'  echo "Quick Actions: cmds | ram | cpu5 | DISK | NET | dcodex | cc"' 
'fi' 
> /opt/phoenix-shell.sh 
&& chmod 644 /opt/phoenix-shell.sh 
&& printf '%s\n' '' 'export PS1="\u@phoenix:\w$ "' 'if [ -f /opt/phoenix-shell.sh ]; then source /opt/phoenix-shell.sh; fi' >> /home/devuser/.bashrc 
&& printf '%s\n' '' 'export PS1="\u@phoenix:\w# "' 'if [ -f /opt/phoenix-shell.sh ]; then source /opt/phoenix-shell.sh; fi' >> /root/.bashrc 
&& chown devuser:devuser /home/devuser/.bashrc

--------------------------------------------------

Startup script

No heredoc.

--------------------------------------------------

RUN printf '%s\n' 
'#!/bin/bash' 
'set -e' 
'mkdir -p /var/run/sshd' 
'ssh-keygen -A' 
'exec /usr/sbin/sshd -D -e' 
> /start.sh 
&& sed -i 's/\r$//' /start.sh 
&& chmod +x /start.sh

WORKDIR /home/devuser

EXPOSE 22

CMD ["/start.sh"]
