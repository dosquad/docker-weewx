# Optional NeoWX Material skin

The image includes [NeoWX Material](https://neoground.com/en/docs/neowx-material/basic/installation)
1.11 as an optional addon. It is installed but inactive by default: no report is
added or changed. WeeWX only uses the skin when an enabled report selects it.
The image already includes `ephem` for the almanac page.

On startup, the skin is copied into `/etc/weewx/skins/neowx-material` if that
directory is absent, including for existing configuration volumes. An existing
skin directory is preserved, so image updates do not overwrite customizations.
This uses upstream's manual skin installation method, so it is not registered
with `weectl extension`.

To enable it, add this report **inside the existing `[StdReport]` section** of
`/etc/weewx/weewx.conf`:

```ini
    [[NeoWXMaterial]]
        skin = neowx-material
        enable = true
        HTML_ROOT = /usr/share/nginx/html/neowx-material
```

This publishes to a separate directory so your current reports can continue
running. Customize `/etc/weewx/skins/neowx-material/skin.conf` as needed, then
restart the container:

```sh
docker restart weewx
```

To leave the addon installed but stop using it, set `enable = false` in that
report and restart the container. Previously generated HTML remains on disk.
If you selected this skin in other reports, disable those reports or select a
different skin there too.

Custom image builds can select a packaged upstream release with
`--build-arg NEOWX_MATERIAL_RELEASE=1.11`.
