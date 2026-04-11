#!/usr/bin/env zsh

# if __name__ != "__main__": quit()
#  i.e., if we're being sourced, exit
if [[ $ZSH_EVAL_CONTEXT != 'toplevel' ]] return 1

() {

  local -r _reset=$'\e[0m'
  local -r  _bold=$'\e[1m'
  local -r   _dim=$'\e[2m'

  local -r _dividing_line="\n$_dim${(r:$COLUMNS::─:)}$_reset"

  local -r _sep=' —→ '
  local -ri 10 _sep_len=${#_sep}
  local -ri 10 delim=$RANDOM

  local -ri 2 _load_from_cache=1
  local -r _cache_file='../cache/latest.txt'
  local -r _defaults_key='NSUserKeyEquivalents'

  local -r _list_start_pattern="^Found 1 keys in domain '([^']+)'"
  local -r _useless_line_pattern='^\s+"'
  local -r _list_end_pattern='}'

  local -r _cmd_sep_pattern='" = "'

  # ———————————————————————————————————————————————————————————————————————— #

  local defaults_raw

  if (( _load_from_cache )) {
    defaults_raw="$( cat "$_cache_file" )"
  } else {
    defaults_raw="$( defaults find "$_defaults_key" | tee "$_cache_file" )"
  }

  # immediately replace all the escape chars with a delimiter
  #  they'll seriously mess things up later if I dont
  defaults_raw="${defaults_raw//\\033/$delim}"

  # ———————————————————————————————————————————————————————————————————————— #

  local -A defaults_parsed

  # autoload -Uz regexp-replace
  setopt rematch_pcre   # for ${match[1]}
  setopt extended_glob  # for ${line/# ##...

  local line bundle_id inner_lines

  for line in "${(@f)defaults_raw}"; {

    # start of key list
    if [[ "$line" =~ "${~_list_start_pattern}" ]] {
      bundle_id="${match[1]}"
      inner_lines=  # reset the inner lines
      continue
    }

    # end of list
    if [[ "$line" == "$_list_end_pattern" ]] {
      # push the contents into the output array
      #  and strip the _final_ newline added by us
      defaults_parsed[$bundle_id]="${inner_lines/%$'\n'}"
      continue
    }

    # if it doesn't start with a quote, it's irrelevant to us
    if [[ ! "$line" =~ "${~_useless_line_pattern}" ]] continue

    # everything else that hasn't been matched before is a keybinding entry
    line="${line/# ##\"}"        # strip the leading spaces and quote
    line="${line/%\";}"          # remove the trailing semicolon and quote

    line="${line/#$delim}"       # strip the leading delimiter, if it exists
    line="${line//$delim/$_sep}" # replace the other delimiters with arrows

    inner_lines+="$line"$'\n'    # add a newline to keep them all separated
  }

  # ———————————————————————————————————————————————————————————————————————— #

  local -a all_lines segments
  local -i 10 max_segments seg_diff
  local raw_lines title command keybind

  for bundle_id raw_lines in "${(@kv)defaults_parsed}"; {
      [[ "$bundle_id" != 'com.google.Chrome' ]] && continue

      #         replace all of the bundle id's chars with an overline ↓
      title="$_dividing_line\n$_bold$bundle_id$_reset\n${bundle_id//?/‾}"

      all_lines=( "${(@f)raw_lines}" )
      max_segments=-1

      for line in "${(@)all_lines}"; {
        segments=( "${(ps:$_sep:)line}" )
        seg_diff=$(( $#segments - max_segments ))
        if (( seg_diff > 0 )) {
          # seg_diff
          max_segments=${#segments}
        }
      }

      echo "$title"
      # echo $max_segments

      for line in "${(@)all_lines}"; {
        command="${line/%$_cmd_sep_pattern*}"
        keybind="${line/#*$_cmd_sep_pattern}"

        echo "${(r:45:: :)command} =⇒ $keybind"
      }

  }

  echo $_dividing_line

}
