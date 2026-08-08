# Fake Apple TV — vývojový target

Virtuálne Apple TV na LAN. Beží lokálne, **nedotýka sa reálnych Apple TV** — vyvíjaš, aj keď na TV
niekto pozerá alebo nie sú dostupné.

Postavené nad `tests.fake_device.FakeAppleTV` z [pyatv](https://github.com/postlund/pyatv) (MIT).
Oproti `scripts/fake_device.py` z pyatv navyše: zoznam nainštalovaných appiek (tamojšie CLI ho
zahadzuje), ikony z reálneho App Store, väzba na konkrétne sieťové rozhranie, daemon režim.

## Spustenie

```bash
tools/fake-atv/setup.sh     # raz — naklonuje pyatv, spraví venv (obe gitignored)
tools/fake-atv/run.sh --demo --daemon
```

Publikuje sa ako `FakeATV` na `en0`. Pairing PIN je **1111** (nikde sa nezobrazí, fake nemá obrazovku).

| Prepínač | Význam |
|---|---|
| `--demo` | cyklí now-playing stav (video / music / nič) |
| `--daemon` | beží do Ctrl-C namiesto čakania na ENTER |
| `--interface` | z ktorého rozhrania vziať IP (default `en0`) |
| `--local-ip` | explicitná IP, obíde detekciu |
| `--status` | hlásený systémový stav (`Awake`, `Asleep`, `Screensaver`, `Idle`) |
| `--tvos26-identity` | hlási tvOS 26.5 build; realistickejšie, ale zabije now-playing |
| `-d` | debug log s OPACK správami — vidno, čo klient posiela |

## Overenie referenčným klientom

```bash
cd tools/fake-atv
.venv/bin/atvremote --scan-hosts 192.168.88.25 scan
echo 1111 | .venv/bin/atvremote --scan-hosts 192.168.88.25 \
  --id 6D797FD3-3538-427E-A47B-A32FC6CF3A69 --protocol companion \
  --storage file --storage-filename ./pyatv-creds.json pair
```

Overené 2026-08-05: `scan`, `pair`, `app_list` (7 appiek), `playing` (cyklí Music → Idle → Video),
`launch_app=com.netflix.Netflix`, `menu select up down left right home play_pause`, `power_state`.

## Pasce (overené, nie teória)

**Scan musí mať timeout ≥ 10 s.** Pri 3 s (default v `atv_service.py`) a ani pri 5 s sa `FakeATV`
multicastom nenájde — python-zeroconf odpovedá pomalšie než reálne zariadenia. Pri 10 s sa nájde
spoľahlivo. Reálnych Apple TV sa to netýka. Alternatíva bez čakania: scan s explicitným hostom.

**Python 3.14 pyatv rozbíja.** `atvremote` padne na `RuntimeError: There is no current event loop
in thread 'MainThread'` — 3.14 už nevytvára loop implicitne. `setup.sh` preto trvá na 3.13.

**VPN kradne mDNS.** Keď je aktívna VPN (`ppp0` ako default route), Zeroconf na 0.0.0.0 padá na
`Errno 49 Can't assign requested address` a služba sa nezaregistruje. Preto `Zeroconf(interfaces=[ip])`
a IP z `en0`, nie z default routy.

**AirPlay pairing na fake device nefunguje.** `handle_pair_setup_pin` v pyatv porovnáva hardcoded
hexlified bajty — je to prehrávka nahratého legacy device-auth flow, nie funkčný SRP pairing.
Skončí na `HTTP 500` alebo `not authenticated`. Použi Companion.

**Preto fake default hlási tvOS 13 build (`17K499`).** Na tvOS 15+ buildoch pyatv priame MRP zakáže
a chce ho tunelovať cez AirPlay — a ten sa spárovať nedá, takže now-playing ostane navždy `Idle`.
Starší build drží priame MRP funkčné.

**`tests.fake_device` nie je v pyatv wheele.** `pip install pyatv` ho nedá (`ModuleNotFoundError:
No module named 'tests'`) — preto `setup.sh` klonuje zdrojáky do `.pyatv/`.

## Čo fake device nepokryje

Reálne Apple TV na LAN — `Kuchyňa` 192.168.88.30 (AppleTV5,3) a `Kitchen` 192.168.88.29
(AppleTV6,2), obe tvOS 26.5 — hlásia **len Companion + AirPlay + RAOP, žiadne priame MRP**.
Ovládač tam musí now-playing ťahať cez AirPlay tunel, čo je iná cesta než proti fake device.

K tomu otvorené pyatv issues na tvOS 26.x: [#2845](https://github.com/postlund/pyatv/issues/2845)
(FetchAttentionState mŕtvy na AppleTV14,1), [#2868](https://github.com/postlund/pyatv/issues/2868)
(launchApp vracia `FBSOpenApplicationServiceErrorDomain`), [#2837](https://github.com/postlund/pyatv/issues/2837)
(pairing bez PIN na obrazovke).

Test proti reálnej TV je pred shipnutím nutný. Pairing zobrazí PIN dialóg na obrazovke — robiť len
keď TV nikto nepozerá.
