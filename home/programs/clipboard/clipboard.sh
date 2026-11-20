# Clipboard history picker: `cb` (a tuikit tool) browses the history and copies the
# choice. `cb watch` records it; this module runs that as a systemd user service.

# fcp - fuzzy clipboard history. Enter copies the entry to the clipboard (nothing
# is printed); ctrl-x deletes it.
function fcp() {
    cb "$@"
}
