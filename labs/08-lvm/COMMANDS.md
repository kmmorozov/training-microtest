# LVM: последовательность объектов

```text
/dev/sde,/dev/sdf,/dev/sdg → PV → vg_lpic103
  ├─ lv_data (ext4, 1G → 1.5G)
  ├─ lv_before (snapshot lv_data, 512M)
  └─ pool0 (thin pool, 1500M) → thin_web (virtual 3G)
```

Создавайте слои только после `preflight.sh`. Команды `pvcreate`, `vgcreate`,
`lvcreate`, `lvextend`, `resize2fs`, `mount -o ro,noload` приведены в руководстве.
Контролируйте snapshot `Data%` и thin-pool `Data%/Metadata%` через:

```bash
sudo lvs -a -o lv_name,lv_size,origin,pool_lv,data_percent,metadata_percent vg_lpic103
```
