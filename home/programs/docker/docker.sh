# Fuzzy docker pickers on `pick` (the shared picker, from the pickers module).
# The old in-picker toggles and actions are `--expect` keys now: pick accepts,
# prints the key name first, and the function below runs the action.

# __docker_pick TITLE EXPECT-KEYS PREVIEW-CMD < table
# Reads a `docker ... --format 'table ...'` listing on stdin (first line is the
# header). Prints the key used (empty for Enter) and the chosen row.
function __docker_pick() {
    pick --title "$1" --header-lines 1 --expect "$2" --preview-cmd "$3"
}

# fdps - fuzzy docker containers; -a/--all includes stopped ones.
# ctrl-e opens a shell in the container, ctrl-l follows its logs.
function fdps() {
    local all=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -a | --all) all=(-a) ;;
        esac
        shift
    done

    local out key row id
    out=$(docker ps "${all[@]}" --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' |
        __docker_pick "Docker Containers" ctrl-e,ctrl-l 'docker inspect {1} | bat --color=always -l json')
    key=$(sed -n 1p <<<"$out")
    row=$(sed -n 2p <<<"$out")
    id=$(awk '{print $1}' <<<"$row")
    [[ -z $id ]] && return

    case "$key" in
    ctrl-e) docker exec -it "$id" sh -c 'exec bash 2>/dev/null || exec sh' ;;
    ctrl-l) docker logs -f --tail 200 "$id" ;;
    *) echo "$row" ;;
    esac
}

# fdimg - fuzzy docker images; ctrl-e runs a throwaway container from the image
function fdimg() {
    local out key row id
    out=$(docker images --format 'table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}' |
        __docker_pick "Docker Images" ctrl-e 'docker inspect {1} | bat --color=always -l json')
    key=$(sed -n 1p <<<"$out")
    row=$(sed -n 2p <<<"$out")
    id=$(awk '{print $1}' <<<"$row")
    [[ -z $id ]] && return

    case "$key" in
    ctrl-e) docker run -it --rm "$id" sh -c 'exec bash 2>/dev/null || exec sh' ;;
    *) echo "$row" ;;
    esac
}

# fdvol - fuzzy docker volumes
function fdvol() {
    docker volume ls --format 'table {{.Name}}\t{{.Driver}}' |
        pick --title "Docker Volumes" --header-lines 1 \
            --preview-cmd 'docker volume inspect {1} | bat --color=always -l json'
}

# fdnet - fuzzy docker networks
function fdnet() {
    docker network ls --format 'table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' |
        pick --title "Docker Networks" --header-lines 1 \
            --preview-cmd 'docker network inspect {1} | bat --color=always -l json'
}
