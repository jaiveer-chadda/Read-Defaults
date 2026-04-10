#!/usr/bin/env zsh

if [[ $ZSH_EVAL_CONTEXT != 'toplevel' ]] return 1


() {

  local -ri 10 _from_cache=1
  local -r _cache_file='../cache/latest.txt'
  local -r _defaults_key='NSUserKeyEquivalents'

  local -ri 10 delim=$RANDOM
  local -r _sep=' -> '

  local defaults_raw

  if (( _from_cache )) {
    defaults_raw="$( cat "$_cache_file" )"
  } else {
    defaults_raw="$( defaults find "$_defaults_key" | tee "$_cache_file" )"
  }

  # immediately replace all the escape chars with a delimiter
  #  they'll seriously mess things up later if I dont
  defaults_raw="${defaults_raw//\\033/$delim}"

  # ———————————————————————————————————————————————————————————————————————— #

  local -A defaults_parsed
  
  local -i 10 is_reading=0
  local line bundle_id inner_lines

  # autoload -Uz regexp-replace
  setopt rematch_pcre
  setopt extended_glob

  for line in "${(@f)defaults_raw}"; {
    
    # start of key list
    if (( ! is_reading )) \
     && [[ "$line" =~ "^Found 1 keys in domain '([^']+)'" ]] {
      bundle_id="${match[1]}"
      inner_lines=  # reset the inner lines
      is_reading=1
      continue
    }

    # end of list
    if (( is_reading )) && [[ "$line" == '}' ]] {
      # push the contents into the output array
      defaults_parsed[$bundle_id]="$inner_lines"
      is_reading=0
      continue
    }

    # if it doesn't start with a quote, it's irrelevant to us
    if (( is_reading )) && [[ ! "$line" =~ '^\s+"' ]] continue

    # everything else that hasn't been matched before is a keybinding entry
    line="${line/# ##\"}"        # strip the leading spaces and quote
    line="${line/%;}"            # remove the trailing semicolon

    line="${line/#$delim}"       # strip the leading delimiter, if it exists
    line="${line//$delim/$_sep}" # replace the other delimiters with arrows

    inner_lines+="$line\n"       # add a newline to keep them all separated
  }

  # ———————————————————————————————————————————————————————————————————————— #

  echo "${(@kvj:\n:)defaults_parsed}"

}
