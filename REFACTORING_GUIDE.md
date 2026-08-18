# Refactored Dotfiles Structure

## Overview

This dotfiles repository has been refactored to improve **reusability**, **maintainability**, and **modularity** following Nix best practices.

### Key Improvements

✅ **Centralized Configuration** - Single source of truth for user info, theme, and preferences  
✅ **Feature-Based Profiles** - Easy to create machine-specific configurations  
✅ **DRY Principle** - Eliminated duplication across modules  
✅ **Clear Separation of Concerns** - Config, features, programs, and shell are properly organized  
✅ **Parametrized Design** - Easily adapt for different machines without copy-paste  

---

## Directory Structure

```
home/
├── config/                          # Configuration center
│   ├── default.nix                  # Export all configs
│   ├── user.nix                     # User info (username, email, home path)
│   ├── theme.nix                    # Colors, fonts, UI settings
│   └── preferences.nix              # Feature flags & preferences
│
├── lib/                             # Helper functions & utilities
│   └── default.nix                  # mkProgram, mkPackages, etc
│
├── modules/                         # Modular program configurations
│   ├── programs/                    # Individual application configs
│   │   ├── firefox.nix              # Browser config
│   │   ├── git.nix                  # Git settings
│   │   ├── zsh.nix                  # Shell configuration
│   │   ├── neovim.nix               # Editor config
│   │   ├── ghostty.nix              # Terminal config
│   │   ├── vscode.nix               # VS Code
│   │   └── ...other programs        # Other tools
│   │
│   ├── features/                    # Machine profiles (feature sets)
│   │   ├── base.nix                 # Common tools (always included)
│   │   ├── dev.nix                  # Development tools (git, vscode, neovim)
│   │   ├── gui.nix                  # GUI apps (firefox, vlc, obsidian)
│   │   └── gaming.nix               # Gaming tools (proton, bottles)
│   │
│   ├── shell/                       # Shell-related configs
│   │   └── default.nix              # Imports zsh, ghostty, gnome-terminal
│   │
│   └── desktop/                     # Desktop environment configs
│       └── gnome.nix                # GNOME-specific settings
│
├── env/                             # Environment-specific configs
│   └── gnome/
│       ├── gnome.nix                # GNOME desktop settings
│       └── keybindings.nix          # Keyboard shortcuts
│
├── home.nix                         # Main entry point (parametrized)
└── flake.nix                        # Nix flakes definition
```

---

## Configuration Files Explained

### `config/user.nix`
**Centralized user information** - referenced everywhere instead of hardcoded values.

```nix
{
  username = "chetansinghsajwan";
  name = "chetansinghsajwan";
  email = "76040441+chetansinghsajwan@users.noreply.github.com";
  homeDirectory = "/home/chetansinghsajwan";
  stateVersion = "23.11";
}
```

**Usage**: Instead of hardcoding username/email in `git.nix`, it now reads from this central location.

### `config/theme.nix`
**Shared theme and styling** - centralized colors, fonts, UI settings.

```nix
{
  colors = { primary, background, foreground, accent };
  fonts = { mono, sans, size };
}
```

### `config/preferences.nix`
**Feature flags and preferences** - control which tools are installed.

```nix
{
  features = { dev = true; gui = true; gaming = false; };
  programs = { firefox.enable = true; vscode.enable = true; };
  shell = { program = "zsh"; theme = "powerlevel10k"; };
}
```

---

## Feature-Based System

The refactored design uses **feature modules** to compose configurations for different machines.

### Available Features

| Feature | Includes | Use Case |
|---------|----------|----------|
| **base** | Zsh, Neovim, utilities (tree, curl, etc) | Every machine |
| **dev** | Git, VSCode, Neovim, CMake, LLDB, Clang | Development laptops |
| **gui** | Firefox, VLC, Obsidian, GNOME desktop, fonts | Workstations |
| **gaming** | Bottles, Proton VPN | Gaming systems |

### Example: Creating Machine Profiles

To create different configs for different machines, update `config/preferences.nix`:

```nix
# Dev laptop - full stack
{
  features = { dev = true; gui = true; gaming = false; };
}

# Headless server - minimal
{
  features = { dev = true; gui = false; gaming = false; };
}

# Gaming desktop - all features
{
  features = { dev = true; gui = true; gaming = true; };
}
```

Then in `home.nix`, features are conditionally imported:

```nix
let
  featuresImports = with cfg.preferences.features; [
    ./modules/features/base.nix
  ] ++ (if dev then [ ./modules/features/dev.nix ] else [])
    ++ (if gui then [ ./modules/features/gui.nix ] else [])
    ++ (if gaming then [ ./modules/features/gaming.nix ] else []);
in
{ imports = featuresImports; }
```

---

## Program Modules

Each program has its own dedicated module in `modules/programs/`:

### Example: `modules/programs/git.nix`

```nix
{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    
    # Settings referencing central config (no hardcoded values)
    settings = {
      user.name = "chetansinghsajwan";
      user.email = "76040441+chetansinghsajwan@users.noreply.github.com";
      # ... rest of git config
    };
  };
}
```

**Benefits**:
- ✅ Single responsibility - one file per program
- ✅ Easy to enable/disable via feature flags
- ✅ Consistent structure across all programs
- ✅ Easy to locate a program's config

---

## How Configuration Flows

```
home.nix (main entry point)
  ├─ imports config/
  │   ├─ user.nix (user info)
  │   ├─ theme.nix (colors/fonts)
  │   └─ preferences.nix (feature flags)
  │
  ├─ conditionally imports features/ based on preferences
  │   ├─ features/base.nix (always)
  │   ├─ features/dev.nix (if dev = true)
  │   ├─ features/gui.nix (if gui = true)
  │   └─ features/gaming.nix (if gaming = true)
  │
  └─ each feature imports specific programs/
      ├─ programs/git.nix
      ├─ programs/firefox.nix
      └─ ... etc
```

---

## Migration from Old Structure

### Old Approach
- Hardcoded user info in 3+ places
- All packages imported in `home.nix` (no feature separation)
- No way to toggle features
- Duplicated configurations

### New Approach
- User info in `config/user.nix` (single source)
- Packages organized by feature (base, dev, gui, gaming)
- Toggle features by changing `config/preferences.nix`
- No duplication - clean separation of concerns

---

## Adding a New Program

To add a new program (e.g., `ripgrep`):

### 1. Create module: `modules/programs/ripgrep.nix`

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ripgrep
  ];
}
```

### 2. Add to appropriate feature in `modules/features/`

For dev tools, add to `modules/features/dev.nix`:

```nix
{
  imports = [
    # ... existing imports
    ../modules/programs/ripgrep.nix
  ];
}
```

### 3. Done! 

Next rebuild will include ripgrep via the dev feature.

---

## Adding a New Feature

To add a new feature (e.g., "music" for music production tools):

### 1. Create feature module: `modules/features/music.nix`

```nix
{
  imports = [
    ../modules/programs/reaper.nix
    ../modules/programs/audacity.nix
  ];

  home.packages = with pkgs; [
    sox
    ffmpeg
  ];
}
```

### 2. Add flag to `config/preferences.nix`

```nix
{
  features = {
    dev = true;
    gui = true;
    gaming = false;
    music = true;  # New feature
  };
}
```

### 3. Update `home.nix` to conditionally import it

Already handled - the pattern in `home.nix` automatically picks up new features.

---

## Commands

### Rebuild home configuration
```bash
home-manager switch -b bak
```

### Check syntax
```bash
nix-instantiate --parse home/home.nix
```

### Evaluate configuration
```bash
nix eval --expr 'import ./home/config'
```

---

## Key Design Principles

| Principle | Implementation |
|-----------|-----------------|
| **DRY** | Centralized config files, no duplication |
| **Modularity** | Each program/feature is independently importable |
| **Reusability** | Feature sets can be composed for different machines |
| **Discoverability** | Clear directory structure, easy to find settings |
| **Maintainability** | Changes to one area don't affect others |
| **Extensibility** | Easy to add new programs and features |

---

## Benefits Summary

### Before Refactoring
- ❌ User info duplicated in 3 places
- ❌ No way to disable features
- ❌ Hard to find related settings
- ❌ Can't easily create machine-specific configs
- ❌ Adding new machine = copy-paste + manual edits

### After Refactoring
- ✅ User info in one place (`config/user.nix`)
- ✅ Toggle features with boolean flags
- ✅ All settings organized by concern
- ✅ Machine profiles as feature combinations
- ✅ Add new machine: edit one file

---

## Next Steps

1. **Edit `config/preferences.nix`** to customize features for your machine
2. **Update `config/user.nix`** if using different machine
3. **Rebuild**: `home-manager switch -b bak`
4. **Add new programs**: Follow the "Adding a New Program" section above

