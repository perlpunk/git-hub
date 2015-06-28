#!/usr/bin/env perl

use strict;

sub main {
    my ($cmd) = @_;
    my $input = do { local $/; <> };
    my $input2 = do { local $/; <> };
    my ($options_spec) = $input2 =~ m/ ^ OPTIONS_SPEC="\\ $ (.*?) ^ " $/xsm;
    $options_spec =~ s/.*Options:\n--//s;
    my @options;
    for my $line (split m/\n/, $options_spec) {
        next unless $line =~ m/\S/;
        my $arg = 0;
        my ($key, $desc) = split ' ', $line, 2;
        if ($key =~ s/=$//) {
            $arg = 1;
        }
        my @keys = split m/,/, $key;
        push @options, { keys => \@keys, arg => $arg, desc => $desc };
    }

    $input =~ s/.*?\n= Commands\n//s;
    $input =~ s/(.*?\n== Configuration Commands\n.*?\n)==? .*/$1/s;
    my @list;
    my @repo_cmds;
    while ($input =~ s/.*?^- (.*?)(?=\n- |\n== |\z)//ms) {
        my $text = $1;
        $text =~ /\A(.*)\n/
            or die "Bad text '$text'";
        my $usage = $1;
        $usage =~ s/\A`(.*)`\z/$1/
            or die "Bad usage: '$text'";
        (my $name = $usage) =~ s/ .*//;
        push @list, $name;
        if ($usage =~ m#\Q$name\E \(?\[?(<owner>/)?\]?<repo>#) {
            push @repo_cmds, $name;
        }
    }
    @repo_cmds = sort @repo_cmds;
    @list = sort @list;

    if ($cmd eq "bash") {
        generate_bash(\@list, \@repo_cmds, \@options);
    }
    else {
        generate_zsh(\@list, \@repo_cmds, \@options);
    }
}

sub generate_zsh {
    my ($list, $repo_cmds, $options) = @_;
    my $options_string = '';
    for my $opt (@$options) {
        my $keys = $opt->{keys};
        my $desc = $opt->{desc};
        $desc =~ s/'/'"'"'/g;
        # examples:
        #'(-c --count)'{-c,--count}'[Number of list items to show]:count' \
        #'--remote[Remote name (like "origin")]:remote' \
        my $arg = '';
        if ($opt->{arg}) {
            $arg = ":$keys->[0]";
        }
        my @keystrings = map { (length $_ > 1 ? "--" : "-") . $_ } @$keys;
        if (@$keys == 1) {
            $options_string .= sprintf "        '%s[%s]%s' \\\n",
                $keystrings[0], $desc, $arg;
        }
        elsif (@$keys > 1) {
            $options_string .= sprintf "        '(%s)'{%s}'[%s]%s' \\\n",
                (join ' ', @keystrings), (join ',', @keystrings), $desc, $arg;
        }
    }
    print <<'...';
#compdef git-hub -P git\ ##hub
#description perform GitHub operations

# DO NOT EDIT. This file generated by tool/generate-completion.pl.

if [[ -z $GIT_HUB_ROOT ]]; then
	echo 'GIT_HUB_ROOT is null; has `/path/to/git-hub/init` been sourced?'
	return 3
fi

_git-hub() {
    typeset -A opt_args
    local curcontext="$curcontext" state line context

    _arguments -s \
        '1: :->subcmd' \
        '2: :->repo' \
...
    print $options_string;
    print <<'...';
        && ret=0

    case $state in
    subcmd)
...
    print <<"...";
        compadd @$list
    ;;
    repo)
        case \$line[1] in
...
    print " " x 8;
    print join '|', @$repo_cmds;
    print <<"...";
)
            if [[ \$line[2] =~ "^(\\w+)/(.*)" ]];
            then
                local username="\$match[1]"
                if [[ "\$username" != "\$__git_hub_lastusername" ]];
                then
                    __git_hub_lastusername=\$username
                    IFS=\$'\\n' set -A  __git_hub_reponames `git hub repos \$username --raw`
                fi
                compadd -X "Repos:" \$__git_hub_reponames
            else
                _arguments "2:Repos:()"
            fi
        ;;
        help)
            compadd @$list
        ;;
        esac
    ;;
    esac

}

...
}

sub generate_bash {
    my ($list, $repo_cmds, $options) = @_;
    my $options_string = '';
    for my $opt (@$options) {
        my $keys = $opt->{keys};
        my $arg = '';
        if ($opt->{arg}) {
            $arg = "=";
        }
        my @keystrings = map { (length $_ > 1 ? "--" : "-") . $_ } @$keys;
        for my $key (@keystrings) {
            $options_string .= " $key$arg";
        }
    }

    print <<"...";
#!bash

# DO NOT EDIT. This file generated by tool/generate-completion.pl.

_git_hub() {
    local _opts="$options_string"
    local subcommands="@$list"
    local repocommands="@$repo_cmds"
    local subcommand="\$(__git_find_on_cmdline "\$subcommands")"

    if [ -z "\$subcommand" ]; then
        # no subcommand yet
        case "\$cur" in
        -*)
            __gitcomp "\$_opts"
        ;;
        *)
            __gitcomp "\$subcommands"
        esac

    else

        case "\$cur" in
        -*)
            __gitcomp "\$_opts"
            return
        ;;
        esac

        local repocommand="\$(__git_find_on_cmdline "\$repocommands")"
        if [ ! -z "\$repocommand" ]; then
            if [[ \$cur =~ ^([a-zA-Z_]+)/(.*) ]];
            then
                local username=\${BASH_REMATCH[1]}
                if [[ "\$username" != "\$__git_hub_lastusername" ]];
                then
                    __git_hub_lastusername=\$username
                    __git_hub_reponames=`git hub repos \$username --raw`
                fi
                __gitcomp "\$__git_hub_reponames"
            fi
        fi

    fi
}
...
}

main(shift);
