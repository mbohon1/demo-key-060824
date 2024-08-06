#!/bin/bash

# Giải mã nội dung của file dockaka.sh.enc
openssl enc -aes-256-cbc -d -in dockaka.sh.enc -out dockaka.sh -k "your_password" -pbkdf2

# Chạy file dockaka.sh
bash dockaka.sh
