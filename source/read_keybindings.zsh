#!/usr/bin/env zsh

# if __name__ != "__main__": quit()
#  i.e., if we're being sourced, exit
if [[ $ZSH_EVAL_CONTEXT != 'toplevel' ]] return 1

() {

  # — Constants —————————————————————————————————————————————————————————— #

  local -r _reset=$'\e[0m'
  local -r  _bold=$'\e[1m'
  local -r   _dim=$'\e[2m'

  local -r _dividing_line="$_dim${(r:$COLUMNS::─:)}$_reset"

  local -r _sep=' —→ '
  local -ri 10 _sep_len=${#_sep}
  local -ri 10 delim=$RANDOM  # just an arbitrary number

  local -ri 2 _load_from_cache=1  # might make this a flag at some point
  local -r _cache_file='../cache/latest.txt'
  local -r _defaults_key='NSUserKeyEquivalents'

  local -r _list_start_pattern="^Found 1 keys in domain '([^']+)'"
  local -r _keybinding_line_pattern='^\s+"'
  local -r _list_end_pattern='}'

  local -r _cmd_sep_pattern='" = "'

  # — Read the Raw Data ———————————————————————————————————————————————————— #
  #    - (and do a tiny bit of cleanup)

  local defaults_raw

  if (( _load_from_cache )) {
    defaults_raw="$( cat "$_cache_file" )"
  } else {
    # Note: tee pipes stdin to stdout AND to another file
    #  - this is so we can save the file, as well as pipe it into defaults_raw
    defaults_raw="$( defaults find "$_defaults_key" | tee "$_cache_file" )"
  }

  # `defaults` uses `\033` as a separator between each segment of a command
  #  - eg. `"\033View\033Developer\033Developer Tools" = "~^\024";`
  #    - is actually `"[—→]View—→Developer—→Developer Tools" = "⌥⌃space";`
  #  - so I immediately replace all the `\033`s with a random delimiter
  #    - otherwise they'll seriously mess things up later
  # Note: if you _do_ want to print $defaults_raw before this line,
  #   use `echo -E ...`
  defaults_raw="${defaults_raw//\\033/$delim}"

  # — Read & Sort Keybinding Entries ——————————————————————————————————————— #


  # autoload -Uz regexp-replace  # might need this later
  setopt rematch_pcre   # for ${match[1]}
  setopt extended_glob  # for ${line/# ##...

  local -A defaults_parsed
  local line bundle_id inner_lines

  for line in "${(@f)defaults_raw}"; {

    # start of key list
    if [[ "$line" =~ "${~_list_start_pattern}" ]] {
      bundle_id="${match[1]}"
      # reset the inner lines at each iteration
      inner_lines=
      continue  # nothing else of interest on this line; continue
    }

    # end of list
    if [[ "$line" == "$_list_end_pattern" ]] {
      # push the contents to the output array
      #  and strip the _final_ newline, which is added by us when
      #  we do `inner_lines+=...$'\n'`
      defaults_parsed[$bundle_id]="${inner_lines/%$'\n'}"
      continue  # nothing else of interest on this line; continue
    }

    # if it doesn't start with a quote, it's not of interest to us
    if [[ ! "$line" =~ "${~_keybinding_line_pattern}" ]] continue

    # everything else that hasn't been matched before
    #  is a keybinding entry
    line="${line/# ##\"}"        # strip the leading spaces and quote
    line="${line/%\";}"          # remove the trailing semicolon and quote

    # we're doing the leading delimiter stripping seperately to the spaces,
    #  cos there are a few cases in which the command doesn't have any
    #  segments, in which case it won't have a leading delimiter
    # e.g. "Show All" (in domain 'Apple Global Domain')
    line="${line/#$delim}"       # strip the leading delimiter (if it exists)
    line="${line//$delim/$_sep}" # replace the other delimiters with arrows

    inner_lines+="$line"$'\n'    # add a newline to keep them all separated
    # Note: the last newline of the block will be stripped when pushing it to
    #  the output assoc. array ($defaults_parsed)
  }

  # — Parse & Print the Data ——————————————————————————————————————————————— #

  local -a all_lines segments
  local -i 10 i num_segs diff column_idx  # reusing old var names ↓
  local raw_lines header command keybind bid_underline # bundle_id line

  for bundle_id raw_lines in "${(@kv)defaults_parsed}"; {
    [[ "$bundle_id" != 'com.google.Chrome' ]] && continue  # for testing

    # ——— Parse Keybindings & Make Columns —————————————————————————————— #

    # Note: the reason I'm doing this section in such a convoluted way is
    #  to avoid having to loop over the lines multiple times
    # Essentially:
    #  - for each line, create an array of segments
    #    - (segments being some text between $_sep)
    #  - find out how many segments are on this line
    #    - if the number of segments on this line > the number of segments
    #      we already have, create new arrays for each of those new segments
    #  - we should end up with `N` arrays named `__col_1` -> `__col_N`
    #    - which each will store this domain's segments
    # This is all in the aim of trying to get each segment to line up with
    #  the others - in a table-like way

    # reset all looped data
    all_lines=( "${(@f)raw_lines}" )  # split the captured lines by newline
    num_segs=0

    for line in "${(@)all_lines}"; {
      # for each line, split the segments at every $_sep
      segments=( "${(ps:$_sep:)line}" )

      # then find the length of the newly-created array
      #  and find how much it differs from how many segments we already had
      diff=$(( $#segments - num_segs ))

      # if it's smaller than the previous max size, we don't care about it
      #  (imo this is cleaner than creating an if block for the code below)
      if (( diff <= 0 )) continue

      # then, for every new segment that was created, make a new array
      #  - e.g., if num_segs=0, and diff=2, this line will run:
      #    - local -a __col_1=() __col_2=()
      #  - or if num_segs=2, and diff=1, it'll run:
      #    - local -a __col_3=()
      eval 'local -a' __col_{$(( num_segs + 1 ))..$(( num_segs + diff ))}'=()'

      # finally, adjust the value of num_segs
      #  - this is being done at the end, cos we still need to use the
      #    old value of $num_segs in the eval line
      num_segs=${#segments}
    }

    # ——— Organise Columns —————————————————————————————————————————————— #

    # for i in {1..$num_segs}; {
    #   local -p "__col_$i"
    # }

    # ——— Format Output ————————————————————————————————————————————————— #

    # print the separator line and bundle_id/title
    #  with an underline of the same length as the bundle_id
    # (this type of underline looks better than doing `\e[4m` imo)
    bundle_id="$_bold$bundle_id$_reset"
    bid_underline="${(r:$#bundle_id::‾:)}"

    echo "$_dividing_line\n$bundle_id\n$bid_underline"

    # ——— Print Output —————————————————————————————————————————————————— #

    for line in "${(@)all_lines}"; {
      command="${line/%$_cmd_sep_pattern*}"
      keybind="${line/#*$_cmd_sep_pattern}"

      # 45 is just an arbitrary number for now
      #  - I need to calculate it at some point, but for now, it's big enough
      #    that none of the commands will be truncated when printing
      echo "${(r:45:: :)command} =⇒ $keybind"
    }
  }

  echo $_dividing_line  # a final line, just for aesthetics
}

# ——————————————————————————————————————————————————————————————————————————— #

# spell-checker:ignoreRegExp /(?<=\['[^']+'\]=')[^']+(?=')/g
