#!/usr/bin/env zsh

# if __name__ != "__main__": quit()
#  i.e.: if we're being sourced (not run directly), then exit
if [[ $ZSH_EVAL_CONTEXT != 'toplevel' ]] return 1

() {

  # — Constants —————————————————————————————————————————————————————————— #

  # General / Util Strings
  local -r NL=$'\n'

  # Graphical ANSI Esc Codes
  local -r _reset=$'\e[0m'
  local -r  _bold=$'\e[1m'
  local -r   _dim=$'\e[2m'

  # Formating / Visual Literals
  local -r _command_sep=' —→ '  # — em-dash   → right arrow
  local -r _keybind_sep=' =⇒ '  # = equals    ⇒ right double arrow
  local -r _underline_char='‾'  # ‾ overline
  local -r _divider_char='─'    # ─ hor. box drawing char

  local -r _dividing_line="$_dim${(pr:$COLUMNS::$_divider_char:)}$_reset"
  
  # Delimiters / Arbitrary Separators
  local -ri 10 delim=$RANDOM  # just an arbitrary number
  
  # Parsing & `domains` Patterns
  local -r _list_start_pattern="^Found 1 keys in domain '([^']+)'"
  local -r _list_content_pattern='^\s+"'
  local -r _list_end_pattern='}'
  local -r _cmd_sep_pattern='" = "'

  # Data Loading & Caching
  local -r _defaults_key='NSUserKeyEquivalents'
  local -r _cache_file='../cache/latest.txt'
  local -ri 2 _load_from_cache=1  # might make this a flag at some point

  # ———————————————————————————————————————————————————————————————————————— #
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

  # ———————————————————————————————————————————————————————————————————————— #
  # — Read & Sort Keybinding Entries ——————————————————————————————————————— #

  # autoload -Uz regexp-replace  # might need this later
  setopt rematch_pcre   # used for: `${match[1]}`
  setopt extended_glob  # used for: `${line/# ##...`

  local -A defaults_parsed
  local line domain_bid inner_lines

  for line in "${(@f)defaults_raw}"; {

    # start of key list
    if [[ "$line" =~ "${~_list_start_pattern}" ]] {
      domain_bid="${match[1]}"
      # reset the inner lines at each iteration
      inner_lines=
      continue  # nothing else of interest on this line; continue
    }

    # end of list
    if [[ "$line" == "$_list_end_pattern" ]] {
      # push the contents to the output array
      #  and strip the _final_ newline, which is added by us when
      #  we do `inner_lines+=...$NL`
      defaults_parsed[$domain_bid]="${inner_lines/%$NL}"
      continue  # nothing else of interest on this line; continue
    }

    # if it doesn't start with a quote, it's not of interest to us
    if [[ ! "$line" =~ "${~_list_content_pattern}" ]] continue

    # any line that remains is a keybinding entry line

    # Note: we're stripping the leading delimiter separately from the spaces,
    #  cos there are a few cases in which the command doesn't have any
    #  segments, in which case it won't have a leading delimiter
    # e.g. "Show All" (in domain 'Apple Global Domain')
    line="${line/# ##\"}"   # strip the leading spaces and quote
    line="${line/%\";}"     # remove the trailing semicolon and quote
    line="${line/#$delim}"  # strip the leading delimiter (if it exists)

    inner_lines+="$line$NL" # add a newline to keep them all separated
    # Note: the last newline of the block will be stripped when pushing it to
    #  the output array
  }

  # ———————————————————————————————————————————————————————————————————————— #
  # — Parse & Print Data ——————————————————————————————————————————————————— #

  local -a all_lines segments
  local -i 10 i num_segs diff column_idx  # reusing old var names ↓
  local raw_lines header command keybind bid_underline # domain_bid line

  for domain_bid raw_lines in "${(@kv)defaults_parsed}"; {
    # ↓↓ debug line ↓↓
    # [[ "$domain_bid" != 'com.google.Chrome' ]] && continue

    # ——— Create Columns ———————————————————————————————————————————————— #

    # Note: the reason I'm doing this section in such a convoluted way is
    #  to avoid having to loop over the lines multiple times
    # Essentially:
    #  - for each line, create an array of segments
    #    - (segments being some text between $_command_sep)
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
      # for each line, split the segments at each delimiter
      segments=( "${(ps:$delim:)line}" )

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

    # ——————————————————————————————————————————————————————————————————— #
    # ——— Format Output ————————————————————————————————————————————————— #

    # print the separator line and domain_bid/title
    #  with an underline of the same length as the domain_bid
    # (this type of underline looks better than doing `\e[4m` imo)
    bid_underline="${(pr:$#domain_bid::$_underline_char:)}"
    domain_bid="$_bold$domain_bid$_reset"

    # finally, replace all the delimiters with separator arrows
    #  (tho this will probably be changed once I make the column system)
    all_lines=( "${(@)all_lines//$delim/$_command_sep}" )

    # ——————————————————————————————————————————————————————————————————— #
    # ——— Print Output —————————————————————————————————————————————————— #

    echo "$_dividing_line\n$domain_bid\n$bid_underline"

    for line in "${(@)all_lines}"; {
      command="${line/%$_cmd_sep_pattern*}"
      keybind="${line/#*$_cmd_sep_pattern}"

      # 45 is just an arbitrary number for now
      #  - I need to calculate it at some point, but for now, it's big enough
      #    that none of the commands will be truncated when printing
      echo "${(r:52:: :)command}$_keybind_sep$keybind"
    }
  }

  echo $_dividing_line  # a final line, just for aesthetics
}

# ——————————————————————————————————————————————————————————————————————————— #

# spell-checker:ignoreRegExp /(?<=\['[^']+'\]=')[^']+(?=')/g
