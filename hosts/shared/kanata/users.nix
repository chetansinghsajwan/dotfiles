# Who gets kanata, from `dotfiles.kanata.enable` (the system level) and each user's
# `kanata.enable` (the user level). With the system level on, kanata is system-wide, for every
# user. With it off, kanata is scoped to the users that have the user level on, and runs only
# while one of them is the active session. The scope is never inferred from the declared users,
# because the machine can have accounts this flake does not know.
lib: dotfiles: let
    enabled = lib.filter (u: u.kanata.enable) (lib.attrValues dotfiles.users);
    systemWide = dotfiles.kanata.enable;
in {
    names = map (u: u.username) enabled;
    any = systemWide || enabled != [];
    scoped = !systemWide && enabled != [];
}
