# Home‑Server Weekly Maintenance – **Beginner‑Friendly Guide**

This guide shows you—**even if you’re brand new to Linux**—how to set up a weekly “housekeeping” task on an Ubuntu server.  In plain English you will:

1. **Keep Ubuntu up‑to‑date** (security patches & new features).
2. **Refresh your Docker apps** (so Plex, Jellyfin, Home‑Assistant, etc. pull the latest images).
3. **Clean old Docker junk** (free disk space automatically).
4. **Check disk health** (SMART) and log everything.
5. **Get an email or phone alert** if the job ever fails (via *Healthchecks.io*).

Everything runs hands‑free once a week—no more manual `apt upgrade` or guessing when to do `docker compose pull`.

---

## 0. What You Need Before You Start

| Item                                 | Why you need it                                      | Quick command                                      |
| ------------------------------------ | ---------------------------------------------------- | -------------------------------------------------- |
| **Ubuntu Server 22.04 LTS or later** | The guide assumes Ubuntu; Debian also works.         | `lsb_release -a`                                   |
| **Docker & Compose v2**              | To run container apps.                               | `sudo apt install docker.io docker-compose-plugin` |
| **Git**                              | To download the files from GitHub.                   | `sudo apt install git`                             |
| **A free *Healthchecks.io* account** | Sends you an alert when the job fails or is late.    | Sign‑up in browser                                 |
| **Basic terminal access**            | You’ll copy‑paste commands via SSH or local console. | –                                                  |

> **Tip:** Anything that starts with `sudo` will ask for your **Ubuntu password**. That’s normal.

---

## 1. Download the project

```bash
# Go to your home folder (safe place)
cd ~
# Clone this repo (replace YOURNAME with your GitHub username if you fork it)
git clone https://github.com/YOURNAME/homeserver-maint.git
cd homeserver-maint
```

Project structure:

```
homeserver-maint/
├── scripts/                ← shell script that does the work
├── systemd/                ← files that tell Ubuntu _when_ to run the script
├── logrotate/              ← keeps logs small
└── README.md               ← this guide
```

---

## 2. Tell Ubuntu what to do (install files)

```bash
# 1) Copy the main script into a system folder and make it runnable
sudo install -m 750 scripts/homeserver-maint.sh /usr/local/sbin/

# 2) Add log‑rotation rule so logs don’t fill your disk
sudo install -m 644 logrotate/homeserver-maint /etc/logrotate.d/

# 3) Add the service + timer so systemd can run it weekly
sudo install -m 644 systemd/homeserver-maint.{service,timer} /etc/systemd/system/

# 4) Reload systemd to detect new files
sudo systemctl daemon-reload

# 5) Start the timer right now (and after every reboot)
sudo systemctl enable --now homeserver-maint.timer
```

You’re 90 % done!  The job is now scheduled for **Sunday, 03:30 AM** (local time).  Feel free to edit `systemd/homeserver-maint.timer` before step 3 if you want a different schedule.

---

## 3. Set up failure alerts (Healthchecks)

1. Log into **[https://healthchecks.io](https://healthchecks.io)**  ➜ **Add Check** ➜ copy the *Ping URL*.
2. Edit the script:

   ```bash
   sudo nano /usr/local/sbin/homeserver-maint.sh
   ```
3. Near the top you’ll see:

   ```bash
   HC_URL="https://hc-ping.com/<YOUR-UUID>"
   ```

   Replace the placeholder with the URL you copied.  **Save & exit** (in nano: `Ctrl‑O`, `Enter`, `Ctrl‑X`).
4. Run a manual test to send the first “success” ping:

   ```bash
   sudo systemctl start homeserver-maint.service
   ```

   Check your Healthchecks dashboard—should be **green**.

---

## 4. How to Check Everything Is Working

| What you want           | Command to type                                     | What you should see                 |
| ----------------------- | --------------------------------------------------- | ----------------------------------- |
| **See next run time**   | `systemctl list-timers homeserver-maint.timer`      | Date & time for next Sunday.        |
| **Run it right now**    | `sudo systemctl start homeserver-maint.service`     | Job runs; no errors.                |
| **Watch live logs**     | `tail -f /var/log/homeserver-maint/$(date +%F).log` | Scrolling output of each step.      |
| **Healthchecks status** | visit dashboard                                     | Green ✓ = OK, Red ✖ = missed/failed |

---

## 5. Want More? (Optional extensions)

* **Daily security patches** – run once:
  `sudo dpkg-reconfigure unattended-upgrades`
* **Automatic backups** – add your `restic` or `borgbackup` command near the top of `homeserver-maint.sh` **before** the `apt-get` lines.
* **Deep SMART test** – add a monthly cron line:
  `smartctl -t long /dev/sda` (replace sda). Check results next time.
* **Snapshots (ZFS/Btrfs)** – snapshot volumes right before the Docker redeploy block.

---

## 6. Troubleshooting (copy‑paste answers)

| Problem you see                              | Reason                            | Quick fix                                                                   |
| -------------------------------------------- | --------------------------------- | --------------------------------------------------------------------------- |
| **Healthchecks says “Late”**                 | Timer never ran                   | `systemctl status homeserver-maint.timer` (enable/start)                    |
| **Service exit code 100**                    | Bad APT repo changed its codename | Remove the repo or keep `AllowReleaseInfoChange` flags (already in script). |
| **Containers didn’t redeploy**               | Compose YAML has relative paths   | Script runs `cd "$dir"` so pull + up happens in correct folder.             |
| **Docker prune error about `unused` filter** | Older Docker version              | Script already uses safe `docker volume prune -f`.                          |

If something still looks off, read the latest log in `/var/log/homeserver-maint/`—the error will be near the bottom.

---

## 7. Un‑install (if you ever change your mind)

```bash
sudo systemctl disable --now homeserver-maint.timer
sudo rm /etc/systemd/system/homeserver-maint.{service,timer}

sudo rm /usr/local/sbin/homeserver-maint.sh
sudo rm /etc/logrotate.d/homeserver-maint
sudo rm -r /var/log/homeserver-maint  # optional, removes old logs
sudo systemctl daemon-reload
```

---

## 8. License

MIT – feel free to copy, adapt, and share.

Happy automating!  🙂
