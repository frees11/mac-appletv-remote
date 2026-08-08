# Handover — fake Apple TV target je hotový, appka naň ešte nevidí

## Kontext

Projekt `mac-appletv-remote` je Electron + Python FastAPI backend (`backend/`), ktorý cez **pyatv
0.15.1** ovláda Apple TV. Chýbal vývojový target: reálne Apple TV sa nedajú používať stále (niekto
na nich pozerá) a **virtualizovať tvOS sa nedá** — Apple `Virtualization.framework` má len tri
bootloadery (`VZMacOSBootLoader`, `VZLinuxBootLoader`, `VZEFIBootLoader`), Corellium tvOS
nepodporuje, QEMU je research-grade a tvOS Simulator nemá funkčný App Store.

Náhrada je hotová a **overená**: `tools/fake-atv/` publikuje na LAN virtuálne Apple TV `FakeATV`
vrátane zoznamu appiek s reálnymi bundle ID a ikonami z App Store. Detaily a všetky pasce sú
v [`tools/fake-atv/README.md`](README.md) — prečítaj si ho ako prvé.

## Stav

Hotové a otestované referenčným klientom (`atvremote`): scan, Companion pairing (PIN 1111),
`app_list` (7 appiek), `playing` (cyklí Music → Idle → Video), `launch_app`, všetky HID tlačidlá,
`power_state`.

**Neotestované: samotná appka.** Backend na fake device ešte nikto nepustil.

## Prvá úloha — appka FakeATV nenájde, kým sa nezvýši scan timeout

`backend/app/services/atv_service.py` volá `pyatv.scan()` s krátkymi timeoutmi:

| Riadok | Volanie | Problém |
|---|---|---|
| 79 / 84 | `scan_devices(timeout: int = 5)` | pri 5 s sa `FakeATV` **nenájde** |
| 146 | `pyatv.scan(identifier=…, timeout=3)` | to isté, pairing zlyhá už na hľadaní |
| 233 | `pyatv.scan(identifier=…, timeout=3)` | to isté pri connecte |

Namerané: pri 3 s a 5 s `FakeATV` v multicast scane nie je, pri **10 s** je spoľahlivo.
Python-zeroconf odpovedá pomalšie než reálne zariadenia; reálnych Apple TV sa to netýka
(`Kitchen` aj `Kuchyňa` sa nájdu aj pri 5 s).

Zváž, či timeout zdvihnúť natvrdo, alebo ho spraviť konfigurovateľným cez `.env` a v dev režime dať vyššie.

## Ako to spustiť

```bash
tools/fake-atv/setup.sh              # raz — naklonuje pyatv, spraví venv (gitignored)
tools/fake-atv/run.sh --demo --daemon -d
```

`-d` zapne debug log s OPACK správami, takže vidno presne, čo backend posiela a čo fake odpovedá —
na ladenie pairing a command flow je to hlavný nástroj.

FakeATV: adresa `192.168.88.25` (en0), identifier `6D797FD3-3538-427E-A47B-A32FC6CF3A69`,
Companion pairing PIN **1111** (nikde sa nezobrazí, fake nemá obrazovku).

## Na čo si dať pozor

**Verzie pyatv sa líšia.** Backend má pinnuté `pyatv==0.15.1`, fake target beží na `v0.18.0`.
Ak sa niečo správa divne, over najprv, či to nie je rozdiel verzií. Zjednotenie je otvorená otázka —
0.15.1 je z čias pred viacerými tvOS 26 fixmi.

**Companion áno, AirPlay nie.** AirPlay pair-setup na fake device je prehrávka nahratých bajtov,
nie funkčná implementácia — skončí na `HTTP 500` / `not authenticated`. Fake preto hlási tvOS 13
build, aby priame MRP (a teda now-playing) fungovalo.

**Fake nenahradí reálnu TV.** Reálne Apple TV na tvOS 26.5 hlásia len Companion + AirPlay + RAOP,
**žiadne priame MRP** — now-playing tam ide cez AirPlay tunel, teda inou cestou než proti fake.
Plus otvorené pyatv issues [#2845](https://github.com/postlund/pyatv/issues/2845),
[#2868](https://github.com/postlund/pyatv/issues/2868),
[#2837](https://github.com/postlund/pyatv/issues/2837) na tvOS 26.x. Pred shipnutím test na reálnej TV.

**Neupratané veci v repe (nie moje, nedotkol som sa ich):** v `ATVRemote/` sú súbory s menami
`-la`, `cp`, `ls`, `~` — artefakty zle spustených príkazov. A `git status` má rozpracované zmeny
(zmazané screenshot súbory, upravený `websocket.py`).

## Čo som zmenil

- **nové:** `tools/fake-atv/{atv_fake.py,setup.sh,run.sh,README.md,HANDOVER.md}`
- **upravené:** `.gitignore` — pridané `tools/fake-atv/{.pyatv,.venv}/` a `pyatv-creds.json`

Nič necommitnuté.
