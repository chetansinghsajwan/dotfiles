/* Swapped in for Contents/MacOS/ghostty inside a copy of the .app bundle.
 * Has to be a real Mach-O executable, not a shell script - RunningBoard
 * (macOS's GUI app launch path, used by Dock/Spotlight/Finder) refuses to
 * spawn a script even with a valid ad-hoc signature; only exec-style CLI
 * invocation accepts one. A compiled trampoline that execs the real
 * binary with baked flags works for both launch paths. */
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    char *real = "@real@";
    char *extra[] = { @extra_args@ };
    int nextra = sizeof(extra) / sizeof(extra[0]);

    char **args = malloc(sizeof(char *) * (argc + nextra + 1));
    int i = 0;
    args[i++] = real;
    for (int j = 0; j < nextra; j++) args[i++] = extra[j];
    for (int j = 1; j < argc; j++) args[i++] = argv[j];
    args[i] = NULL;

    execv(real, args);
    return 1;
}
