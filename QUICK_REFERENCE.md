# Quick Reference: New Dotfiles Structure

## Common Tasks

### ❓ Where do I find X setting?

| Setting | Location |
|---------|----------|
| Username / email | `home/config/user.nix` |
| Colors / fonts | `home/config/theme.nix` |
| Feature toggles | `home/config/preferences.nix` |
| Git config | `home/modules/programs/git.nix` |
| Firefox settings | `home/modules/programs/firefox.nix` |
| Shell (zsh) config | `home/modules/programs/zsh.nix` |
| GNOME shortcuts | `home/env/gnome/keybindings.nix` |

---

## Quick Edits

### Change Git Email
```bash
# Before (3 edits needed)
# Now just 1 edit:
$ vim home/config/user.nix
# Change: email = "your-email@domain.com"
```

### Add Dev Tool (e.g., ripgrep)
```bash
# 1. Create module:
cat > home/modules/programs/ripgrep.nix << 'EOF'
{ pkgs, ... }:
{ home.packages = [ pkgs.ripgrep ]; }
EOF

# 2. Add to dev feature:
# Edit home/modules/features/dev.nix, add to imports:
# ../modules/programs/ripgrep.nix

# 3. Rebuild:
$ home-manager switch -b bak
```

### Toggle Feature (e.g., Disable Gaming)
```bash
# Edit: home/config/preferences.nix
# Change: gaming = true;
# To:     gaming = false;
```

### Add New Machine Profile
```bash
# 1. Create new feature: home/modules/features/server.nix
# 2. Edit preferences.nix to change feature flags
# 3. Rebuild
```

---

## File Organization Quick Guide

```
Each program → ONE dedicated file
├─ firefox.nix
├─ git.nix
├─ vscode.nix
└─ etc

Feature = Collection of programs
├─ base (shell tools)
├─ dev (coding tools)
├─ gui (desktop apps)
└─ gaming (game stuff)

Config = Central settings
├─ user (name, email, paths)
├─ theme (colors, fonts)
└─ preferences (feature toggles)
```

---

## When Adding Something New

### New Program?
→ Create `home/modules/programs/myprogram.nix`
→ Add to relevant feature in `home/modules/features/`

### New Feature?
→ Create `home/modules/features/myfeature.nix`
→ Add flag to `home/config/preferences.nix`

### New Config Setting?
→ Add to `home/config/preferences.nix` or `home/config/theme.nix`

---

## Syntax Check

```bash
# Verify Nix syntax (without building)
nix-instantiate --parse home/home.nix
nix-instantiate --parse home/config/default.nix

# Check entire evaluation
nix flake check
```

---

## Directory Tree (Simple View)

```
home/
├── config/           # Settings hub
├── lib/              # Helper functions
├── modules/
│   ├── programs/     # Individual app configs
│   ├── features/     # Machine profiles
│   ├── shell/        # Terminal configs
│   └── desktop/      # DE-specific
├── env/gnome/        # GNOME configs
└── home.nix          # Main entry (reads from config/)
```

---

## Before/After Comparison

| Action | Before | After |
|--------|--------|-------|
| Change username | Edit 3 files | Edit `config/user.nix` |
| Add dev tool | Edit multiple places | Add to `features/dev.nix` |
| New machine config | Copy entire home.nix | Edit `preferences.nix` |
| Find Firefox settings | Search everywhere | Open `programs/firefox.nix` |
| Disable a feature | Remove from imports | Set `preferences.X = false` |

---

## Remember

- **Don't**: Copy-paste configs (use centralized config/)
- **Don't**: Hardcode values (reference config/ instead)
- **Do**: Keep programs isolated (one file per program)
- **Do**: Use features to compose configs
- **Do**: Reference central configs in programs

