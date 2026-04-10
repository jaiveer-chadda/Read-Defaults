#!/usr/bin/env zsh


# keybindings::read
() {

  local -ri 10 _from_cache=1
  local -r _cache_file='../cache/latest.txt'

  local -r _defaults_key='NSUserKeyEquivalents'
  local all_defaults


  if (( _from_cache )) {
    all_defaults="$( cat "$_cache_file" )"
  } else {
    all_defaults="$( defaults find "$_defaults_key" | tee "$_cache_file" )"
  }

  echo "$all_defaults"
  
}

