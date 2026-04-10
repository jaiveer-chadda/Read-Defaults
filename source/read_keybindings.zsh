#!/usr/bin/env zsh

if [[ $ZSH_EVAL_CONTEXT != 'toplevel' ]] return 1


() {

  local -ri 10 _from_cache=1
  local -r _cache_file='../cache/latest.txt'
  local -r _defaults_key='NSUserKeyEquivalents'

  local -ri 10 delim=$RANDOM

  local defaults_raw

  if (( _from_cache )) {
    defaults_raw="$( cat "$_cache_file" )"
  } else {
    defaults_raw="$( defaults find "$_defaults_key" | tee "$_cache_file" )"
  }

  # immediately replace all the escape chars with a delimiter
  #  they'll seriously mess things up later if I dont
  defaults_raw="${defaults_raw//\\033/>$delim<}"

  # autoload -Uz regexp-replace
  setopt rematch_pcre

  local -A defaults_parsed
  
  local -i 10 is_reading=0
  local line bundle_id inner_lines

  for line in "${(@f)defaults_raw}"; {
    
    # start of key list
    if [[ "$line" =~ "^Found 1 keys in domain '([^']+)'" ]] {
      bundle_id="${match[1]}"
      # reset the inner content
      inner_lines=
      is_reading=1
      continue
    }

    # end of list
    if [[ $is_reading && "$line" == '}' ]] {
      defaults_parsed[$bundle_id]="$inner_lines"
      is_reading=0
      continue
    }

  }

  # echo "$defaults_raw"
  echo "${(@kj:\n:)defaults_parsed}"
}
