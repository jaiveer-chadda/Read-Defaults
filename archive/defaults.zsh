#!/usr/bin/env zsh

get_keybindings() {

  local output="$( defaults read "$1" 'NSUserKeyEquivalents' )"

  for line in "${(@f)output}"; do
    [[ "$line" =~ ' *[{}] *' ]] && { echo $line; continue; }
    echo -n "${${(r:42:: :)${line//\\033/ -> }/%\" = ?#/\"}/ -> }"
    echo "=  ${(l:5:: :)${${${${${(U)line//# #\"?#\" = }/@/⌘ }/$/⇧ }/\~/⌥ }/\^/⌃ }//[\";]}"
  done

}
