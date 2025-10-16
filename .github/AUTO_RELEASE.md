# Automatic Release System

Verzia sa **automaticky zvyšuje** pri každom push do `main` branch.

## Ako to funguje

```
Push do main
    ↓
GitHub Actions sa spustí
    ↓
Automaticky zvýši verziu (1.0.0 → 1.0.1)
    ↓
Commitne novú verziu späť [skip ci]
    ↓
Vytvorí git tag (v1.0.1)
    ↓
Buildne aplikáciu
    ↓
Nahrá DMG do GitHub Releases
```

## Setup (Prvýkrát)

Musíš nastaviť Personal Access Token (PAT) pre GitHub Actions:

**Návod: [PAT_SETUP.md](PAT_SETUP.md)** (~5 minút)

Stručne:
1. GitHub → Settings → Developer settings → Personal access tokens
2. Vytvor token s `repo` scope
3. Pridaj do repository Secrets ako `PAT_TOKEN`
4. Hotovo!

## Použitie

### Stačí pushnúť do main:

```bash
git add .
git commit -m "feat: nova funkcionalita"
git push origin main
```

**A hotovo!** GitHub Actions automaticky:
1. Zvýši patch verziu (1.0.0 → 1.0.1)
2. Zbuildí aplikáciu
3. Vytvorí release v GitHub Releases s DMG súbormi

### Sleduj build:

1. Choď na GitHub → **Actions** tab
2. Klikni na najnovší workflow run
3. Sleduj progress (~10-15 minút)
4. Po dokončení: **Releases** → stiahnuť DMG

## Verziovanie

### Automatický patch increment:
- `1.0.0` → `1.0.1` → `1.0.2` → `1.0.3` ...

### Manuálne zvýšenie minor/major verzie:

Ak chceš zmeniť major alebo minor verziu:

```bash
# Minor verzia (nová funkcionalita)
npm version minor  # 1.0.5 → 1.1.0
git push origin main

# Major verzia (breaking changes)
npm version major  # 1.1.0 → 2.0.0
git push origin main
```

GitHub Actions potom bude inkrementovať od novej verzie:
- Po `1.1.0` bude `1.1.1`, `1.1.2`, ...
- Po `2.0.0` bude `2.0.1`, `2.0.2`, ...

## Verzie v Release

Každý release obsahuje:
- **DMG súbory** (Intel + Apple Silicon)
- **ZIP súbory** (alternatívna inštalácia)
- **Auto-generované release notes** z git commitov
- **Timestamp a commit hash**

## Vypnutie auto-release pre konkrétny commit

Ak z nejakého dôvodu nechceš vytvoriť release:

```bash
git commit -m "docs: update readme [skip ci]"
git push origin main
```

`[skip ci]` v commit message preskočí build.

## Konfigurácia

### Zmena branch pre auto-release:

Upraviť `.github/workflows/deploy.yml`:

```yaml
on:
  push:
    branches:
      - main     # alebo develop, staging, atď.
```

### Zmena verziovacej logiky:

V `.github/workflows/deploy.yml` v kroku "Generate version number":

```bash
# Aktuálne: auto-increment patch (1.0.0 → 1.0.1)
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

# Alternatívy:

# Calendar versioning (2024.10.16.1)
NEW_VERSION="$(date +%Y.%m.%d).$GITHUB_RUN_NUMBER"

# Build number only (1.0.BUILD_NUMBER)
NEW_VERSION="${MAJOR}.${MINOR}.$GITHUB_RUN_NUMBER"
```

## FAQ

### Čo ak build zlyhá?

Build sa zastaví, verzia sa NEzvýši, release sa NEuloží. Oprav chybu a pushni znova.

### Môžem vytvoriť release manuálne?

Áno! Choď na **Actions** → **Build and Release** → **Run workflow**

### Kde je starý release script?

`./scripts/release.sh` stále funguje, ale už ho nepotrebuješ. Je užitočný pre manuálne releasy s vlastnými release notes.

### Ako stiahnem konkrétnu verziu?

**Releases** → Vyber verziu → Stiahni DMG/ZIP

### Ako zistím čo sa zmenilo medzi verziami?

Každý release má sekciu "What's Changed" vygenerovanú z git commitov.

## Best Practices

### Commit messages:

Používaj [Conventional Commits](https://www.conventionalcommits.org/):

```bash
feat: pridaná nová funkcia
fix: opravený bug
docs: aktualizovaná dokumentácia
chore: bump version
```

Tieto sa automaticky zobrazia v release notes.

### Testing pred push:

```bash
# Lokálny build test
./scripts/deploy-electron.sh

# Ak funguje, pushni
git push origin main
```

### Rollback k starej verzii:

```bash
# Stiahni starú verziu z Releases
# Alebo:
git revert <commit-hash>
git push origin main
# Vytvorí sa nový release s opravou
```

## Porovnanie: Staré vs. Nové

### Staré (manuálne):
```bash
./scripts/release.sh
# Zadaj verziu
# Potvrď
# Čakaj na build
# Stiahnuť z Releases
```

### Nové (automatické):
```bash
git push origin main
# Hotovo! Čakaj na build.
```

## Riešenie problémov

### "Version already exists"

Znamená to že verzia v `package.json` sa nezmenila. Zvýš ju manuálne:

```bash
npm version patch  # alebo minor/major
git push origin main
```

### "Permission denied" pri push

GitHub Actions potrebuje write permissions:
- **Settings** → **Actions** → **General**
- **Workflow permissions** → **Read and write permissions**
- **Save**

### Nechcem aby každý push vytváral release

Zmeň trigger na konkrétny pattern:

```yaml
on:
  push:
    branches:
      - main
    paths-ignore:
      - 'docs/**'
      - '*.md'
```

Alebo použi manuálny trigger a použiť `[skip ci]` defaultne.

## Súvisiace súbory

- **Workflow**: `.github/workflows/deploy.yml`
- **Detailná dokumentácia**: `.github/GITHUB_ACTIONS_SETUP.md`
- **Quick guide**: `.github/QUICK_RELEASE.md`
- **CI/CD overview**: `docs/CICD.md`
