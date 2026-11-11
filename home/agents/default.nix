{ lib, ... }:
let
    instructions = ./AGENTS.md;

    # Skills kept in this repo. Skills installed with `npx skills add` are not listed here, so
    # they stay writable and unmanaged.
    skills = [ "commit-messages" ];

    # The same skill is linked for the agents that read ~/.agents/skills (Codex) and for the ones
    # that read ~/.claude/skills (Claude Code, opencode).
    skillRoots = [
        ".agents/skills"
        ".claude/skills"
    ];

    skillLinks = lib.listToAttrs (
        lib.concatMap (
            name:
            map (root: {
                name = "${root}/${name}";
                value.source = ./skills/${name};
            }) skillRoots
        ) skills
    );
in
{
    home.file = {
        ".agents/AGENTS.md".source = instructions;

        # Claude Code reads CLAUDE.md, so it imports the shared file.
        ".claude/CLAUDE.md".text = "@~/.agents/AGENTS.md\n";

        ".codex/AGENTS.md".source = instructions;
        ".gemini/GEMINI.md".source = instructions;
    }
    // skillLinks;

    xdg.configFile."opencode/AGENTS.md".source = instructions;
}
