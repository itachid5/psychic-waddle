FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

--------------------------------------------------

Base system packages

No top-level ENV lines are used in this Dockerfile.

This avoids Railway/Docker parser errors like:

"ENV must be of the form: name=value"

--------------------------------------------------

RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Asia/Dhaka apt-get install -y --no-install-recommends 
tzdata openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils 
lsof htop jq speedtest-cli unzip tree python3 python3-pip 
ca-certificates gnupg tmux screen vim zip rsync socat telnet ncdu 
&& ln -snf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime 
&& echo Asia/Dhaka > /etc/timezone 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/* /root/.cache/pip

--------------------------------------------------

Install Tailscale

--------------------------------------------------

RUN curl -fsSL https://tailscale.com/install.sh | sh 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

--------------------------------------------------

Install cloudflared

--------------------------------------------------

RUN mkdir -p /usr/share/keyrings 
&& curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg 
&& echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main" > /etc/apt/sources.list.d/cloudflared.list 
&& apt-get update 
&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cloudflared 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

--------------------------------------------------

Install Node.js LTS + Codex

--------------------------------------------------

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 
&& apt-get install -y --no-install-recommends nodejs 
&& npm config set audit false 
&& npm config set fund false 
&& npm config set update-notifier false 
&& npm i -g @openai/codex --cache /tmp/.npm-cache --no-audit --no-fund 
&& npm cache clean --force 
&& rm -rf /tmp/.npm-cache /root/.npm /root/.cache/npm /root/.cache/node-gyp 
&& apt-get clean 
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

--------------------------------------------------

SSH + users

Password login + SSH key login enabled

StrictModes disabled for easier login

--------------------------------------------------

RUN mkdir -p /var/run/sshd /run/sshd /etc/ssh/sshd_config.d 
&& useradd -m -s /bin/bash -u 1000 devuser 
&& echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 
&& echo "devuser:123456" | chpasswd 
&& echo "root:123456" | chpasswd 
&& mkdir -p /home/devuser/.ssh /root/.ssh 
&& printf '%s\n' 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl/8uY6DFHrP7QB/Nowv3oHceyUpq0QjL/lVLA45Vf7 runner@cb615ad88875' > /home/devuser/.ssh/authorized_keys 
&& cp /home/devuser/.ssh/authorized_keys /root/.ssh/authorized_keys 
&& chown -R devuser:devuser /home/devuser/.ssh 
&& chown -R root:root /root/.ssh 
&& chmod 700 /home/devuser/.ssh /root/.ssh 
&& chmod 600 /home/devuser/.ssh/authorized_keys /root/.ssh/authorized_keys 
&& sed -i -E 's/^\s*(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication|AuthorizedKeysFile|StrictModes|UsePAM)\s+/# disabled-by-phoenix \0/' /etc/ssh/sshd_config 
&& { 
echo 'PasswordAuthentication yes'; 
echo 'PermitRootLogin yes'; 
echo 'PubkeyAuthentication yes'; 
echo 'AuthorizedKeysFile .ssh/authorized_keys'; 
echo 'StrictModes no'; 
echo 'UsePAM yes'; 
} > /etc/ssh/sshd_config.d/99-phoenix-login.conf

--------------------------------------------------

Disable default MOTD noise

--------------------------------------------------

RUN rm -rf /etc/update-motd.d/* 
&& rm -f /etc/legal /etc/motd 
&& touch /home/devuser/.hushlogin /root/.hushlogin 
&& chown devuser:devuser /home/devuser/.hushlogin

--------------------------------------------------

Prompt styling

--------------------------------------------------

RUN echo "export PS1='\u@phoenix\e[0m:\w\e[0m$ '" >> /home/devuser/.bashrc 
&& echo "export PS1='\u@phoenix\e[0m:\w\e[0m# '" >> /root/.bashrc

--------------------------------------------------

Main shell setup

No backup/restore and no virtual environment helpers.

--------------------------------------------------

RUN cat > /tmp/setup.sh <<'EOF'

==========================================

Phoenix shortcuts

==========================================

alias c='clear' alias ..='cd ..' alias ...='cd ../..' alias ll='ls -alF --color=auto' alias la='ls -A --color=auto' alias md='mkdir -p' alias sz='du -sh * 2>/dev/null | sort -hr' alias tree='tree -C' alias f='find . -name' alias grep='grep --color=auto' alias h='history' alias dsize='du -h --max-depth=1 | sort -hr' alias chmodx='chmod +x' alias chownme='sudo chown -R $USER:$USER .' alias path='echo -e ${PATH//:/\n}'

alias up='sudo apt-get update && sudo apt-get upgrade -y' alias clean='sudo apt-get autoremove -y && sudo apt-get clean && reclaimram' alias mem='ram' alias hostmem='free -h' alias cpu='cpuuse' alias df='df -h' alias top='htop' alias ports='sudo netstat -tulpn' alias logs='sudo tail -f /var/log/syslog' alias rst='source ~/.bashrc && echo -e "\e[1;32m✔ Terminal Reloaded!\e[0m"' alias sysinfo='cat /etc/os-release' alias cpuinfo='lscpu' alias myports='ss -tuln' alias histg='history | grep'

alias myip='echo -e "\n\e[1;36m🌐 IP Details:\e[0m"; curl -s ipinfo.io; echo' alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple' alias ping='ping -c 4' alias ts='sudo tailscale status' alias pinger='ping -c 4 8.8.8.8' alias serve='python3 -m http.server 8000'

alias gs='git status' alias ga='git add .' alias gc='git commit -m' alias gp='git push' alias gl='git log --oneline --graph -n 10' alias get='wget -c' alias api='curl -s' alias weather='curl -s wttr.in/Dhaka?0'

alias apps='echo -e "\n\e[1;36m▶ Codex / Node / Python Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[c]odex|[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"' alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"' alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"' alias kcodex='sudo pkill -f codex 2>/dev/null; echo -e "\e[1;32m✔ All Codex processes stopped.\e[0m"'

CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts" if [ -f "$CUSTOM_ALIAS_FILE" ]; then source "$CUSTOM_ALIAS_FILE" fi

function addcmd() { echo -e "\n\e[1;36m➕ Create a New Shortcut\e[0m" read -p "Shortcut Name: " S_NAME [ -z "$S_NAME" ] && echo -e "\e[1;31m✘ Name cannot be empty.\e[0m" && return 1 grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null && echo -e "\e[1;33mShortcut already exists.\e[0m" && return 1 read -p "Command to run: " S_CMD [ -z "$S_CMD" ] && echo -e "\e[1;31m✘ Command cannot be empty.\e[0m" && return 1 echo "alias $S_NAME='$S_CMD'" >> "$CUSTOM_ALIAS_FILE" eval "alias $S_NAME='$S_CMD'" echo -e "\e[1;32m✔ Shortcut '$S_NAME' created.\e[0m" }

function delcmd() { echo -e "\n\e[1;31m🗑️ Delete a Custom Shortcut\e[0m" read -p "Shortcut Name to delete: " S_NAME [ -z "$S_NAME" ] && echo -e "\e[1;31m✘ Name cannot be empty.\e[0m" && return 1 grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null || echo -e "\e[1;33mShortcut not found.\e[0m" sed -i "/alias $S_NAME=/d" "$CUSTOM_ALIAS_FILE" 2>/dev/null || true unalias "$S_NAME" 2>/dev/null || true echo -e "\e[1;32m✔ Shortcut deleted.\e[0m" }

function pcmd() { printf "   \e[1;32m%-14s\e[0m : %s\n" "$1" "$2" }

function cmds() { echo -e "\n\e[1;37m⚡ Phoenix Shortcuts ⚡\e[0m" echo -e "\e[90m──────────────────────────────────────────────\e[0m" pcmd "c" "Clear screen" pcmd "ll" "List files with details" pcmd "sz" "Show sizes here" pcmd "mkcd <dir>" "Make directory and enter" pcmd "findtext <txt>" "Search text inside files" pcmd "ram" "Container RAM summary" pcmd "ramtop" "Top RAM processes" pcmd "reclaimram" "Clean apt/pip/npm cache" pcmd "cpu" "CPU process view" pcmd "DISK" "Disk usage" pcmd "bigfiles" "Largest files" pcmd "bigdirs" "Largest directories" pcmd "tmpclean" "Clean temp files" pcmd "NET" "Network usage" pcmd "netports" "Ports with process" pcmd "cc" "Connect Tailscale" pcmd "cs" "Disconnect Tailscale" pcmd "apps" "List Codex/Node/Python apps" pcmd "kport <port>" "Kill app on port" pcmd "dcodex" "Codex status" pcmd "dpy" "Python/Pip status" pcmd "dgo" "Install Golang runtime" pcmd "djava" "Install Java 17 runtime" pcmd "syshealth" "Full health report" pcmd "addcmd" "Create personal shortcut" pcmd "delcmd" "Delete personal shortcut" echo -e "\e[90m──────────────────────────────────────────────\e[0m\n" }

function mkcd() { mkdir -p "$1" && cd "$1" }

function findtext() { grep -rnw . -e "$1" }

function kport() { if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: kport <port>\e[0m" return 1 fi PID=$(sudo lsof -t -i:"$1") if [ -z "$PID" ]; then echo -e "\e[1;33mℹ Port $1 is free\e[0m" else sudo kill -9 $PID echo -e "\e[1;32m✔ Killed process on port $1\e[0m" fi }

function ex() { if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: ex <filename>\e[0m" return 1 fi if [ -f "$1" ]; then case "$1" in *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;; *.bz2) bunzip2 "$1" ;; *.gz) gunzip "$1" ;; *.tar) tar xf "$1" ;; *.zip) unzip "$1" ;; *) echo -e "\e[1;31m✘ Cannot extract '$1'\e[0m" ;; esac else echo -e "\e[1;31m✘ '$1' is not a valid file\e[0m" fi }

function _b2h() { awk -v b="${1:-0}" 'BEGIN{ split("B KB MB GB TB",u," "); i=1; while (b>=1024 && i<5) { b/=1024; i++ } printf "%.1f %s", b, u[i] }' }

function ram() { echo -e "\n\e[1;36m📊 RAM\e[0m" echo -e "\e[90m──────────────────────────────────────────────\e[0m" free -h echo -e "\e[90m──────────────────────────────────────────────\e[0m" echo -e "\e[1;33mTop RAM processes:\e[0m" ps -eo pid,user,%mem,rss,comm --sort=-rss | head -n 12 echo }

function ramtop() { ps -eo pid,user,%mem,rss,comm --sort=-rss | head -n 20 }

function reclaimram() { echo -e "\n\e[1;33m🧹 Cleaning package/cache files...\e[0m" npm cache clean --force >/dev/null 2>&1 || true python3 -m pip cache purge >/dev/null 2>&1 || true sudo apt-get clean >/dev/null 2>&1 || true rm -rf "$HOME/.npm" "$HOME/.cache/npm" "$HOME/.cache/node-gyp" "$HOME/.cache/pip" /tmp/.npm-cache /tmp/pip-* /tmp/pip-build-* /tmp/pip-install-* /var/tmp/* 2>/dev/null || true sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/*.bin 2>/dev/null || true sync echo -e "\e[1;32m✔ Cache cleaned.\e[0m" ram }

function cpuuse() { echo -e "\n\e[1;36m⚙ CPU / Processes\e[0m" echo -e "\e[90m──────────────────────────────────────────────\e[0m" uptime echo ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu | head -n 15 echo }

function DISK() { echo -e "\n\e[1;36m💾 Disk Usage\e[0m" echo -e "\e[90m──────────────────────────────────────────────\e[0m" df -h / echo du -sh /home /root /tmp /var /usr 2>/dev/null | sort -hr echo echo -e "Run: bigfiles | bigdirs | tmpclean" }

function bigfiles() { echo -e "\n\e[1;36m📦 Top 20 Largest Files\e[0m" find / -xdev -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -n 20 | while read -r size path; do human=$(_b2h "$size") printf "  %-10s  %s\n" "$human" "$path" done echo }

function bigdirs() { echo -e "\n\e[1;36m📁 Top 20 Largest Directories\e[0m" du -hx --max-depth=4 / 2>/dev/null | sort -hr | grep -v "^0" | head -n 20 echo }

function tmpclean() { echo -e "\n\e[1;33m🧹 Cleaning temporary files...\e[0m" find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true sync echo -e "\e[1;32m✔ /tmp and /var/tmp cleaned.\e[0m" df -h / echo }

function NET() { echo -e "\n\e[1;36m🌐 Network Usage\e[0m" echo -e "\e[90m──────────────────────────────────────────────\e[0m" ip -4 addr show 2>/dev/null | awk '/inet / {printf "  %-12s : %s\n", $NF, $2}' echo awk 'NR>2 {iface=$1; gsub(/:/,"",iface); if($2+$10>0) printf "  %-10s RX: %-12s TX: %-12s\n", iface, $2, $10}' /proc/net/dev echo echo -e "Run: netports | myip | speed" }

function netports() { echo -e "\n\e[1;36m🔌 Active Ports & Processes\e[0m" sudo ss -tulpn 2>/dev/null || ss -tuln echo }

function dcodex() { echo -e "\n\e[1;36m🤖 Codex Status\e[0m" if command -v codex >/dev/null 2>&1; then echo -e "\e[1;32m✔ Codex installed.\e[0m" echo -e "Codex: $(codex --version 2>/dev/null || echo installed)" echo -e "Node : $(node -v 2>/dev/null || echo missing)" echo -e "NPM  : $(npm -v 2>/dev/null || echo missing)" else echo -e "\e[1;31m✘ Codex not found.\e[0m" return 1 fi echo }

function dpy() { echo -e "\n\e[1;36m🐍 Python/Pip Status\e[0m" python3 --version 2>&1 || true pip3 --version 2>&1 || true echo }

function dgo() { echo -e "\n\e[1;36m🐹 Installing Golang...\e[0m" sudo apt-get update && sudo apt-get install -y --no-install-recommends golang sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* go version }

function djava() { echo -e "\n\e[1;36m☕ Installing Java 17...\e[0m" sudo apt-get update && sudo apt-get install -y --no-install-recommends openjdk-17-jdk openjdk-17-jre sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* java -version }

function cc() { if ! pgrep -x "tailscaled" >/dev/null; then echo -e "\e[1;33m⌛ Starting Tailscale...\e[0m" nohup sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 >/dev/null 2>&1 & sleep 3 fi

TS_KEY_FILE="$HOME/.ts_auth_key"
TS_KEY=""

if [ -f "$TS_KEY_FILE" ]; then
    echo -e "\n\e[1;36mPrevious Tailscale key found.\e[0m"
    echo -e "1) Use previous key"
    echo -e "2) Enter new key"
    read -p "Option [1/2]: " OPTION
    if [ "$OPTION" = "1" ]; then
        TS_KEY=$(cat "$TS_KEY_FILE")
    else
        read -p "New key: " TS_KEY
        [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
    fi
else
    read -p "Enter Tailscale Auth Key: " TS_KEY
    [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
fi

[ -z "$TS_KEY" ] && return 1
sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix

}

function cs() { sudo tailscale logout 2>/dev/null || true sudo tailscale down 2>/dev/null || true sudo pkill -f tailscaled 2>/dev/null || true echo -e "\e[1;32m✔ Tailscale stopped.\e[0m" }

function custom_motd() { OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2) KERNEL_VERSION=$(uname -r) ARCH=$(uname -m) UPTIME_SEC=$(ps -o etimes= -p 1 2>/dev/null | xargs) h=$((UPTIME_SEC / 3600)) m=$(((UPTIME_SEC % 3600) / 60))

echo -e "\e[1;36m╭──────────────────────────────────────────────╮\e[0m"
echo -e "\e[1;36m│ \e[1;37m🔥 Welcome to Phoenix Server 🔥\e[0m            "
echo -e "\e[1;36m├──────────────────────────────────────────────┤\e[0m"
echo -e "\e[1;36m│ \e[1;32mOS\e[0m      : ${OS_VERSION}"
echo -e "\e[1;36m│ \e[1;32mKernel\e[0m  : ${KERNEL_VERSION} (${ARCH})"
echo -e "\e[1;36m│ \e[1;32mUptime\e[0m  : ${h}h ${m}m"
echo -e "\e[1;36m╰──────────────────────────────────────────────╯\e[0m"

}

function mm() { custom_motd echo -e "\n\e[1;37m▶ Quick System Monitor\e[0m" echo -e "\e[90m──────────────────────────────────────────────\e[0m" free -h | awk 'NR<=2' df -h / | awk 'NR<=2' echo -e "\e[90m──────────────────────────────────────────────\e[0m" echo -e "Run: cmds | ram | cpu | DISK | NET | dcodex" echo }

function syshealth() { mm ram cpuuse DISK NET }

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then clear mm echo -e "\e[1;33m🔥 Quick Actions:\e[0m" printf "   \e[1;32m%-10s\e[0m : %s\n" "cc" "Connect VPN" printf "   \e[1;32m%-10s\e[0m : %s\n" "ram" "RAM info" printf "   \e[1;32m%-10s\e[0m : %s\n" "cpu" "CPU/process view" printf "   \e[1;32m%-10s\e[0m : %s\n" "DISK" "Disk usage" printf "   \e[1;32m%-10s\e[0m : %s\n" "NET" "Network info" printf "   \e[1;32m%-10s\e[0m : %s\n" "dcodex" "Codex status" printf "   \e[1;36m%-10s\e[0m : \e[1;36m%s\e[0m\n\n" "cmds" "View all shortcuts" fi EOF

RUN cat /tmp/setup.sh >> /home/devuser/.bashrc 
&& cat /tmp/setup.sh >> /root/.bashrc 
&& chown devuser:devuser /home/devuser/.bashrc 
&& rm /tmp/setup.sh

--------------------------------------------------

Startup script

--------------------------------------------------

RUN cat > /start.sh <<'SH' #!/bin/bash set -e

mkdir -p /var/run/sshd /run/sshd ssh-keygen -A exec /usr/sbin/sshd -D -e SH

RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /home/devuser EXPOSE 22 CMD ["/start.sh"]
