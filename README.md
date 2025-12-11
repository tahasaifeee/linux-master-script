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

```bash
curl -sSL https://raw.githubusercontent.com/<user>/<repo>/main/master-linux-tool.sh | bash
