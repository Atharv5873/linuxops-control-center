#!/bin/bash
set -euo pipefail

# =========================
# System & Metadata
# =========================

get_hostname() {
  hostname 2>/dev/null || echo "unknown"
}

get_uptime_seconds() {
  awk '{print int($1)}' /proc/uptime 2>/dev/null || echo "unknown"
}

# =========================
# CPU Metrics
# =========================

get_cpu_usage_percent() {
  top -bn1 | awk '/Cpu\(s\)/ {print 100 - $8}' 2>/dev/null || echo "unknown"
}

get_load_average() {
  awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || echo "unknown unknown unknown"
}

# =========================
# Memory Metrics
# =========================

get_memory_stats() {
  free -m | awk '
    /Mem:/ {
      total=$2; used=$3; free=$4;
      used_percent=(used/total)*100;
      printf "%d %d %d %.2f\n", total, used, free, used_percent
    }
  ' 2>/dev/null || echo "unknown unknown unknown unknown"
}

# =========================
# Disk Metrics (Root FS)
# =========================

get_disk_stats() {
  df -BG / | awk '
    NR==2 {
      gsub("G","",$2); gsub("G","",$3); gsub("%","",$5);
      printf "%d %d %d\n", $2, $3, $5
    }
  ' 2>/dev/null || echo "unknown unknown unknown"
}

get_inode_usage_percent() {
  df -i / | awk 'NR==2 {gsub("%","",$5); print $5}' 2>/dev/null || echo "unknown"
}

# =========================
# Process Metrics
# =========================

get_top_cpu_processes() {
  ps -eo pid=,comm=,%cpu= --sort=-%cpu | head -n 3 | \
  awk '
  {
    pid=$1
    cpu=$NF
    name=""
    for (i=2; i<NF; i++) {
      name = name (i==2 ? "" : " ") $i
    }
    printf "%s|%s|%s\n", pid, name, cpu
  }' 2>/dev/null || true
}

get_top_memory_processes() {
  ps -eo pid=,comm=,%mem= --sort=-%mem | head -n 3 | \
  awk '
  {
    pid = $1
    mem = $NF
    name = ""
    for (i = 2; i < NF; i++) {
      name = name (i == 2 ? "" : " ") $i
    }
    printf "%s|%s|%s\n", pid, name, mem
  }' 2>/dev/null || true
}



get_top_cpu_processes_json() {
  get_top_cpu_processes | \
  awk -F'|' '
  {
    printf "{\"pid\":%d,\"name\":\"%s\",\"cpu_percent\":%s}\n", $1, $2, $3
  }' | jq -s .
}

get_top_memory_processes_json() {
  get_top_memory_processes | \
  awk -F'|' '
  {
    printf "{\"pid\":%d,\"name\":\"%s\",\"mem_percent\":%s}\n", $1, $2, $3
  }' | jq -s .
}



# =========================
# Service Health
# =========================

get_service_status() {
  local input="$1"

  for unit in "$input.service" "${input%d}.service" "ssh.service"; do
    if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "$unit"; then
      systemctl is-active "$unit" >/dev/null 2>&1 && echo active || echo inactive
      return
    fi
  done

  echo "unknown"
}
