# Who gets kanata: the users with `kanata.enable`. Kanata runs when any user has it. When
# every user has it, it is system-wide; when only some do, it is scoped to them.
lib: users:
let
    all = lib.attrValues users;
    enabled = lib.filter (u: u.kanata.enable) all;
in
{
    names = map (u: u.username) enabled;
    any = enabled != [ ];
    scoped = enabled != [ ] && lib.length enabled != lib.length all;
}
