# Fish completion for bx (Bruno Execute)

function __bx_find_root
    if set -q BX_COLLECTION; and test -f "$BX_COLLECTION/bruno.json"
        echo $BX_COLLECTION
        return
    end
    set -l dir (pwd)
    while test "$dir" != "/"
        if test -f "$dir/bruno.json"
            echo $dir
            return
        end
        set dir (dirname $dir)
    end
end

function __bx_requests
    set -l root (__bx_find_root)
    test -z "$root"; and return
    find $root -name '*.bru' -not -path '*/environments/*' | sed "s|$root/||;s|\.bru\$||"
end

function __bx_envs
    set -l root (__bx_find_root)
    test -z "$root"; and return
    test -d "$root/environments"; or return
    find $root/environments -name '*.bru' -exec basename {} .bru \;
end

function __bx_needs_command
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 1
end

function __bx_using_command
    set -l cmd (commandline -opc)
    test (count $cmd) -gt 1; and test "$cmd[2]" = "$argv[1]"
end

# Commands
complete -c bx -n __bx_needs_command -a ls -d 'List all requests'
complete -c bx -n __bx_needs_command -a envs -d 'List environments'
complete -c bx -n __bx_needs_command -a inspect -d 'Show resolved request'
complete -c bx -n __bx_needs_command -a help -d 'Show help'
complete -c bx -n __bx_needs_command -a version -d 'Print version'
complete -c bx -n __bx_needs_command -a completion -d 'Output completion script'

# Request names
complete -c bx -n __bx_needs_command -a '(__bx_requests)' -d 'Request'

# Completion subcommand
complete -c bx -n '__bx_using_command completion' -a 'bash zsh fish'

# Flags
complete -c bx -s e -l env -x -a '(__bx_envs)' -d 'Use environment'
complete -c bx -s v -l verbose -d 'Show request details'
complete -c bx -s d -l dry-run -d 'Print command only'
complete -c bx -l raw -d 'Raw response body'
complete -c bx -l xh -d 'Force xh client'
complete -c bx -l curlie -d 'Force curlie client'
complete -c bx -l curl -d 'Force curl client'
complete -c bx -l no-color -d 'Disable colors'
complete -c bx -s H -l header -x -d 'Add header'
complete -c bx -l var -x -d 'Override variable'
