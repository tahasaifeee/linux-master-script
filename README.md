# Master Linux Tool

A universal, interactive Bash script for Linux system administration — works **everywhere**:  
Ubuntu, Debian, RHEL, CentOS, Rocky Linux, Fedora, OpenSUSE, and more.

Designed to survive **piped execution** (e.g., `curl ... | bash`) while remaining fully **interactive**.

---

## ✅ Features

- 🎯 Safe piped execution (uses `/dev/tty` for prompts)
- 🛡️ Graceful `Ctrl+C` (SIGINT) handling — returns to menu
- 🌐 Auto-detects distro, package manager, firewall, and network manager
- 📋 9 essential admin functions in one menu
- 📝 Logs all activity to `/var/log/master-linux-tool.log`
- 🎨 Colorized, user-friendly interface

---

## 🔧 Supported Linux Distributions

| Distribution | Versions |
|--------------|----------|
| **Debian** | 10+, including derivatives |
| **Ubuntu** | 18.04+ |
| **RHEL / CentOS / Rocky / Alma** | 7+ (preferably 8/9 for full feature support) |
| **Fedora** | 30+ |
| **OpenSUSE** | Leap 15+, Tumbleweed |

> ✅ Works over SSH, TTY, Docker (if `tty` available), and with `curl | bash`.

---

## 🚀 Installation & Usage

### Run directly (no install needed):

Recommended (secure-ish, uses bash -c to ensure the script gets a proper argv/env and supports tty):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/master-linux-tool.sh)"
```

One-line (classic "one-click") options — choose one:

- Run with curl and bash (non-sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/master-linux-tool.sh | bash
```

- Run with curl and bash as root (if the script requires elevated privileges):

```bash
curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/master-linux-tool.sh | sudo bash
```

- Run with wget:

```bash
wget -qO- https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/master-linux-tool.sh | bash
```

Notes:
- The script is designed to be safe for piped execution and reads prompts from `/dev/tty` when needed.
- Review the script before running if you have security concerns: https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/master-linux-tool.sh

---

## 🔎 What it does

(keep existing or add a description here explaining the 9 admin functions, logging behavior, and how the menu works)

---

(keep the rest of the README as-is or update other sections if desired)
