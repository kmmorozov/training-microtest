#!/usr/bin/env bash
# Генератор ИСКЛЮЧИТЕЛЬНО учебной PKI для TLS/OpenVPN лабораторного стенда.
# Создает root CA, пять leaf certificates и OpenVPN tls-crypt static key.
# Не использовать как production CA: нет CRL/OCSP, защищенного HSM и issuance audit.
set -euo pipefail

# Default generated/ исключен из Git; можно передать отдельный закрытый каталог.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out=${1:-"$script_dir/../generated/pki"}
command -v openssl >/dev/null || { echo "Требуется openssl" >&2; exit 1; }
# openvpn CLI нужен для корректного формата static key, его не заменяем openssl rand.
command -v openvpn >/dev/null || { echo "Требуется OpenVPN для tls-crypt.key" >&2; exit 1; }

# Каталог закрыт mode 0700. Непустой каталог никогда не перезаписывается.
install -d -m 0700 "$out"
if find "$out" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "Каталог $out не пуст. Скрипт не перезаписывает PKI." >&2
    exit 1
fi
# Все создаваемые private/intermediate файлы по умолчанию получает mode 0600.
umask 077

# EC P-256 root key и self-signed CA certificate на 10 учебных лет.
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$out/ca.key"
openssl req -x509 -new -sha256 -days 3650 -key "$out/ca.key" \
    -subj '/CN=LPIC-103 Lab Root CA/O=Microtest Training' \
    -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
    -addext 'keyUsage=critical,keyCertSign,cRLSign' \
    -out "$out/ca.crt"

# issue_leaf FILE_BASENAME COMMON_NAME EKU SAN создает key → CSR → signed cert.
# SAN передается явным аргументом, а EKU разделяет serverAuth и clientAuth roles.
issue_leaf() {
    file_name=$1
    common_name=$2
    extended_usage=$3
    subject_alt_name=$4
    ext_file="$out/$file_name.ext.cnf"
    # Для каждого leaf создается независимый EC private key.
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$out/$file_name.key"
    # CSR содержит public key и subject; extensions задаются при подписи ниже.
    openssl req -new -sha256 -key "$out/$file_name.key" \
        -subj "/CN=$common_name/O=Microtest Training" -out "$out/$file_name.csr"
    {
        # Leaf не может подписывать другие certificates.
        echo 'basicConstraints=critical,CA:FALSE'
        # EC TLS использует digital signature/key agreement.
        echo 'keyUsage=critical,digitalSignature,keyAgreement'
        echo "extendedKeyUsage=$extended_usage"
        echo "subjectAltName=$subject_alt_name"
        echo 'subjectKeyIdentifier=hash'
        echo 'authorityKeyIdentifier=keyid,issuer'
    } >"$ext_file"
    # 397 дней ограничивают срок учебного leaf; CA serial хранится рядом с CA.
    openssl x509 -req -sha256 -days 397 -in "$out/$file_name.csr" \
        -CA "$out/ca.crt" -CAkey "$out/ca.key" -CAcreateserial \
        -extfile "$ext_file" -out "$out/$file_name.crt"
}

# HTTP/mail endpoints получают serverAuth и DNS SAN; loopback IP нужен локальным tests.
issue_leaf app app.example.test serverAuth 'DNS:app.example.test,IP:127.0.0.1'
issue_leaf wp wp.example.test serverAuth 'DNS:wp.example.test,IP:127.0.0.1'
issue_leaf mail mail.example.test serverAuth 'DNS:mail.example.test'
issue_leaf server vpn.example.test serverAuth 'DNS:vpn.example.test'
# OpenVPN client certificate имеет отдельный clientAuth EKU.
issue_leaf client client1 clientAuth 'DNS:client1'
# Static key защищает/скрывает control channel, но не заменяет certificate PKI.
openvpn --genkey secret "$out/tls-crypt.key"
[ -s "$out/tls-crypt.key" ] || { echo "OpenVPN не создал tls-crypt.key" >&2; exit 1; }

# Явно разделяем permissions public certificates и всех private/static keys.
chmod 0600 "$out"/*.key
chmod 0644 "$out"/*.crt
for cert in app wp mail server client; do
    # Каждый leaf обязан построить цепочку до созданного CA.
    openssl verify -CAfile "$out/ca.crt" "$out/$cert.crt"
done
echo "Учебная PKI создана в $out. Закрытые ключи не коммитьте и не публикуйте."
