#!/usr/bin/env zsh

# if __name__ != "__main__": quit()
#  i.e.: if we're being sourced (not run directly), then exit
if [[ $ZSH_EVAL_CONTEXT != 'toplevel' ]] return 1

() {
  local PS4=$'%F{red}+ %N:%I%F{blue}\t>%f '
  # — Constants —————————————————————————————————————————————————————————— #

  # General / Util Strings
  local -r NL=$'\n'

  # Graphical ANSI Esc Codes
  local -r _reset=$'\e[0m'

  local -r   _red=$'\e[31m'
  local -r  _blue=$'\e[34m'
  local -r _mgnta=$'\e[35m'

  local -r  _bold=$'\e[1m'
  local -r   _dim=$'\e[2m'

  # Formating / Visual Literals
  local -r _command_sep=' —→ '  # — em-dash   → right arrow
  local -r _keybind_sep=' =⇒ '  # = equals    ⇒ right double arrow
  local -r _underline_char='▔'  # ▔ upper 1⁄8th block  
  local -r _divider_char='─'    # ─ hor. box drawing char

  local -r _dividing_line="${(pr:$COLUMNS::$_divider_char:)}"

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
      inner_lines=  # reset the inner lines at each iteration
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

  local -a all_lines segments line_arr cmd_segs
  local -i 10 line_no total_segs seg_no diff
  local -i 10 seg_len __seg_n_max_len
  local raw_lines command keybind bid_underline segment

  for domain_bid raw_lines in "${(@kv)defaults_parsed}"; {
    # ↓↓ debug line ↓↓
    # [[ "$domain_bid" != 'com.google.Chrome' ]] && continue

    # ——— Create Columns ———————————————————————————————————————————————— #

    # reset all looped data
    total_segs=0
    all_lines=( "${(@f)raw_lines}" )  # split the captured lines by newline

    for line_no in {1.."${#all_lines}"}; {
      line="${all_lines[$line_no]}"

      command="${line/%$_cmd_sep_pattern*}"
      keybind="${line/#*$_cmd_sep_pattern}"

      segments=( "${(ps:$delim:)command}" )
      eval 'local -a __line_'$line_no'=( "${(@)segments}" "$keybind" )'

      diff=$(( $#segments - total_segs ))

      # create a new max len counter for each new segment that's found
      if (( diff > 0 )) {
        for seg_no in {$(( total_segs + 1 ))..$(( total_segs + diff ))}; {
          eval "local -i 10 __seg_${seg_no}_max_len=0"
        }
        total_segs=$#segments
      }

      for seg_no in {1..$total_segs}; {
        # unloading the max len into $__seg_n_max_len so I don't have to
        #  do eval statements through this whole for loop
        eval '__seg_n_max_len=$__seg_'$seg_no'_max_len'
        seg_len=${#segments[$seg_no]}

        if (( seg_len > __seg_n_max_len )) \
          __seg_n_max_len=$seg_len

        eval '__seg_'$seg_no'_max_len=$__seg_n_max_len'
      }

    }

    # ——————————————————————————————————————————————————————————————————— #
    # ——— Format Title —————————————————————————————————————————————————— #

    # print the separator line and domain_bid/title
    #  with an underline of the same length as the domain_bid
    # (this type of underline looks better than doing `\e[4m` imo)
    bid_underline="${(pr:$#domain_bid::$_underline_char:)}"

    # finally, replace all the delimiters with separator arrows
    #  (tho this will probably be changed once I make the column system)
    all_lines=( "${(@)all_lines//$delim/$_command_sep}" )

    # ——— Print Output —————————————————————————————————————————————————— #

    echo -ne "$_reset$_blue$_dim"
    echo "$_dividing_line"

    echo -ne "$_reset$_blue$_bold"
    echo "$domain_bid"

    echo -ne "$_reset$_blue$_dim"
    echo "$bid_underline$_reset"


    for line_no in {1.."${#all_lines}"}; {
      # unload the line's contents into $line_arr
      #  - again, so I don't have to run eval multiple times
      eval 'line_arr=( ${(@)__line_'$line_no'} )'
      cmd_segs=( "${(@)line_arr[1,-2]}" )
      keybind="${line_arr[-1]}"

      for seg_no in {1..$total_segs}; {
        segment="${cmd_segs[$seg_no]}"

        # using old-style if/else here, cos honestly it's
        #  just a bit cleaner & clearer in this case
        if (( seg_no != 1 )) {
          [[ -n "$segment" ]]         \
            && echo -n "$_red$_command_sep$_reset"  \
            || echo -n "${(r:$#_command_sep:: :)}"
        }

        # unload the segment's max len into $seg_len
        #  then right-pad (left-align) each segment to that len
        # I could do this in one line, but honestly, this looks/feels nicer
        eval 'seg_len=$__seg_'$seg_no'_max_len'
        echo -n "${(r:$seg_len:: :)segment}"
      }

      echo "$_mgnta$_keybind_sep$_reset$keybind"
    }

  }

  echo $_dividing_line  # a final line, just for aesthetics
}

# ——————————————————————————————————————————————————————————————————————————— #

# spell-checker:ignoreRegExp /(?<=\['[^']+'\]=')[^']+(?=')|mgnta/g
