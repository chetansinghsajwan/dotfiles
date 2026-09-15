# Fuzzy docker pickers built on the __fzf wrapper from the fzf module
# (dotfiles.programs.docker.enable forces programs.fzf.enable on).

# fdps - fuzzy docker containers
function fdps() {
    local start_mode=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all) start_mode=1; shift ;;
            *) shift ;;
        esac
    done

    # Tracks which listing (running vs all) is active across ctrl-d presses;
    # docker has no "watch for new containers" reload primitive of its own,
    # so we just reload the whole list, same trick as ff's file/dir toggle.
    local mode_state
    mode_state=$(mktemp)
    echo "$start_mode" > "$mode_state"

    local fmt='table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    local running_cmd="docker ps --format '$fmt'"
    local all_cmd="docker ps -a --format '$fmt'"
    local mode_toggle_bind="ctrl-d:transform:if [ \"\$(cat '$mode_state')\" = 0 ]; then printf 1 > '$mode_state'; echo 'reload($all_cmd)'; else printf 0 > '$mode_state'; echo 'reload($running_cmd)'; fi"

    local init_cmd="$running_cmd"
    [[ "$start_mode" -eq 1 ]] && init_cmd="$all_cmd"

    eval "$init_cmd" | __fzf \
        --label "Docker Containers" \
        --no-multi \
        -- \
        --header-lines 1 \
        --preview 'docker inspect {1} | bat --color=always -l json' \
        --bind "$mode_toggle_bind" \
        --bind 'ctrl-e:become(docker exec -it {1} sh -c "exec bash 2>/dev/null || exec sh")' \
        --bind 'ctrl-l:become(docker logs -f --tail 200 {1})'

    rm -f "$mode_state"
}

# fdimg - fuzzy docker images
function fdimg() {
    docker images --format 'table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}' | \
        __fzf --label "Docker Images" --no-multi -- \
        --header-lines 1 \
        --preview 'docker inspect {1} | bat --color=always -l json' \
        --bind 'ctrl-e:become(docker run -it --rm {1} sh -c "exec bash 2>/dev/null || exec sh")'
}

# fdvol - fuzzy docker volumes
function fdvol() {
    docker volume ls --format 'table {{.Name}}\t{{.Driver}}' | \
        __fzf --label "Docker Volumes" --no-multi -- \
        --header-lines 1 \
        --preview 'docker volume inspect {1} | bat --color=always -l json'
}

# fdnet - fuzzy docker networks
function fdnet() {
    docker network ls --format 'table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' | \
        __fzf --label "Docker Networks" --no-multi -- \
        --header-lines 1 \
        --preview 'docker network inspect {1} | bat --color=always -l json'
}
