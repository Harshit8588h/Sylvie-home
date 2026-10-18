# OEM Battery Setup Guides

Indian Android OEMs (Vivo, Oppo, Xiaomi, Realme) kill background apps aggressively — more than stock Android. For Sylvie's location + alert system to be reliable, these settings must be applied once on each family member's phone after install. The app itself will walk the user through this on first launch (detected via `device_info_plus`), but these are the canonical steps.

## Vivo (Funtouch OS / OriginOS) — most important: grandma's phone

1. Settings → Battery → Background power consumption management → find **Sylvie** → set to **Allow background activity**
2. Settings → Battery → High background power consumption → remove Sylvie if listed
3. Settings → Apps → Sylvie → **Autostart** → enable
4. Settings → Apps → Sylvie → **Permissions** → Location → **Allow all the time** (not just "while using")
5. Settings → Apps → Sylvie → Notifications → enable all channels
6. Lock screen: pull up recent apps, long-press Sylvie card → **Lock** (padlock icon) so OS does not kill it on memory pressure

*Exact menu names vary by Vivo model/year. Will finalize once we know the exact model.*

## Oppo / Realme (ColorOS)

1. Settings → Battery → App Battery Management → Sylvie → **Allow background activity** + **Allow auto-launch**
2. Settings → Privacy → Permission Manager → Location → Sylvie → **Allow all the time**
3. Recent apps → lock Sylvie card

## Xiaomi / Redmi / Poco (MIUI / HyperOS)

1. Settings → Apps → Manage apps → Sylvie → **Battery saver** → **No restrictions**
2. Settings → Apps → Manage apps → Sylvie → **Autostart** → enable
3. Settings → Apps → Manage apps → Sylvie → **Other permissions** → Display pop-up windows while running in background → enable
4. Recent apps → lock Sylvie card

## Samsung (One UI)

1. Settings → Apps → Sylvie → Battery → **Unrestricted**
2. Settings → Apps → Sylvie → Permissions → Location → **Allow all the time**
3. Settings → Device care → Battery → Background usage limits → Never sleeping apps → **add Sylvie**

## OnePlus (OxygenOS)

1. Settings → Battery → Battery optimisation → Sylvie → **Don't optimise**
2. Settings → Apps → Sylvie → Permissions → Location → **Allow all the time**
3. Recent apps → lock Sylvie card

## Pixel / stock Android

1. Settings → Apps → Sylvie → Battery → Unrestricted
2. Settings → Apps → Sylvie → Permissions → Location → Allow all the time

Pixel is the easiest — Google doesn't aggressively kill apps.
