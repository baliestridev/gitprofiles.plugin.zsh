# Copyright (c) Bruno Sales <org@baliestri.dev>. Licensed under the MIT License.
# See the LICENSE file in the project root for full license information.

# vim: set ts=4 sw=4 tw=0 et :
#!/usr/bin/env zsh

function __is_git_repo() {
  # if git isnt installes, this will also return false
  if [[ -n "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]]; then
    return 0
  else
    return 1
  fi
}

function __gitprofiles_hook() {
  # make sure we're in a git repo
  if ! __is_git_repo; then
    return 1
  fi

  typeset -A profile_paths_map
  typeset -A profile_cfg_map

  ## Get the path to the profile file
  zstyle -s ":baliestridev:git:profile" path profile_filepath

  ## Check if the file exists
  if [[ ! -f "${profile_filepath}" ]]; then
    return 1
  fi

  # Ensure glob patterns that don't match don't cause errors
  setopt LOCAL_OPTIONS NO_NOMATCH

  ## Load all stored profiles
  local profiles=()
  local current_section=""

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Check for profile section
    if [[ "$line" =~ '^\[profile[[:space:]]+"([^"]+)"\]' ]]; then
      current_section="${match[1]}"
      profiles+=("$current_section")
      # [[ -n "${GP_DEBUG}" ]] && print -u2 "Found profile: ${current_section}"
    fi
  done < "${profile_filepath}"

  ## Check if default profile exists
  if [[ ! "${profiles[(r)default]}" ]]; then
    print -u2 "gitprofiles: 'default' profile not found in '${profile_filepath}'"
    return 1
  fi

  # Function to parse paths into an array and support tilde expansion
  function __parse_paths() {
    local raw_paths="$1"
    # [[ -n "${GP_DEBUG}" ]] && print -u2 "Raw paths input: ${(q)raw_paths}"

    local -a path_lines
    # split on commas or newlines
    path_lines=(${(s:,:)${(f)raw_paths}})

    # Process each line
    local -a paths
    local line
    for line in $path_lines; do
      # remove newlines
      line="${line//'\n'/}"

      # remove quotes
      line="${line//[\"\']}"

      # Remove trailing commas
      line="${line%%,}"

      # Trim whitespace
      line="${line## }"
      line="${line%% }"

      # Expand tildes
      if [[ $line = "~"* ]]; then
        line=${HOME}${line#"~"}
      fi

      # Skip empty lines
      [[ -n "$line" ]] && paths+=("$line")
    done

    # Expand tildes
    #  paths=(${~paths}) # this doesnt work as it expands the glob

    # [[ -n "${GP_DEBUG}" ]] && print -u2 "Final paths: ${paths}"
    print -l -- ${paths}
  }

  ## Parse configuration for each profile
  for profile in ${profiles}; do
    typeset -A profile_value_map
    local in_current_profile=0
    local in_paths=0
    local paths_tmp=()

    while IFS= read -r line; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" == \#* ]] && continue

      # Check for profile section
      if [[ "$line" =~ '^\[profile[[:space:]]+"([^"]+)"\]' ]]; then
        if [[ "${match[1]}" == "$profile" ]]; then
          in_current_profile=1
        else
          in_current_profile=0
          in_paths=0
        fi
        continue
      fi

      # Only process lines for current profile
      (( in_current_profile )) || continue

      # Parse key-value pairs
      if [[ "$line" =~ '^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.*)' ]]; then
        local key="${match[1]## }"    # Trim leading spaces
        key="${key%% }"               # Trim trailing spaces
        local value="${match[2]}"     # Keep spaces in value for now

        case "$key" in
          name|email|signingkey)
            # Remove quotes and trim for non-path values
            value="${value## }"       # Trim leading spaces
            value="${value%% }"       # Trim trailing spaces
            value="${value#[\"\']}"   # Remove leading quote
            value="${value%[\"\']}"   # Remove trailing quote
            profile_value_map[$key]="$value"
            ;;
          path|paths)
            in_paths=1
            paths_tmp=("$value")
            ;;
        esac
      elif (( in_paths )) && [[ "$line" =~ '^[[:space:]]+(.*)' ]]; then
        # Handle indented continuation lines for paths
        local value="${match[1]}"
        paths_tmp+=("$value")
      fi
    done < "${profile_filepath}"

    # Join and parse paths
    if (( ${#paths_tmp} > 0 )); then
      local joined_paths="${(j:\n:)paths_tmp}"
      profile_paths_map[$profile]="${(@f)$(__parse_paths "$joined_paths")}"
    fi

    # Store other configurations
    profile_cfg_map[$profile.name]="${profile_value_map[name]}"
    profile_cfg_map[$profile.email]="${profile_value_map[email]}"

    if [[ -n "${profile_value_map[signingkey]}" ]]; then
      profile_cfg_map[$profile.signingkey]="${profile_value_map[signingkey]}"
    fi
  done

  # Get current directory
  local current_dir=$(pwd)
  local matched_profile="default"

  [[ -n "${GP_DEBUG}" ]] && print -u2 "Current directory: ${current_dir}"

  # First pass: Check for exact matches
  for profile in ${(k)profile_paths_map}; do
    [[ -n "${GP_DEBUG}" ]] && print -u2 "Testing Profile (exact): ${profile}"

    local paths=(${=profile_paths_map[$profile]})  # Convert to array
    for path_pattern in $paths; do
      # Only do exact match if pattern doesn't contain a wildcard
      if [[ ! $path_pattern =~ '[*?]' ]] && [[ "${current_dir}" = "${path_pattern}" ]]; then
        [[ -n "${GP_DEBUG}" ]] && print -u2 "Matched (exact) path: ${path_pattern}"
        matched_profile="${profile}"
        break 2
      fi
    done
  done

  # Second pass: Check for wildcard matches (only if no exact match found)
  if [[ "${matched_profile}" = "default" ]]; then
    for profile in ${(k)profile_paths_map}; do
      [[ -n "${GP_DEBUG}" ]] && print -u2 "Testing Profile (wildcard): ${profile}"

      local paths=(${=profile_paths_map[$profile]})  # Convert to array
      for path_pattern in $paths; do
        # Only do regex match if we have a wildcard
        if [[ $path_pattern =~ '[*?]' ]] && [[ "${current_dir}" =~ "${path_pattern}" ]]; then
        [[ -n "${GP_DEBUG}" ]] && print -u2 "Matched (*) path: ${path_pattern}"
          matched_profile="${profile}"
          break 2
        fi
      done
    done
  fi

  ## Set the current profile name and email
  git config --global user.name "${profile_cfg_map[${matched_profile}.name]}"
  git config --global user.email "${profile_cfg_map[${matched_profile}.email]}"

  ## Set the current profile signingkey if it exists
  if [[ -n "${profile_cfg_map[${matched_profile}.signingkey]}" ]]; then
    git config --global user.signingkey "${profile_cfg_map[${matched_profile}.signingkey]}"
  fi

  # Print debug information if GP_DEBUG is set
  if [[ -n "${GP_DEBUG}" ]] && [[ -n "${matched_profile}" ]]; then
    print -u2 "Matched profile: ${matched_profile}"
    print -u2 "Using configuration:"
    print -u2 "  name: ${profile_cfg_map[${matched_profile}.name]}"
    print -u2 "  email: ${profile_cfg_map[${matched_profile}.email]}"
    if [[ -n "${profile_cfg_map[${matched_profile}.signingkey]}" ]]; then
      print -u2 "  signingkey: ${profile_cfg_map[${matched_profile}.signingkey]}"
    fi
  fi
}

add-zsh-hook chpwd __gitprofiles_hook
