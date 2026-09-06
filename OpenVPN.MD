# OpenVPN

Прежний пример был рассчитан на старую конфигурацию (`cipher AES-256-CBC`,
`comp-lzo`, `tls-auth`, DH-файл и старые unit paths). Он заменен материалами для
OpenVPN 2.6: [лабораторная 19](labs/19-openvpn/README.md).

Канонические профили находятся в `labs/19-openvpn/`, а учебная PKI создается
`scripts/generate-lab-pki.sh`. В профилях используются AEAD `data-ciphers`,
`tls-crypt`, проверка EKU/имени сервера и один адресный route. Compression не
включается. Порядок проверки: version → unit template → listener → TLS journal →
tun address → route → доступ к конечному сервису.
