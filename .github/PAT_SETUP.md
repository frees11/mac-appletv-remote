# GitHub Personal Access Token Setup

Pre automatické releases musíš vytvoriť Personal Access Token (PAT), ktorý umožní GitHub Actions pushovat späť do repozitára.

## Rýchly Setup (5 minút)

### 1. Vytvor Personal Access Token

1. Choď na GitHub → **Settings** (tvoj profile vpravo hore)
2. Scroll dole → **Developer settings** (úplne dole v ľavom menu)
3. **Personal access tokens** → **Tokens (classic)**
4. **Generate new token** → **Generate new token (classic)**

5. Vyplň:
   - **Note**: `mac-appletv-remote auto-release`
   - **Expiration**: `No expiration` (alebo `1 year`)
   - **Select scopes**: ✅ Zaškrtni **`repo`** (všetky pod-checkboxy)

6. Scroll dole → **Generate token**
7. **IMPORTANT**: Skopíruj token HNEĎ (zobrazí sa len raz!)
   - Token vyzerá ako: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 2. Pridaj Token do Repository Secrets

1. Choď na tvoj repository: `https://github.com/frees11/mac-appletv-remote`
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**
4. Vyplň:
   - **Name**: `PAT_TOKEN`
   - **Secret**: Vlož token čo si skopíroval
5. **Add secret**

### 3. Povoľ Workflow Permissions

1. Stále v **Settings** → **Actions** → **General**
2. Scroll dole na **Workflow permissions**
3. Vyber: ✅ **Read and write permissions**
4. Zaškrtni: ✅ **Allow GitHub Actions to create and approve pull requests**
5. **Save**

### 4. Test

```bash
# Push zmeny
git add .github/
git commit -m "fix: update workflow with PAT token"
git push origin main
```

Workflow by mal teraz fungovať!

---

## Alternatívne Riešenie (Fine-grained Token)

Ak chceš bezpečnejší token s obmedzenými oprávneniami:

### 1. Vytvor Fine-grained Token

1. GitHub → **Settings** → **Developer settings**
2. **Personal access tokens** → **Fine-grained tokens**
3. **Generate new token**
4. Vyplň:
   - **Token name**: `mac-appletv-remote-releases`
   - **Expiration**: `90 days` (alebo podľa preferencie)
   - **Repository access**: **Only select repositories** → Vyber `mac-appletv-remote`
   - **Permissions**:
     - **Repository permissions**:
       - Contents: `Read and write` ✅
       - Metadata: `Read-only` ✅
       - Pull requests: `Read and write` ✅
5. **Generate token**
6. Skopíruj token

### 2. Pridaj ako PAT_TOKEN Secret

Rovnako ako vyššie - pridaj do repository secrets ako `PAT_TOKEN`.

---

## Riešenie Problémov

### "403 Permission denied"

**Príčina**: Token nemá správne oprávnenia alebo nie je nastavený.

**Riešenie**:
1. Skontroluj či `PAT_TOKEN` secret existuje v repo Settings → Secrets
2. Skontroluj či token má `repo` scope
3. Skontroluj či token nie je expirovaný

### "Token not found"

**Príčina**: Secret má zlý názov.

**Riešenie**:
- Secret MUSÍ mať presne názov `PAT_TOKEN`
- Veľké písmená sú dôležité

### "Resource not accessible by integration"

**Príčina**: Workflow permissions sú vypnuté.

**Riešenie**:
- Settings → Actions → General → Workflow permissions
- Zapni "Read and write permissions"

---

## Bezpečnosť

### Je PAT bezpečný?

✅ Áno, ak:
- Token je uložený len v GitHub Secrets (nie v kóde!)
- Token má obmedzené permissions (len `repo` scope)
- Token má expiráciu (napr. 1 rok)

### Čo ak token unikne?

1. Choď na GitHub → Settings → Developer settings
2. Nájdi token
3. **Delete** / **Revoke**
4. Vytvor nový a aktualizuj secret

---

## Ako to funguje

```
GitHub Actions spustí workflow
    ↓
Použije PAT_TOKEN na checkout
    ↓
Zmení verziu v package.json
    ↓
Commitne zmeny (git commit)
    ↓
Pushne späť do repo pomocou PAT_TOKEN
    ↓
Vytvorí tag
    ↓
Pushne tag
    ↓
Pokračuje s buildom...
```

PAT_TOKEN dáva GitHub Actions oprávnenie pushovat do repozitára, čo štandardný `GITHUB_TOKEN` neumožňuje (z bezpečnostných dôvodov).

---

## Checklist

- [ ] Vytvoril som PAT token (classic alebo fine-grained)
- [ ] Token má `repo` scope
- [ ] Skopíroval som token
- [ ] Pridal som token do Secrets ako `PAT_TOKEN`
- [ ] Zapol som "Read and write permissions"
- [ ] Pushol som zmeny a workflow funguje

---

## Potrebuješ pomoc?

Ak máš problémy:
1. Skontroluj Actions tab → Klikni na zlyhnutý workflow → Pozri error log
2. Overiť že `PAT_TOKEN` secret existuje
3. Overiť že token nie je expirovaný

---

**Po dokončení môžeš jednoducho pushovať do main a releases sa vytvoria automaticky!**
