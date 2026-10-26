#!/bin/bash
# ติดตั้งแบบ "มีเน็ต" เลือกได้ทีละส่วน (Ubuntu 22.04)
#
# วิธีใช้:
#   sudo bash setup-online.sh                  -> ขึ้นเมนู พิมพ์เลข เช่น 1 3 5
#   sudo bash setup-online.sh docker node      -> ระบุชื่อตรงๆ
#   sudo bash setup-online.sh all              -> ลงทั้งหมด
# ชื่อที่ใช้ได้: docker node emqx mysql nodered all

MYSQL_PASS="1234"
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "กรุณารันด้วย root: sudo bash $0"
  exit 1
fi

SEL="$*"
if [ -z "$SEL" ]; then
  echo "เลือกสิ่งที่จะติดตั้ง (พิมพ์เลขคั่นด้วยเว้นวรรค เช่น 1 3 5)"
  echo "  1) Docker"
  echo "  2) Node.js 22"
  echo "  3) EMQX (MQTT)"
  echo "  4) MySQL"
  echo "  5) Node-RED"
  echo "  6) ทั้งหมด"
  read -r -p "เลือก: " CHOICE
  for n in $CHOICE; do
    case "$n" in
      1) SEL="$SEL docker" ;;
      2) SEL="$SEL node" ;;
      3) SEL="$SEL emqx" ;;
      4) SEL="$SEL mysql" ;;
      5) SEL="$SEL nodered" ;;
      6) SEL="all" ;;
    esac
  done
fi
[ "$SEL" = "all" ] && SEL="docker node emqx mysql nodered"

want() { echo " $SEL " | grep -q " $1 "; }

if want emqx || want mysql || want nodered; then
  want docker || SEL="$SEL docker"
fi

apt-get update -y
apt-get install -y curl ca-certificates gnupg

if want docker; then
  echo "===== Docker ====="
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi
  systemctl enable --now docker
  docker --version
fi

if want node; then
  echo "===== Node.js 22 ====="
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
  node -v
  npm -v
fi

if want emqx; then
  echo "===== EMQX ====="
  docker rm -f emqx 2>/dev/null
  docker run -d --name emqx --restart always \
    -p 1883:1883 -p 8083:8083 -p 8084:8084 -p 8883:8883 -p 18083:18083 \
    -v emqx_data:/opt/emqx/data \
    emqx/emqx:5
fi

if want mysql; then
  echo "===== MySQL ====="
  docker rm -f mysql 2>/dev/null
  docker run -d --name mysql --restart always \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_PASS" \
    -e MYSQL_DATABASE=iotdb \
    -v mysql_data:/var/lib/mysql \
    mysql:8
fi

if want nodered; then
  echo "===== Node-RED ====="
  docker rm -f nodered 2>/dev/null
  docker run -d --name nodered --restart always \
    -p 1880:1880 \
    -v nodered_data:/data \
    nodered/node-red:latest
  sleep 8
  docker exec nodered npm install --prefix /data node-red-node-mysql \
    && docker restart nodered
fi

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  for p in 1880 1883 18083 3306; do ufw allow ${p}/tcp; done
fi

echo
command -v docker >/dev/null 2>&1 && docker ps
IP=$(hostname -I | awk '{print $1}')
echo
want nodered && echo "Node-RED : http://$IP:1880"
want emqx    && echo "EMQX     : http://$IP:18083  (admin / public)  MQTT: $IP:1883"
want mysql   && echo "MySQL    : $IP:3306  (root / $MYSQL_PASS)"
exit 0
