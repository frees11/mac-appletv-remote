# Quick Deploy Cheat Sheet

## For First-Time Beta Testing (No Code Signing)

```bash
# 1. Build the app
make deploy

# 2. Share the file
open dist-electron/
# Upload the .dmg to cloud storage and share the link
```

**Note:** Users will see "unidentified developer" warning. They should right-click → Open.

## For Code Signed Distribution

### One-Time Setup (5 minutes):

```bash
# 1. Copy environment template
cp .env.deploy.example .env.deploy

# 2. Edit with your Apple Developer credentials
nano .env.deploy

# Add:
# APPLE_ID=your-apple-id@email.com
# APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
# APPLE_TEAM_ID=XXXXXXXXXX

# 3. Deploy
make deploy
```

### Future Deployments:

```bash
make deploy
```

That's it! The script automatically uses your `.env.deploy` credentials.

## Get Your Credentials

### Apple ID
Your Apple Developer account email (from developer.apple.com)

### App-Specific Password
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Security → Generate App-Specific Password
3. Copy the `xxxx-xxxx-xxxx-xxxx` format password

### Team ID
1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Membership → Team ID (10 characters like `A1B2C3D4E5`)

## Commands Reference

| Command | Purpose |
|---------|---------|
| `make deploy` | Build and package app |
| `npm run icons` | Regenerate icons |
| `make clean` | Clean build artifacts |
| `./scripts/release.sh` | Create versioned release |

## File Locations

| What | Where |
|------|-------|
| Built app | `dist-electron/*.dmg` |
| Icons | `build/*.icns`, `build/*.ico`, `build/*.png` |
| Credentials | `.env.deploy` (create from `.env.deploy.example`) |

## Troubleshooting

### Build fails?
```bash
make clean
npm install
make deploy
```

### Icons missing?
```bash
npm run icons
```

### Code signing fails?
- Check credentials in `.env.deploy`
- Verify Apple Developer account is active
- See [docs/SIGNING-SETUP.md](docs/SIGNING-SETUP.md)

## Full Documentation

- **Quick Start:** [docs/QUICK-START-DEPLOYMENT.md](docs/QUICK-START-DEPLOYMENT.md)
- **Code Signing:** [docs/SIGNING-SETUP.md](docs/SIGNING-SETUP.md)
- **CI/CD Setup:** [docs/CICD.md](docs/CICD.md)
- **Complete Guide:** [DEPLOYMENT.md](DEPLOYMENT.md)
