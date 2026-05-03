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
PHOENIX_CPU_SAMPLE_SECONDS=2 
PHOENIX_MM_CPU_SAMPLE_SECONDS=2 
PHOENIX_CPU_FALLBACK_VCPU= 
PHOENIX_CPU_HISTORY_FILE=/tmp/.phoenix_cpu_history

--------------------------------------------------

Base system packages

--------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends 
tzdata openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils 
lsof htop jq speedtest-cli unzip tree python3 python3-pip 
ca-certificates gnupg tmux screen vim zip rsync socat telnet ncdu 
&& pip3 install awscli 
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

Install Node.js LTS + Codex at build time

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

Password login + public key login enabled.

StrictModes disabled as requested.

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
&& chmod 700 /home/devuser/.ssh /root/.ssh 
&& chmod 600 /home/devuser/.ssh/authorized_keys /root/.ssh/authorized_keys 
&& sed -i '/^PasswordAuthentication/d;/^PubkeyAuthentication/d;/^PermitRootLogin/d;/^StrictModes/d;/^UsePAM/d;/^ChallengeResponseAuthentication/d;/^KbdInteractiveAuthentication/d' /etc/ssh/sshd_config 
&& { 
echo 'PasswordAuthentication yes'; 
echo 'PubkeyAuthentication yes'; 
echo 'PermitRootLogin yes'; 
echo 'StrictModes no'; 
echo 'UsePAM no'; 
echo 'ChallengeResponseAuthentication no'; 
echo 'KbdInteractiveAuthentication no'; 
} >> /etc/ssh/sshd_config

--------------------------------------------------

Disable default MOTD noise

--------------------------------------------------

RUN rm -rf /etc/update-motd.d/* 
&& rm -f /etc/legal /etc/motd 
&& touch /home/devuser/.hushlogin /root/.hushlogin 
&& chown devuser:devuser /home/devuser/.hushlogin

--------------------------------------------------

Main shell setup

Backup/R2 helpers removed.

Python virtual-environment shortcuts removed as requested.

--------------------------------------------------

RUN cat > /tmp/setup.sh <<'EOF' export PHOENIX_CPU_HISTORY_FILE="/tmp/.phoenix_cpu_history_${USER}"

==========================================

SYSTEM ALIASES

==========================================

alias c='clear' alias ..='cd ..' alias ...='cd ../..' alias ll='ls -alF --color=auto' alias la='ls -A --color=auto' alias md='mkdir -p' alias sz='du -sh * 2>/dev/null | sort -hr' alias tree='tree -C' alias f='find . -name' alias grep='grep --color=auto' alias h='history' alias findbig='find . -type f -size +50M -exec ls -lh {} + 2>/dev/null | awk '''{ print $9 ": " $5 }'''' alias dsize='du -h --max-depth=1 | sort -hr' alias chmodx='chmod +x' alias chownme='sudo chown -R $USER:$USER .' alias path='echo -e ${PATH//:/\n}' alias up='sudo apt-get update && sudo apt-get upgrade -y' alias clean='sudo apt-get autoremove -y && sudo apt-get clean && reclaimram' alias mem='ram' alias hostmem='free -h' alias cpu='cpuuse' alias cpu5='cpuuse 5' alias df='df -h' alias top='htop' alias ports='sudo netstat -tulpn' alias logs='sudo tail -f /var/log/syslog' alias rst='source ~/.bashrc && echo -e "\e[1;32m✔ Terminal Reloaded!\e[0m"' alias sysinfo='cat /etc/os-release' alias cpuinfo='lscpu' alias myports='ss -tuln' alias histg='history | grep' alias myip='echo -e "\n\e[1;36m🌐 IP Details:\e[0m"; curl -s ipinfo.io; echo' alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple' alias ping='ping -c 4' alias ts='sudo tailscale status' alias pinger='ping -c 4 8.8.8.8' alias serve='python3 -m http.server 8000' alias gs='git status' alias ga='git add .' alias gc='git commit -m' alias gp='git push' alias gl='git log --oneline --graph -n 10' alias get='wget -c' alias api='curl -s' alias weather='curl -s wttr.in/Dhaka?0' alias apps='echo -e "\n\e[1;36m▶ Codex / Node / Python Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[c]odex|[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"' alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"' alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"' alias kcodex='sudo pkill -f codex 2>/dev/null; echo -e "\e[1;32m✔ All Codex processes stopped.\e[0m"'

==========================================

CUSTOM SHORTCUT MANAGER

==========================================

CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts" [ -f "$CUSTOM_ALIAS_FILE" ] && source "$CUSTOM_ALIAS_FILE"

function addcmd() { echo -e "\n\e[1;36m➕ Create a New Shortcut\e[0m" echo -e "\e[90m----------------------------------------\e[0m" read -r -p "Shortcut Name (e.g., gohome) : " S_NAME [ -z "$S_NAME" ] && echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m" && return 1

if grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
    echo -e "\e[1;33mℹ Shortcut '$S_NAME' already exists!\e[0m"
    return 1
fi

read -r -p "Command to run (e.g., cd ~)  : " S_CMD
[ -z "$S_CMD" ] && echo -e "\e[1;31m✘ Cancelled. Command cannot be empty.\e[0m" && return 1

printf "alias %s='%s'\n" "$S_NAME" "$S_CMD" >> "$CUSTOM_ALIAS_FILE"
eval "alias $S_NAME='$S_CMD'"
echo -e "\e[1;32m✔ Shortcut '$S_NAME' has been created!\e[0m\n"

}

function delcmd() { echo -e "\n\e[1;31m🗑️ Delete a Custom Shortcut\e[0m" echo -e "\e[90m----------------------------------------\e[0m" read -r -p "Shortcut Name to delete : " S_NAME [ -z "$S_NAME" ] && echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m" && return 1

if ! grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
    echo -e "\e[1;33mℹ Shortcut '$S_NAME' not found!\e[0m"
    return 1
fi

sed -i "/alias $S_NAME=/d" "$CUSTOM_ALIAS_FILE"
unalias "$S_NAME" 2>/dev/null || true
echo -e "\e[1;32m✔ Shortcut '$S_NAME' deleted!\e[0m\n"

}

==========================================

MENU

==========================================

function pcmd() { printf "   \e[1;32m%-14s\e[0m : %s\n" "$1" "$2"; }

function cmds() { echo -e "\n\e[1;37m⚡ ALL MAGICAL SHORTCUTS ⚡\e[0m" echo -e "\e[90m──────────────────────────────────────────────────────────────\e[0m"

echo -e "\e[1;33m📁 Navigation & Files\e[0m"
pcmd "c" "Clear screen"
pcmd ".." "Go back 1 folder"
pcmd "..." "Go back 2 folders"
pcmd "ll" "List files with details & sizes"
pcmd "sz" "Show size of files/folders here"
pcmd "md" "Make a new directory"
pcmd "mkcd <dir>" "Make a directory and enter it"
pcmd "tree" "Visual tree structure"
pcmd "dsize" "Sub-folder sizes"
pcmd "chownme" "Take ownership of current directory"
pcmd "chmodx" "Make a file executable"
pcmd "ex <file>" "Extract archive"
pcmd "findbig" "Find files larger than 50MB"
pcmd "findtext" "Search text inside files"

echo -e "\n\e[1;33m💻 System & Processes\e[0m"
pcmd "up" "Update and upgrade packages"
pcmd "clean" "Autoremove + apt clean + reclaimram"
pcmd "mem" "Same as ram"
pcmd "hostmem" "Raw free -h"
pcmd "ram" "Container RAM summary"
pcmd "ramtop" "Top processes by RSS"
pcmd "ramwhy" "Explain RAM usage"
pcmd "cachefiles" "Show cache directories"
pcmd "reclaimram" "Clean cache files"
pcmd "cpu" "CPU usage"
pcmd "cpu5" "CPU usage, 5 sec average"
pcmd "cputop" "Top CPU-hungry processes"
pcmd "cpulive [s]" "Live CPU monitor"
pcmd "cpuwhy [s]" "Explain CPU spikes / throttling"
pcmd "cpuavg [s]" "Average saved CPU history"
pcmd "cginfo" "Show raw cgroup info"
pcmd "diag" "Quick full diagnostics"
pcmd "df" "Disk space usage"
pcmd "top" "Task manager"
pcmd "cpuinfo" "CPU hardware info"
pcmd "sysinfo" "OS details"
pcmd "ports" "Open ports"
pcmd "logs" "Live syslog"
pcmd "rst" "Reload terminal settings"
pcmd "h" "History"
pcmd "histg <txt>" "Search history"

echo -e "\n\e[1;33m💾 Disk & Storage\e[0m"
pcmd "DISK" "Full container disk usage"
pcmd "disklive" "Live disk I/O monitor"
pcmd "diskwhy" "Explain disk usage"
pcmd "bigfiles" "Top 20 largest files"
pcmd "bigdirs" "Top 20 largest directories"
pcmd "tmpclean" "Clean /tmp and /var/tmp"

echo -e "\n\e[1;33m🌐 Network & Traffic\e[0m"
pcmd "NET" "Network usage since boot"
pcmd "netlive" "Live network traffic monitor"
pcmd "netstats" "Detailed connection statistics"
pcmd "netports" "Active connections with process"
pcmd "dnslookup" "DNS lookup helper"
pcmd "cc" "Connect to Tailscale"
pcmd "cs" "Disconnect Tailscale"
pcmd "ts" "Tailscale status"
pcmd "myip" "Public IP details"
pcmd "pinger" "Internet connectivity test"
pcmd "speed" "Internet speed test"
pcmd "serve" "Host current folder on :8000"

echo -e "\n\e[1;33m🎯 App Management\e[0m"
pcmd "apps" "List Codex/Node/Python apps"
pcmd "kn" "Kill all Node.js apps"
pcmd "kp" "Kill all Python apps"
pcmd "kcodex" "Kill all Codex processes"
pcmd "kport <no>" "Kill app on a port"
pcmd "proctree" "Process tree view"
pcmd "openfiles" "Show open file count per process"

echo -e "\n\e[1;33m🛠️ Tools & Dev\e[0m"
pcmd "weather" "Weather in Dhaka"
pcmd "gs, ga, gc" "Git shortcuts"
pcmd "gitlog" "Pretty full git log"
pcmd "addcmd" "Create personal shortcut"
pcmd "delcmd" "Delete personal shortcut"
pcmd "dcodex" "Show Codex status"
pcmd "dpy" "Check Python/Pip"
pcmd "dgo" "Install Golang at runtime"
pcmd "djava" "Install Java 17 at runtime"
pcmd "syshealth" "Full system health report"
pcmd "uptime2" "Pretty uptime display"
pcmd "envlist" "Show all env variables"

echo -e "\n\e[1;35m👤 My Personal Shortcuts\e[0m"
if [ -f "$CUSTOM_ALIAS_FILE" ] && [ -s "$CUSTOM_ALIAS_FILE" ]; then
    sed "s/alias //g; s/='/|/g; s/'//g" "$CUSTOM_ALIAS_FILE" | while IFS='|' read -r name cmd; do
        pcmd "$name" "$cmd"
    done
else
    echo -e "   \e[90mNo personal shortcuts yet. Type 'addcmd' to create one.\e[0m"
fi

echo -e "\e[90m──────────────────────────────────────────────────────────────\e[0m\n"

}

==========================================

HELPERS

==========================================

function mkcd() { mkdir -p "$1" && cd "$1" || return; } function findtext() { grep -rnw . -e "$1"; }

function kport() { [ -z "$1" ] && echo -e "\e[1;31m✘ Usage: kport <port>\e[0m" && return 1 PID=$(sudo lsof -t -i:"$1") if [ -z "$PID" ]; then echo -e "\e[1;33mℹ Port $1 is free\e[0m" else sudo kill -9 $PID echo -e "\e[1;32m✔ Killed process on port $1\e[0m" fi }

function ex() { [ -z "$1" ] && echo -e "\e[1;31m✘ Usage: ex <file>\e[0m" && return 1 if [ -f "$1" ]; then case "$1" in *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;; *.bz2) bunzip2 "$1" ;; *.rar) unrar e "$1" ;; *.gz) gunzip "$1" ;; *.tar) tar xf "$1" ;; *.zip) unzip "$1" ;; *) echo -e "\e[1;31m✘ Cannot extract '$1'\e[0m" ;; esac else echo -e "\e[1;31m✘ '$1' is not a valid file\e[0m" fi }

==========================================

DEV SHORTCUTS

==========================================

function dcodex() { echo -e "\n\e[1;36m🤖 Codex Status\e[0m" echo -e "\e[90m----------------------------------------\e[0m" if command -v codex >/dev/null 2>&1; then echo -e "\e[1;32m✔ Codex is installed.\e[0m" echo -e "\e[1;36mCodex Version:\e[0m $(codex --version 2>/dev/null || echo installed)" echo -e "\e[1;36mNode Version:\e[0m $(node -v 2>/dev/null || echo missing)" echo -e "\e[1;36mNPM Version:\e[0m $(npm -v 2>/dev/null || echo missing)" else echo -e "\e[1;31m✘ Codex not found. Rebuild the image.\e[0m" return 1 fi echo }

function dpy() { echo -e "\n\e[1;36m🐍 Python Environment Status\e[0m" echo -e "\e[90m----------------------------------------\e[0m" if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then echo -e "\e[1;32m✔ Python and pip are installed.\e[0m" echo -e "\e[1;36mPython Version:\e[0m $(python3 --version 2>&1)" echo -e "\e[1;36mPip Version:\e[0m $(pip3 --version 2>&1)" return 0 fi

echo -e "\e[1;33m⚠ Missing Python/Pip package detected. Installing now...\e[0m"
sudo apt-get update
sudo apt-get install -y --no-install-recommends python3 python3-pip
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/*.bin
python3 -m pip cache purge >/dev/null 2>&1 || true
sync

}

function dgo() { echo -e "\n\e[1;36m🐹 Installing Golang...\e[0m" sudo apt-get update && sudo apt-get install -y --no-install-recommends golang sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* sync echo -e "\e[1;32m✔ Go installed successfully!\e[0m" go version }

function djava() { echo -e "\n\e[1;36m☕ Installing Java 17 LTS...\e[0m" sudo apt-get update && sudo apt-get install -y --no-install-recommends openjdk-17-jdk openjdk-17-jre sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* sync echo -e "\e[1;32m✔ Java installed successfully!\e[0m" java -version }

==========================================

MEMORY / RAM HELPERS

==========================================

_b2h() { awk -v b="${1:-0}" 'BEGIN{ split("B KB MB GB TB",u," "); i=1; while (b>=1024 && i<5) { b/=1024; i++ } printf "%.1f %s", b, u[i] }'; } _mem_mode() { if [ -f /sys/fs/cgroup/memory.current ]; then echo "v2"; elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then echo "v1"; else echo ""; fi; } _cg_base() { if [ -f /sys/fs/cgroup/memory.current ]; then echo "/sys/fs/cgroup"; return; fi; if [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then echo "/sys/fs/cgroup/memory"; return; fi; } _cg_read() { local f="$1"; [ -f "$f" ] || { echo 0; return; }; local v; v=$(cat "$f" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || echo 0; } _cg_stat() { local key="$1" base; base="$(_cg_base)"; [ -z "$base" ] && { echo 0; return; }; awk -v k="$key" '$1==k {print $2}' "$base/memory.stat" 2>/dev/null | head -n 1; }

==========================================

CPU HELPERS

==========================================

_cpu_mode() { if [ -f /sys/fs/cgroup/cpu.stat ]; then echo "v2"; elif [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ] || [ -f /sys/fs/cgroup/cpu/cpu.stat ]; then echo "v1"; else echo ""; fi; }

_cpu_limit() { local quota period if [ -f /sys/fs/cgroup/cpu.max ]; then read -r quota period < /sys/fs/cgroup/cpu.max if [ "$quota" != "max" ] && [ -n "$period" ] && [ "$period" -gt 0 ] 2>/dev/null; then awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.2f\n", q/p }' return fi fi if [ -n "$PHOENIX_CPU_FALLBACK_VCPU" ] && awk -v v="$PHOENIX_CPU_FALLBACK_VCPU" 'BEGIN { exit !(v>0) }'; then printf "%.2f\n" "$PHOENIX_CPU_FALLBACK_VCPU" return fi echo "0" }

_cpu_limit_label() { local l="$(_cpu_limit)"; if awk -v v="$l" 'BEGIN { exit !(v>0) }'; then printf "%s vCPU limit" "$l"; else printf "shared/auto"; fi; } _cpu_usage_usec() { if [ -f /sys/fs/cgroup/cpu.stat ]; then awk '/^usage_usec / {print $2; exit}' /sys/fs/cgroup/cpu.stat; return; fi; echo 0; } _cpu_throttled_usec() { if [ -f /sys/fs/cgroup/cpu.stat ]; then awk '/^throttled_usec / {print $2; found=1} END {if(!found) print 0}' /sys/fs/cgroup/cpu.stat; return; fi; echo 0; } _cpu_nr_throttled() { if [ -f /sys/fs/cgroup/cpu.stat ]; then awk '/^nr_throttled / {print $2; found=1} END {if(!found) print 0}' /sys/fs/cgroup/cpu.stat; return; fi; echo 0; } _cpu_pressure_avg() { local kind="${1:-some}" window="avg${2:-10}"; [ ! -f /sys/fs/cgroup/cpu.pressure ] && { echo "0.00"; return; }; awk -v k="$kind" -v w="$window" '$1==k { for(i=2;i<=NF;i++){ split($i,a,"="); if(a[1]==w){ print a[2]; found=1; exit } } } END { if(!found) print "0.00" }' /sys/fs/cgroup/cpu.pressure; } _cpu_history_file() { echo "${PHOENIX_CPU_HISTORY_FILE:-/tmp/.phoenix_cpu_history}"; } _cpu_record_history() { local used="$1" limit="$2" pct="$3" file tmp; file="$(_cpu_history_file)"; tmp="${file}.tmp.$$"; printf '%s|%s|%s|%s\n' "$(date +%s)" "$used" "$limit" "$pct" >> "$file"; tail -n 120 "$file" > "$tmp" 2>/dev/null && mv -f "$tmp" "$file"; } _cpu_avg_history() { local window="${1:-30}" file now; file="$(_cpu_history_file)"; [ ! -f "$file" ] && return 1; now=$(date +%s); awk -F'|' -v cutoff="$((now - window))" '$1>=cutoff {sum+=$2; n++} END { if(n>0) printf "%.3f\n", sum/n; else exit 1 }' "$file"; }

_cpu_measure() { local secs="${1:-2}" u1 u2 t1 t2 wall thr1 thr2 n1 n2 used limit pct thr_pct psi_some psi_full u1=$(_cpu_usage_usec); thr1=$(_cpu_throttled_usec); n1=$(_cpu_nr_throttled); t1=$(date +%s%N) sleep "$secs" t2=$(date +%s%N); u2=$(_cpu_usage_usec); thr2=$(_cpu_throttled_usec); n2=$(_cpu_nr_throttled) wall=$(( (t2 - t1) / 1000 )); [ "$wall" -le 0 ] && wall=1 used=$(awk -v du="$((u2-u1))" -v dw="$wall" 'BEGIN{ v=du/dw; if(v<0) v=0; printf "%.3f", v }') limit=$(_cpu_limit) pct=$(awk -v u="$used" -v l="$limit" 'BEGIN{ if(l>0) printf "%.1f", (u/l)*100; else print "-" }') thr_pct=$(awk -v dt="$((thr2-thr1))" -v dw="$wall" 'BEGIN{ if(dw>0){ p=(dt/dw)*100; if(p<0)p=0; printf "%.1f", p } else print "0.0" }') psi_some=$(_cpu_pressure_avg some 10) psi_full=$(_cpu_pressure_avg full 10) _cpu_record_history "$used" "$limit" "$pct" echo "$used|$limit|$pct|$((thr2-thr1))|$thr_pct|$((n2-n1))|$psi_some|$psi_full|$secs" }

==========================================

RAM TOOLS

==========================================

function ramtop() { echo -e "\n\e[1;36m📋 Top Processes by RSS\e[0m" ps -eo pid=,user=,%mem=,rss=,comm= --sort=-rss | head -n 15 | while read -r pid user mem rss comm; do printf "  %-7s │ %-8.8s │ %-6s │ %-10s │ %s\n" "$pid" "$user" "${mem}%" "$(_b2h "$((rss * 1024))")" "$comm" done echo }

function ramwhy() { local base used limit anon file slab rss base="$(_cg_base)"; [ -z "$base" ] && { echo "cgroup memory info not found"; return 1; } if [ -f "$base/memory.current" ]; then used=$(_cg_read "$base/memory.current"); limit=$(_cg_read "$base/memory.max"); else used=$(_cg_read "$base/memory.usage_in_bytes"); limit=$(_cg_read "$base/memory.limit_in_bytes"); fi anon=$(_cg_stat anon); [ -z "$anon" ] && anon=0 file=$(_cg_stat file); [ -z "$file" ] && file=0 slab=$(_cg_stat slab); [ -z "$slab" ] && slab=0 rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print s1024}') echo -e "\n\e[1;35m🔎 RAM Diagnosis\e[0m" if [ "$file" -gt "$anon" ] && [ "$file" -gt $((15010241024)) ]; then echo -e "\e[1;33mMain Cause:\e[0m File/Page cache is dominating memory." elif [ "$anon" -gt $((2001024*1024)) ]; then echo -e "\e[1;33mMain Cause:\e[0m Real process/application memory is high." else echo -e "\e[1;33mMain Cause:\e[0m Mixed usage." fi echo -e "  Total: $(_b2h "$used") / $(_b2h "$limit")" echo -e "  Anon : $(_b2h "$anon")" echo -e "  File : $(_b2h "$file")" echo -e "  Slab : $(_b2h "$slab")" echo -e "  RSS  : $(_b2h "$rss")" echo -e "\nRun: ramtop | cachefiles | reclaimram\n" }

function ram() { local base used limit anon file shmem slab slab_reclaimable pgt kstack sock rss free limit_txt free_txt used_pct reclaimable base="$(_cg_base)"; [ -z "$base" ] && { echo "cgroup memory info not found"; return 1; } if [ -f "$base/memory.current" ]; then used=$(_cg_read "$base/memory.current"); limit=$(_cg_read "$base/memory.max"); else used=$(_cg_read "$base/memory.usage_in_bytes"); limit=$(_cg_read "$base/memory.limit_in_bytes"); fi anon=$(_cg_stat anon); [ -z "$anon" ] && anon=0 file=$(_cg_stat file); [ -z "$file" ] && file=0 shmem=$(_cg_stat shmem); [ -z "$shmem" ] && shmem=0 slab=$(_cg_stat slab); [ -z "$slab" ] && slab=0 slab_reclaimable=$(_cg_stat slab_reclaimable); [ -z "$slab_reclaimable" ] && slab_reclaimable=0 pgt=$(_cg_stat pagetables); [ -z "$pgt" ] && pgt=0 kstack=$(_cg_stat kernel_stack); [ -z "$kstack" ] && kstack=0 sock=$(_cg_stat sock); [ -z "$sock" ] && sock=0 rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print s*1024}') reclaimable=$((file + slab_reclaimable)) if [[ "$limit" =~ ^[0-9]+$ ]] && [ "$limit" -gt 0 ]; then free=$((limit - used)); [ "$free" -lt 0 ] && free=0 limit_txt="$(_b2h "$limit")"; free_txt="$(_b2h "$free")" used_pct=$(awk -v u="$used" -v l="$limit" 'BEGIN { if (l>0) printf "%.1f%%", (u/l)*100; else print "-" }') else limit_txt="unlimited"; free_txt="-"; used_pct="-" fi echo -e "\n\e[1;36m📊 RAM (Container Accurate)\e[0m" printf "  %-20s : %s\n" "Cgroup Total" "$(_b2h "$used")" printf "  %-20s : %s\n" "Memory Limit" "$limit_txt" printf "  %-20s : %s\n" "Free to Limit" "$free_txt" printf "  %-20s : %s\n" "Usage Percent" "$used_pct" printf "  %-20s : %s\n" "Process RSS Sum" "$(_b2h "$rss")" printf "  %-20s : %s\n" "Anon Memory" "$(_b2h "$anon")" printf "  %-20s : %s\n" "File Cache" "$(_b2h "$file")" printf "  %-20s : %s\n" "Slab" "$(_b2h "$slab")" printf "  %-20s : %s\n" "Likely Reclaimable" "$(_b2h "$reclaimable")" echo -e "\nRun: ramtop | ramwhy | cachefiles | reclaimram\n" }

function cachefiles() { echo -e "\n\e[1;36m🗂 Common Cache Directories\e[0m" du -sh /var/cache/apt /var/lib/apt/lists "$HOME/.cache" "$HOME/.cache/pip" "$HOME/.cache/npm" "$HOME/.cache/node-gyp" "$HOME/.npm" /tmp/.npm-cache /var/tmp 2>/dev/null | sort -hr echo }

function reclaimram() { echo -e "\n\e[1;33m🧹 Cleaning package/cache files...\e[0m" npm cache clean --force >/dev/null 2>&1 || true python3 -m pip cache purge >/dev/null 2>&1 || true sudo apt-get clean >/dev/null 2>&1 || true rm -rf "$HOME/.npm" "$HOME/.cache/npm" "$HOME/.cache/node-gyp" "$HOME/.cache/pip" /tmp/.npm-cache /tmp/pip-* /tmp/pip-build-* /tmp/pip-install-* /var/tmp/* 2>/dev/null || true sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/*.bin 2>/dev/null || true sync if sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null; then echo -e "\e[1;32m✔ Linux page cache dropped.\e[0m" else echo -e "\e[1;33mℹ Cache files removed. Container cannot force-drop kernel page cache.\e[0m" fi ram }

==========================================

CPU TOOLS

==========================================

function cputop() { echo -e "\n\e[1;36m📈 Top Processes by CPU\e[0m" ps -eo pid=,user=,%cpu=,etime=,rss=,comm= --sort=-%cpu | head -n 15 | while read -r pid user cpu etime rss comm; do printf "  %-7s │ %-8.8s │ %-6s │ %-10s │ %-10s │ %s\n" "$pid" "$user" "${cpu}%" "$(_b2h "$((rss * 1024))")" "$etime" "$comm" done echo }

function cpuavg() { local win="${1:-30}" avg limit pct avg=$(_cpu_avg_history "$win" 2>/dev/null || true) [ -z "$avg" ] && echo -e "\n\e[1;33mℹ No local CPU history yet. Run cpu first.\e[0m\n" && return 1 limit=$(_cpu_limit) pct=$(awk -v u="$avg" -v l="$limit" 'BEGIN{ if(l>0) printf "%.1f", (u/l)*100; else print "-" }') echo -e "\n\e[1;36m🧠 Local CPU Average\e[0m" echo -e "  Window        : ${win}s" echo -e "  Average Used  : ${avg} vCPU" echo -e "  Limit         : $(_cpu_limit_label)" [ "$pct" != "-" ] && echo -e "  Percent Limit : ${pct}%" echo }

function cpuuse() { local secs="${1:-${PHOENIX_CPU_SAMPLE_SECONDS:-2}}" data used limit pct thr_usec thr_pct thr_n psi_some psi_full sample avg30 data="$(_cpu_measure "$secs")" IFS='|' read -r used limit pct thr_usec thr_pct thr_n psi_some psi_full sample <<< "$data" avg30=$(_cpu_avg_history 30 2>/dev/null || true) echo -e "\n\e[1;36m⚙ CPU (cgroup-based)\e[0m" echo -e "  Sample Window : ${sample}s" echo -e "  Used          : ${used} vCPU" echo -e "  Limit         : $(_cpu_limit_label)" [ "$pct" != "-" ] && echo -e "  Percent Limit : ${pct}%" echo -e "  Throttle Evts : ${thr_n}" echo -e "  Throttle Time : ${thr_pct}%" echo -e "  PSI some avg10: ${psi_some}%" echo -e "  PSI full avg10: ${psi_full}%" [ -n "$avg30" ] && echo -e "  Local Avg 30s : ${avg30} vCPU" echo }

function cpuwhy() { local secs="${1:-3}" data used limit pct thr_usec thr_pct thr_n psi_some psi_full sample avg30 data="$(_cpu_measure "$secs")" IFS='|' read -r used limit pct thr_usec thr_pct thr_n psi_some psi_full sample <<< "$data" avg30=$(_cpu_avg_history 30 2>/dev/null || true) echo -e "\n\e[1;35m🔎 CPU Diagnosis\e[0m" if [ "$thr_n" -gt 0 ] || awk -v t="$thr_pct" 'BEGIN { exit !(t>0.1) }'; then echo -e "\e[1;33mMain Cause:\e[0m CPU throttling happened during the sample." elif [ "$pct" != "-" ] && awk -v p="$pct" 'BEGIN { exit !(p>=70) }'; then echo -e "\e[1;33mMain Cause:\e[0m Real CPU load is high." elif awk -v s="$psi_some" 'BEGIN { exit !(s>=5.0) }'; then echo -e "\e[1;33mMain Cause:\e[0m CPU pressure is noticeable." else echo -e "\e[1;33mMain Cause:\e[0m Current CPU usage looks low or moderate." fi echo -e "  Used: ${used} vCPU, Sample: ${sample}s, Throttle: ${thr_pct}%, PSI: ${psi_some}%" [ -n "$avg30" ] && echo -e "  Local Avg 30s: ${avg30} vCPU" echo -e "\nRun: cpu 5 | cputop | cpulive 2 | cginfo\n" }

function cpulive() { echo -e "\e[1;36mLive CPU monitor. Press Ctrl+C to stop.\e[0m"; sleep 1; while true; do clear; cpuuse "${1:-2}"; cputop; done; }

function cginfo() { echo -e "\n\e[1;36m🧩 Raw cgroup info\e[0m" printf "  %-22s : %s\n" "CPU mode" "$(_cpu_mode)" printf "  %-22s : %s\n" "CPU limit label" "$(_cpu_limit_label)" [ -f /sys/fs/cgroup/cpu.max ] && printf "  %-22s : %s\n" "cpu.max" "$(cat /sys/fs/cgroup/cpu.max 2>/dev/null)" [ -f /sys/fs/cgroup/cpu.pressure ] && { echo "  cpu.pressure:"; sed 's/^/    /' /sys/fs/cgroup/cpu.pressure; } [ -f /sys/fs/cgroup/cpu.stat ] && { echo "  cpu.stat:"; sed 's/^/    /' /sys/fs/cgroup/cpu.stat; } [ -f /sys/fs/cgroup/memory.current ] && printf "  %-22s : %s\n" "memory.current" "$(cat /sys/fs/cgroup/memory.current 2>/dev/null)" [ -f /sys/fs/cgroup/memory.max ] && printf "  %-22s : %s\n" "memory.max" "$(cat /sys/fs/cgroup/memory.max 2>/dev/null)" echo }

function diag() { mm; cpuwhy 3; ramwhy; cachefiles; }

==========================================

UI / DASHBOARD

==========================================

function custom_motd() { OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2) KERNEL_VERSION=$(uname -r) ARCH=$(uname -m) CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//') [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown Virtual CPU" LAST_LOGIN_FILE="$HOME/.last_login_info" if [ -f "$LAST_LOGIN_FILE" ]; then LAST_LOGIN_DATA=$(cat "$LAST_LOGIN_FILE") LAST_LOGIN_TIME=$(echo "$LAST_LOGIN_DATA" | cut -d'|' -f1) LAST_LOGIN_IP=$(echo "$LAST_LOGIN_DATA" | cut -d'|' -f2) else LAST_LOGIN_TIME="First Login" LAST_LOGIN_IP="---" fi CURRENT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}') echo "$(date +"%A, %d %B %Y %I:%M:%S %p")|${CURRENT_IP:-Local}" > "$LAST_LOGIN_FILE" UPTIME_SEC=$(ps -o etimes= -p 1 2>/dev/null | xargs) if [ -n "$UPTIME_SEC" ] && [[ "$UPTIME_SEC" =~ ^[0-9]+$ ]]; then d=$((UPTIME_SEC / 86400)); h=$(((UPTIME_SEC % 86400) / 3600)); m=$(((UPTIME_SEC % 3600) / 60)) if [ "$d" -gt 0 ]; then MY_UPTIME="${d} days, ${h} hours, ${m} mins"; elif [ "$h" -gt 0 ]; then MY_UPTIME="${h} hours, ${m} mins"; else MY_UPTIME="${m} mins"; fi else MY_UPTIME="Just started" fi echo -e "\e[1;36m╭────────────────────────────────────────────────────────────────────────╮\e[0m" echo -e "\e[1;36m│ \e[1;37m🔥 Welcome to Phoenix Server 🔥\e[0m" echo -e "\e[1;36m├────────────────────────────────────────────────────────────────────────┤\e[0m" echo -e "\e[1;36m│ \e[1;32m💻 OS\e[0m         : ${OS_VERSION}" echo -e "\e[1;36m│ \e[1;32m🐧 Kernel\e[0m     : ${KERNEL_VERSION} (${ARCH})" echo -e "\e[1;36m│ \e[1;32m⚙️  CPU\e[0m        : ${CPU_MODEL}" echo -e "\e[1;36m│ \e[1;32m⏳ Uptime\e[0m     : ${MY_UPTIME}" echo -e "\e[1;36m│ \e[1;32m🕒 Last Login\e[0m : ${LAST_LOGIN_TIME}" echo -e "\e[1;36m│ \e[1;32m🌐 Login IP\e[0m   : ${LAST_LOGIN_IP}" echo -e "\e[1;36m╰────────────────────────────────────────────────────────────────────────╯\e[0m" }

function mm() { local base used limit anon file slab_rec rss reclaimable used_mb limit_mb free_mb used_pct cpu_data cpu_used cpu_limit cpu_pct cpu_thr cpu_thr_pct cpu_thr_n cpu_psi_some cpu_psi_full cpu_sample avg30 disk_used disk_free home_items echo -e "\n\e[1;37m▶ SYSTEM MONITOR (Container Accurate)\e[0m\n\e[90m------------------------------------------------------------\e[0m" print_row() { echo -e " $1   \e[1;37m$(printf "%-6s" "$2")\e[0m \e[90m::\e[0m  \e[36m$(printf "%-16s" "$3")\e[0m \e[90m|\e[0m  \e[36m$(printf "%-16s" "$4")\e[0m \e[90m|\e[0m  \e[36m$(printf "%-16s" "$5")\e[0m"; } base="$(_cg_base)" if [ -n "$base" ]; then if [ -f "$base/memory.current" ]; then used=$(_cg_read "$base/memory.current"); limit=$(_cg_read "$base/memory.max"); else used=$(_cg_read "$base/memory.usage_in_bytes"); limit=$(_cg_read "$base/memory.limit_in_bytes"); fi else used=0; limit="max" fi anon=$(_cg_stat anon); [ -z "$anon" ] && anon=0 file=$(_cg_stat file); [ -z "$file" ] && file=0 slab_rec=$(_cg_stat slab_reclaimable); [ -z "$slab_rec" ] && slab_rec=0 rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print int(s/1024) "MB"}') reclaimable=$(((file + slab_rec) / 1024 / 1024)) used_mb=$((used / 1024 / 1024)) if [[ "$limit" =~ ^[0-9]+$ ]] && [ "$limit" -gt 0 ]; then limit_mb=$((limit / 1024 / 1024)); free_mb=$(((limit - used) / 1024 / 1024)); [ "$free_mb" -lt 0 ] && free_mb=0 used_pct=$(awk -v u="$used" -v l="$limit" 'BEGIN { if (l>0) printf "%.1f%%", (u/l)*100; else print "-" }') print_row "❖" "RAM" "${limit_mb}MB Max" "${used_mb}MB Used" "${free_mb}MB Free" else used_pct="unknown" print_row "❖" "RAM" "Unknown Max" "${used_mb}MB Used" "cgroup mode" fi print_row "≣" "CACHE" "$((file / 1024 / 1024))MB File" "$((anon / 1024 / 1024))MB Anon" "${rss} RSS" cpu_data="$(_cpu_measure "${PHOENIX_MM_CPU_SAMPLE_SECONDS:-2}")" IFS='|' read -r cpu_used cpu_limit cpu_pct cpu_thr cpu_thr_pct cpu_thr_n cpu_psi_some cpu_psi_full cpu_sample <<< "$cpu_data" avg30=$(_cpu_avg_history 30 2>/dev/null || true) if awk -v v="$cpu_limit" 'BEGIN { exit !(v>0) }'; then print_row "⚙" "CPU" "${cpu_limit} vCPU Max" "${cpu_used} vCPU ${cpu_sample}s" "${cpu_pct}% Limit"; else print_row "⚙" "CPU" "shared/auto" "${cpu_used} vCPU ${cpu_sample}s" "no fixed cap"; fi [ -z "$avg30" ] && avg30="$cpu_used" print_row "⌁" "CPU+" "${avg30} vCPU 30s" "${cpu_thr_pct}% Throttle" "${cpu_psi_some}% PSI10" disk_used=$(du -sh / --exclude=/proc --exclude=/sys --exclude=/dev 2>/dev/null | cut -f1); disk_free=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}') print_row "⛁" "DISK" "Container Use" "${disk_used:-?} Used" "${disk_free:-?} Free" home_items=$(find "$HOME" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ') print_row "▣" "HOME" "${home_items:-0} Items" "$USER" "$HOME" echo -e "\e[90m------------------------------------------------------------\e[0m" echo -e " \e[1;37mRAM%\e[0m    \e[90m::\e[0m  \e[36m${used_pct}\e[0m" echo -e " \e[1;37mCACHE\e[0m   \e[90m::\e[0m  \e[36m${reclaimable}MB likely reclaimable\e[0m" echo -e " \e[1;37mCPU NOW\e[0m \e[90m::\e[0m  \e[36m${cpu_used} vCPU (${cpu_sample}s avg)\e[0m" echo -e "\e[90m------------------------------------------------------------\e[0m\n" }

==========================================

Tailscale commands

==========================================

function cc() { if pgrep -x "tailscaled" > /dev/null; then echo -e "\e[1;33mℹ Tailscale daemon is running.\e[0m" else echo -e "\e[1;33m⌛ Starting Tailscale in background...\e[0m" nohup sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 > /dev/null 2>&1 & sleep 3 fi TS_KEY_FILE="$HOME/.ts_auth_key" TS_KEY="" if [ -f "$TS_KEY_FILE" ]; then echo -e "\n\e[1;36m🔑 Previous Key found!\e[0m" echo -e "  \e[1;32m1) Use previous Key\e[0m" echo -e "  \e[1;33m2) Enter new Key\e[0m" read -r -p "Option [1/2]: " OPTION if [ "$OPTION" = "1" ]; then TS_KEY=$(cat "$TS_KEY_FILE"); elif [ "$OPTION" = "2" ]; then read -r -p "New Key: " TS_KEY; [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"; else return 1; fi else read -r -p "Enter Tailscale Auth Key: " TS_KEY [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE" fi [ -z "$TS_KEY" ] && return 1 sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix }

function cs() { sudo tailscale logout 2>/dev/null || true sudo tailscale down 2>/dev/null || true sudo pkill -f tailscaled 2>/dev/null || true echo -e "\e[1;32m✔ Tailscale stopped.\e[0m\n" }

==========================================

DISK TOOLS

==========================================

function DISK() { echo -e "\n\e[1;37m💾 DISK USAGE (Full Container View)\e[0m" df -h --output=source,size,used,avail,pcent,target 2>/dev/null echo -e "\n\e[1;33m📂 Container Directory Usage:\e[0m" du -sh "$HOME" /tmp /var/log /var/cache /root 2>/dev/null | sort -hr echo -e "\n\e[1;32mRun: bigfiles | bigdirs | diskwhy | tmpclean\e[0m\n" }

function diskwhy() { local pct pct=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}') echo -e "\n\e[1;35m🔎 Disk Usage Diagnosis\e[0m" if [ -n "$pct" ] && [ "$pct" -ge 90 ] 2>/dev/null; then echo -e "\e[1;31m⚠ CRITICAL: Disk is ${pct}% full!\e[0m"; elif [ -n "$pct" ] && [ "$pct" -ge 70 ] 2>/dev/null; then echo -e "\e[1;33m⚠ WARNING: Disk is ${pct}% full.\e[0m"; else echo -e "\e[1;32m✔ Disk usage is healthy (${pct}% used).\e[0m"; fi echo -e "\nTop space consumers:" du -sh /home /root /tmp /var /usr 2>/dev/null | sort -hr | head -n 8 echo }

function bigfiles() { echo -e "\n\e[1;36m📦 Top 20 Largest Files\e[0m"; find / -xdev -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -n 20 | while read -r size path; do human=$(awk -v b="$size" 'BEGIN{ split("B KB MB GB",u," "); i=1; while(b>=1024&&i<4){b/=1024;i++} printf "%.1f %s", b, u[i] }'); printf "  %-10s  %s\n" "$human" "$path"; done; echo; } function bigdirs() { echo -e "\n\e[1;36m📁 Top 20 Largest Directories\e[0m"; du -hx --max-depth=4 / 2>/dev/null | sort -hr | grep -v "^0" | head -n 20; echo; } function tmpclean() { echo -e "\n\e[1;33m🧹 Cleaning temporary files...\e[0m"; rm -rf /tmp/* /tmp/.[!.]* /var/tmp/* 2>/dev/null || true; sync; echo -e "\e[1;32m✔ /tmp and /var/tmp cleaned.\e[0m"; df -h / | awk 'NR<=2'; echo; } function disklive() { echo -e "\e[1;36mLive disk monitor. Press Ctrl+C to stop.\e[0m"; sleep 1; while true; do clear; echo "⛁ LIVE DISK — $(date '+%H:%M:%S')"; DISK; sleep 2; done; }

==========================================

NETWORK TOOLS

==========================================

function NET() { echo -e "\n\e[1;37m🌐 NETWORK USAGE (Since Container Boot)\e[0m" awk 'NR>2 { iface=$1; gsub(/:/, "", iface); rx_bytes=$2; tx_bytes=$10; rx_pkts=$3; tx_pkts=$11; if (rx_bytes+tx_bytes > 0) { split("B KB MB GB TB", u, " "); rx=rx_bytes; ri=1; while(rx>=1024 && ri<5){rx/=1024; ri++}; tx=tx_bytes; ti=1; while(tx>=1024 && ti<5){tx/=1024; ti++}; printf "  %-12s RX:%-12s TX:%-12s RXp:%-10s TXp:%-10s\n", iface, sprintf("%.1f %s",rx,u[ri]), sprintf("%.1f %s",tx,u[ti]), rx_pkts, tx_pkts } }' /proc/net/dev echo -e "\nConnections:" echo "  TCP Established: $(ss -t 2>/dev/null | grep -c ESTAB || echo 0)" echo "  Listening Ports: $(ss -tln 2>/dev/null | grep -c LISTEN || echo 0)" echo -e "\nDNS:" grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{printf "  %s\n", $2}' | head -n 3 echo -e "\nIP Addresses:" ip -4 addr show 2>/dev/null | awk '/inet / {printf "  %-12s : %s\n", $NF, $2}' | head -n 5 echo -e "\nRun: netlive | netstats | netports | myip\n" }

function netlive() { echo -e "\e[1;36mLive network monitor. Press Ctrl+C to stop.\e[0m" local prev_rx prev_tx cur_rx cur_tx iface dl ul iface=$(ip -o link show 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}'); [ -z "$iface" ] && iface="eth0" prev_rx=$(awk -v iface="${iface}:" '$1==iface {print $2}' /proc/net/dev); prev_tx=$(awk -v iface="${iface}:" '$1==iface {print $10}' /proc/net/dev) while true; do sleep 1 cur_rx=$(awk -v iface="${iface}:" '$1==iface {print $2}' /proc/net/dev); cur_tx=$(awk -v iface="${iface}:" '$1==iface {print $10}' /proc/net/dev) dl=$(awk -v d="$((cur_rx - prev_rx))" 'BEGIN{ split("B/s KB/s MB/s GB/s",u," "); i=1; b=d; if(b<0)b=0; while(b>=1024&&i<4){b/=1024;i++}; printf "%.1f %s", b, u[i] }') ul=$(awk -v d="$((cur_tx - prev_tx))" 'BEGIN{ split("B/s KB/s MB/s GB/s",u," "); i=1; b=d; if(b<0)b=0; while(b>=1024&&i<4){b/=1024;i++}; printf "%.1f %s", b, u[i] }') printf "\r\e[1;36m[%s]\e[0m  \e[1;32m↓ DL: %-12s\e[0m  \e[1;33m↑ UL: %-12s\e[0m  iface: %s   " "$(date '+%H:%M:%S')" "$dl" "$ul" "$iface" prev_rx="$cur_rx"; prev_tx="$cur_tx" done }

function netstats() { echo -e "\n\e[1;36m📊 Detailed Network Statistics\e[0m"; ss -tan 2>/dev/null | awk 'NR>1 {states[$1]++} END {for(s in states) printf "  %-18s: %d\n", s, states[s]}' | sort -k2 -rn; echo -e "\nSocket Buffers:"; cat /proc/net/sockstat 2>/dev/null | sed 's/^/  /'; echo; } function netports() { echo -e "\n\e[1;36m🔌 Active Ports & Processes\e[0m"; sudo ss -tulpn 2>/dev/null; echo; } function dnslookup() { [ -z "$1" ] && echo -e "\e[1;31m✘ Usage: dnslookup <domain>\e[0m" && return 1; host -t A "$1"; host -t MX "$1"; host -t NS "$1"; }

==========================================

EXTRA SYSTEM TOOLS

==========================================

function proctree() { echo -e "\n\e[1;36m🌳 Process Tree\e[0m"; ps -eo pid=,ppid=,user=,%cpu=,%mem=,comm= --sort=ppid | head -n 30; echo; } function openfiles() { echo -e "\n\e[1;36m📂 Open File Descriptors per Process\e[0m"; for pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$' | sort -n); do fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l); comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?"); user=$(stat -c '%U' /proc/$pid 2>/dev/null || echo "?"); [ "$fd_count" -gt 5 ] 2>/dev/null && printf "  %-7s %-8s %-8s %s\n" "$pid" "$fd_count" "$user" "$comm"; done | sort -k2 -rn | head -n 20; echo; } function gitlog() { git log --oneline --graph --decorate --all -n 20 2>/dev/null || echo -e "\e[1;31m✘ Not a git repository.\e[0m"; } function uptime2() { local secs d h m s; secs=$(awk '{print int($1)}' /proc/uptime 2>/dev/null); d=$((secs/86400)); h=$(((secs%86400)/3600)); m=$(((secs%3600)/60)); s=$((secs%60)); echo -e "\n\e[1;36m⏱ System Uptime\e[0m"; printf "  %-20s : %s days, %s hours, %s mins, %s secs\n" "Host Uptime" "$d" "$h" "$m" "$s"; echo; } function envlist() { echo -e "\n\e[1;36m🌍 Environment Variables\e[0m"; env | sort; echo; } function syshealth() { uptime2; mm; DISK; NET; netstats; ramwhy; cpuwhy 2; }

==========================================

Clean login screen

==========================================

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then clear custom_motd mm echo -e "\e[1;33m🔥 Quick Actions:\e[0m" printf "   \e[1;32m%-10s\e[0m : %s\n" "cc" "Connect VPN" printf "   \e[1;32m%-10s\e[0m : %s\n" "ram" "Detailed RAM Info" printf "   \e[1;32m%-10s\e[0m : %s\n" "cpu5" "Steady CPU view" printf "   \e[1;32m%-10s\e[0m : %s\n" "DISK" "Full disk usage" printf "   \e[1;32m%-10s\e[0m : %s\n" "NET" "Network traffic info" printf "   \e[1;32m%-10s\e[0m : %s\n" "dcodex" "Show Codex status" printf "   \e[1;36m%-10s\e[0m : \e[1;36m%s\e[0m\n\n" "cmds" "View ALL Shortcuts ⚡" fi EOF

--------------------------------------------------

Prompt styling + install shell setup

--------------------------------------------------

RUN printf "\nexport PS1='\u@phoenix:\w$ '\n" >> /home/devuser/.bashrc 
&& printf "\nexport PS1='\u@phoenix:\w# '\n" >> /root/.bashrc 
&& cat /tmp/setup.sh >> /home/devuser/.bashrc 
&& cat /tmp/setup.sh >> /root/.bashrc 
&& chown devuser:devuser /home/devuser/.bashrc 
&& rm /tmp/setup.sh

--------------------------------------------------

Startup script

--------------------------------------------------

RUN cat > /start.sh <<'SH' #!/bin/bash set -e mkdir -p /var/run/sshd exec /usr/sbin/sshd -D -e SH

RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /home/devuser

EXPOSE 22

CMD ["/start.sh"]
