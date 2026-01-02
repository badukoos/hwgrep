# hwgrep

Small set of scripts to query data from [https://linux-hardware.org](https://linux-hardware.org) from the comfort of your terminal.

---

## Requires

Nothing fancy, you would just need `bash`, `awk` and `curl`

---

## Quickstart

Some quick examples to show how this fits together

---

## Initial query filters

Say you want to look up a **Lenovo ThinkPad E14 Gen 7** model computer

```bash
./main.sh --type notebook --vendor Lenovo --model-like "ThinkPad E14 Gen 7"
```

If you are not sure about the exact series or model or generation, you can narrow things down using the
manufacturing year instead

```bash
./main.sh --type notebook --vendor Lenovo --model-like "ThinkPad" --mfg-year 2025
```

You can also be very specific if you already know the full model string

```bash
./main.sh --type notebook --vendor Lenovo --model-like "ThinkPad E14 Gen 7 21SYS00H00"
```

> [!TIP]
> The more info you give in the initial query, the cleaner the results will be. The good people maintaining
> linux-hardware.org might appreciate it too.

> [!NOTE]
> The website can timeout from time to time, so a bit of patience goes a long way when using this repo.

Example output:

```
Computer 'Lenovo ThinkPad E14 Gen 7 21SYS00H00'
  HWid   : 06f6de75bec1
  Type   : notebook
  Vendor : Lenovo
  Model  : ThinkPad E14 Gen 7 21SYS00H00
  Year   : 2025

Probes:
  ID         Source   System       Date
  ---------- -------- ------------ --------------
  2044f52e97 Classic  Fedora 42    Sep 02, 2025
```

---

## Sifting through probes

Once you have a computer ID and a probe ID, you can dig into the probe itself.

```bash
./main.sh --probe-id 2044f52e97
```

This will print

* System info
* All detected devices
* All logs uploaded for that probe

Example output:

```
Host:
  System : Fedora 42
  Arch   : x86_64
  Kernel : 6.16.3-200.fc42.x86_64
  Vendor : Lenovo
  Model  : ThinkPad E14 Gen 7 21SYS00H00

  [output trimmed]
...
```

Devices:

```
Devices:
  BUS  ID/Class              Vendor      Device           Type     Driver   Status   Comments
  ---- --------------------- ----------- ---------------- -------- -------- -------- ---------
  PCI  8086:7dd1:17aa:5134 / Intel       Arrow Lake-P     graphics i915, xe detected <none>
       03-00-00              Corporation [Intel Graphics] card
...
  USB  04f3:0c8c / ff-00-00  Elan Micro  ELAN:ARM-M4      <none>     -      failed   <none>
                             electronics
  USB  8087:0033 / e0-01-01  Intel Corp. AX211 Bluetooth  bluetooth btusb   detected <none>

  [output trimmed]
...
```

Available logs:

```
Available Logs:
  Board      : Dmidecode, Hwinfo, Sensors
  Boot       : Boot.log, Boot_efi, Efibootmgr, Grub, Grub.cfg, Systemd-analyze, Uptime
  CPU        : Cpuinfo, Cpupower, Lscpu
  Drive      : Iostat, Smartctl
  Filesystem : Df, Fdisk, Lsblk
  Graphics   : Edid, Glxinfo, Xdpyinfo, Xorg.conf.d, Xrandr, Xrandr_providers
  Input      : Input/devices, Xinput
  Kernel     : Dev, Dmesg, Dmesg.1, Interrupts, Ioports, Power_supply, Upower

  [output trimmed]
...
```

> [!TIP]
> Use `--max-results` if you want to limit how many devices are shown

---

## Perusing logs

If you see a log you care about (for example `dmesg`), you can fetch it directly

```bash
./main.sh --probe-id 2044f52e97 --log-name dmesg
```
The logs also support additional `--grep` filter

```bash
./main.sh --probe-id 2044f52e97 --log-name dmesg --grep "acpi error:|ec access misbehaving"
```

You can also expand this with a broader search

```bash
./main.sh \
  --type notebook \
  --vendor Lenovo \
  --model-like "ThinkPad E14 Gen 7" \
  --log-name dmesg \
  --grep "acpi error:|ec access misbehaving" \
  --max-results 10
```

This is useful if you want to check whether a specific log message shows up across
multiple machines or models.

> [!NOTE]
> Uploaded dmesg logs don't include the numeric severity levels you'd get from a raw `dmesg -r`, so coloring is purely heuristic.

---

## Diving into a specific device

Devices show up the in probe output. Once you spot a device ID you want to inspect,
you can query the device directly using `--device-id`

This is useful if you want to see how the same device behaves across different
machines, probes, or distributions.

For example, let's pick the bluetooth device from the previous probe output:

```bash
./main.sh --device-id usb:8087-0033
```

Just like elsewhere, you can cap the output:

```bash
./main.sh --device-id usb:8087-0033 --max-results 10
```
> [!IMPORTANT]
> The `--device-id` value is derived from the probe output, but it is not always a direct copy.
>
> For most hardware buses USB, PCI, NVMe, etc the format is:
>
> ```
> <bus>:<vendor-id>-<device-id>
> ```
>
> For example:
>
> ```
> USB  8087:0033 / e0-01-01
> ```
>
> becomes:
>
> ```
> usb:8087-0033
> ```
>
> `SYS` devices work a bit differently. Their IDs are derived from the **device type**
> memory, battery, motherboard, etc rather than the BUS column. So, `memory` becomes `mem:`,
> `battery` becomes `bat:`, `motherboard` becomes `board:` etc.
>
> In general, spaces and punctuation are replaced with dashes.
---

## Additional device filters

Both the probe device table and the device status table can be filtered further using
`--filter-device`. It takes simple `key=value` pairs.

Show failed devices for a specific USB ID

```bash
./main.sh \
  --device-id usb:8087-0033 \
  --filter-device "status=failed" \
  --max-results 10
```

You can also narrow it down further by adding more filters

```bash
./main.sh \
  --device-id usb:8087-0033 \
  --filter-device "status=failed" \
  --filter-device "vendor=lenovo" \
  --filter-device "system=fedora"
```

> [!NOTE]
> There is a hard cap of 5 pages and 250 records when scanning devices.
> `--filter-device` is applied on top of that limit unless `--max-results`
> is also applied in which case it takes precedence over `--filter-device`.

---

## Caching

Pages are cached locally so we do not hammer linux-hardware.org. The default behavior is to check **offline** i.e.

* Use cached pages if available
* Only hit the network if needed

To refetch even if cache exists use the `--refresh-cache` flag. To override and prefer the network using `--no-cache` flag

Example:

```bash
./main.sh --device-id usb:8087-0033 --refresh-cache
```

There is also a helper script for cache management.

List cache contents

```bash
./scripts/hw_cache.sh ls
```

Show cache path for a specific ID

```bash
./scripts/hw_cache.sh path device:usb:8087-0033
```

> [!TIP]
> Use the following prefixes, `probe:` for probe IDs and `computer:` for computer IDs

Manually warm the cache

```bash
./scripts/hw_cache.sh prime device:usb:8087-0033
```

Clear all cached files

```bash
./scripts/hw_cache.sh clear
```
---

## BSD hardware

To query data from **bsd-hardware.info** instead, just tack `--bsd` with all your queries.

Example:

```bash
./main.sh --type notebook --vendor Lenovo --model-like "ThinkPad" --mfg-year 2025 --bsd
```
---

## License

Boilerplate MIT