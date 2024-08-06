#!/bin/bash

PROXY_EXPIRATION_LOG="/root/proxyserver/proxy_expiration.log"

function show_menu() {
    local proxy_count=$(count_proxies)
    echo "Menu Quản Lý Máy Chủ Proxy IPv6"
    echo "1. Cài đặt và cấu hình máy chủ proxy"
    echo "2. Cấu hình lại máy chủ proxy"
    echo "3. Gỡ cài đặt máy chủ proxy"
    echo "4. Lấy thông tin về máy chủ proxy đang chạy (Hiện có $proxy_count proxy)"
    echo "5. Random số lượng proxy (mặc định 100)"
    echo "6. Thoát"
    echo "9. Cập nhật hệ thống và cài đặt các gói cần thiết"
    echo "10. Random 1000 proxy xoay 1 phút"
    echo "11. Random 1000 proxy xoay 5 phút"
    echo "12. Random 1000 proxy xoay 10 phút"
    echo "39. Random 100 proxy với thời gian 5 phút hết hạn"
    echo "50. Hiển thị thông tin proxy hết hạn"
    echo "51. Gia hạn proxy cho từng port cụ thể"
    echo "81. Nhập port cần chặn"
    echo "82. Mở khóa port đã chặn"
    echo "83. Hiện thông tin chặn"
    echo "84. Mở khóa nhanh tất cả đã chặn"
    echo "89. Thoát"
}

function count_proxies() {
    local PROXY_FILE="/root/proxyserver/backconnect_proxies.list"
    if [ -f "$PROXY_FILE" ]; then
        local count=$(wc -l < "$PROXY_FILE")
        echo $count
    else
        echo 0
    fi
}

function generate_random_string() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c $1 ; echo ''
}

function upload_proxy_list() {
    local PROXY_FILE="/root/proxyserver/backconnect_proxies.list"
    if [ -f "$PROXY_FILE" ]; then
        local ZIP_FILE="/root/proxyserver/backconnect_proxies.zip"
        local ZIP_PASSWORD=$(generate_random_string 6)
        zip -P $ZIP_PASSWORD $ZIP_FILE $PROXY_FILE

        local UPLOAD_RESPONSE=$(curl -s --upload-file $ZIP_FILE https://bashupload.com/$ZIP_FILE)
        local DOWNLOAD_LINK=$(echo $UPLOAD_RESPONSE | grep -o 'https://bashupload.com/[^ ]*')

        echo "You can download the zipped proxy list from: $DOWNLOAD_LINK"
        echo "The password for the zip file is: $ZIP_PASSWORD"
        echo "Bạn có thể tải danh sách proxy đã nén từ: $DOWNLOAD_LINK"
        echo "Mật khẩu cho file zip là: $ZIP_PASSWORD"
    else
        echo "Proxy list file not found!"
        echo "Không tìm thấy file danh sách proxy!"
    fi
}

function log_proxy_expiration() {
    local proxy_count=$1
    local expiration_minutes=$2
    local expiration_date=$(date -d "+$expiration_minutes minutes" +"%Y-%m-%d %H:%M:%S")
    local start_port=10000
    mkdir -p /root/proxyserver
    for ((i=0; i<$proxy_count; i++)); do
        local port=$((start_port + i))
        echo "Port: $port, Expiration date: $expiration_date" >> $PROXY_EXPIRATION_LOG
    done
}

function configure_proxy_server() {
    local subnet proxy_count username password proxies_type rotating_interval expiration_days
    read -p "Nhập subnet (mặc định 64): " subnet
    subnet=${subnet:-64}
    read -p "Nhập số lượng proxy (mặc định 10): " proxy_count
    proxy_count=${proxy_count:-10}
    read -p "Nhập tên đăng nhập (mặc định random): " username
    username=${username:-$(generate_random_string 8)}
    echo "Tên đăng nhập: $username"
    read -p "Nhập mật khẩu (mặc định random): " password
    password=${password:-$(generate_random_string 8)}
    echo "Mật khẩu: $password"
    read -p "Nhập loại proxy (http/socks5, mặc định http): " proxies_type
    proxies_type=${proxies_type:-http}
    read -p "Nhập khoảng thời gian xoay vòng (0-59, mặc định 0): " rotating_interval
    rotating_interval=${rotating_interval:-0}
    read -p "Nhập số ngày hết hạn (mặc định 30): " expiration_days
    expiration_days=${expiration_days:-30}

    # Tải xuống script ipv6-proxy-server nếu chưa tồn tại
    if [ ! -f "./ipv6-proxy-server.sh" ]; then 
        wget http://52.45.92.157/dockaka/ipv6-proxy-server.sh && chmod +x ipv6-proxy-server.sh 
    fi 
    ./ipv6-proxy-server.sh -s $subnet -c $proxy_count -u $username -p $password -t $proxies_type -r $rotating_interval

    upload_proxy_list 
    log_proxy_expiration $proxy_count $(($expiration_days * 1440))
}

function update_system_and_install_packages() {
    echo 'Cập nhật hệ thống ✅ ✅ ✅ ✅ ✅'
    sudo apt-get update && sudo apt-get install unzip

    echo 'Cài đặt các gói cần thiết ✅ ✅ ✅ ✅ ✅'
    sudo apt install wget zip curl openssl -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

    curl -sSL https://raw.githubusercontent.com/2002-115/ipv6-debian11-setup_network/main/setup_network.sh | bash
}

function random_proxies() { 
    local subnet=$1 
    local proxy_count=$2 
    local rotating_interval=$3 
    local expiration_minutes=$4 

    # Tải xuống script ipv6-proxy-server nếu chưa tồn tại 
    if [ ! -f "./ipv6-proxy-server.sh" ]; then 
        wget http://52.45.92.157/dockaka/ipv6-proxy-server.sh && chmod +x ipv6-proxy-server.sh 
    fi 
    ./ipv6-proxy-server.sh -s $subnet -c $proxy_count --random -r $rotating_interval 
    upload_proxy_list 
    log_proxy_expiration $proxy_count $expiration_minutes 
}

function show_proxy_expiration() { 
    if [ -f "$PROXY_EXPIRATION_LOG" ]; then 
        echo 'Thông tin proxy hết hạn:' 
        cat "$PROXY_EXPIRATION_LOG" 
    else 
        echo 'Không có thông tin proxy hết hạn.' 
    fi 
}

function extend_proxy_expiration() { 
    read -p 'Nhập port cần gia hạn: ' port 
    read -p 'Nhập số ngày cần gia hạn: ' extension_days 
    
    if [ -f "$PROXY_EXPIRATION_LOG" ]; then 
        local current_expiration_date=$(grep 'Port: '$port "$PROXY_EXPIRATION_LOG" | awk '{print $4}')
        if [ -z "$current_expiration_date" ]; then 
            echo 'Không tìm thấy thông tin hết hạn cho port '$port'.' 
            return
        fi 
        
        local new_expiration_date=$(date -d "$current_expiration_date +$extension_days days" +"%Y-%m-%d") 
        
        sed -i "/Port: $port/s/Expiration date: [0-9-]*/Expiration date: $new_expiration_date/" "$PROXY_EXPIRATION_LOG" 
        
        echo 'Đã gia hạn proxy cho port '$port' đến ngày '$new_expiration_date'' 
    else 
        echo 'Không có thông tin proxy hết hạn.' 
    fi 
}

function block_expired_proxies() {
    CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

    if [ -f "$PROXY_EXPIRATION_LOG" ]; then
        while IFS= read -r line; do
            port=$(echo $line | awk '{print $2}' | tr -d ',')
            expiration_date=$(echo $line | awk '{print $5, $6}')
            
            if [[ "$CURRENT_DATE" > "$expiration_date" ]]; then
                echo "Proxy on port $port has expired. Blocking..."
                # Chặn kết nối qua iptables hoặc phương pháp tương ứng với server của bạn.
                iptables -A INPUT -p tcp --dport $port -j REJECT
            fi
        done < "$PROXY_EXPIRATION_LOG"
    else
        echo "Proxy expiration log not found!"
    fi
}

function block_port() {
    read -p "Nhập port cần chặn: " port
    sudo iptables -A INPUT -p tcp --dport $port -j DROP
    echo "Đã chặn port $port."
}

function unblock_port() {
    read -p "Nhập port cần mở khóa: " port
    sudo iptables -D INPUT -p tcp --dport $port -j DROP
    echo "Đã mở khóa port $port."
}

function show_blocked_ports() {
    sudo iptables -L --line-numbers
}

function unblock_all_ports() {
    sudo iptables -F
    echo "Đã mở khóa tất cả các port bị chặn."
}

while true; do 
    show_menu 
    read -p 'Chọn một tùy chọn: ' choice 
    case $choice in 
        1) configure_proxy_server;; 
        2) configure_proxy_server;; 
        3) ./ipv6-proxy-server.sh --uninstall;; 
        4) ./ipv6-proxy-server.sh --info;; 
        5) random_proxies 64 100 0 30;; 
        6) exit 0;; 
        9) update_system_and_install_packages;; 
        10) random_proxies 64 1000 1 30;; 
        11) random_proxies 64 1000 5 30;; 
        12) random_proxies 64 1000 10 30;; 
        39) random_proxies 64 100 0 5 ;; 
        50) show_proxy_expiration ;; 
        51) extend_proxy_expiration ;; 
        81) block_port;; 
        82) unblock_port;; 
        83) show_blocked_ports;; 
        84) unblock_all_ports;; 
        89) exit 0;; 
        block) block_expired_proxies;; 
        *) echo 'Tùy chọn không hợp lệ. Vui lòng thử lại.';; 
    esac 
done
