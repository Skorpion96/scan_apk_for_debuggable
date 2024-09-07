#!/bin/bash

# Function to check if required tools are installed
check_tools() {
    if ! command -v apktool &> /dev/null; then
        echo "Error: apktool is not installed. Please install apktool to use this script."
        exit 1
    fi
    if ! command -v aapt &> /dev/null; then
        echo "Error: aapt is not installed. Please install aapt to use this script."
        exit 1
    fi
}

# Help function to explain how to use the script
print_help() {
    echo "Usage: ./scan_apk_for_debuggable.sh [directory] [report.txt]"
    echo "       ./scan_apk_for_debuggable.sh [directory] --report-debuggable-only [report.txt]"
    echo
    echo "Options:"
    echo "  -h, --help                      Show this help message."
    echo "  --report-debuggable-only [file]   Generate a report containing debuggable apps sorted by their uids and if there aren't will put them in a 2nd list."
    echo "  [directory]                     Scan APKs in directory without creating a report."
    echo
    echo "Description:"
    echo "  This script scans APK files in a specified directory, identifies debuggable apps sorting eventually them by their uid, and generates a report."
    echo "  The report can be either a full report of all scan or limited to debuggable apps sorted by their uid."
    echo "Examples:"
    echo "  ./scan_apk_for_debuggable.sh /path/to/apk/files"
    echo "  ./scan_apk_for_debuggable.sh /path/to/apk/files report.txt"
    echo "  ./scan_apk_for_debuggable.sh /path/to/apk/files --report-debuggable-only report.txt"
    exit 0
}

# Error function for wrong usage
error_usage() {
    echo "Error: Invalid usage."
    echo "Use ./scan_apk_for_debuggable.sh -h or --help for usage instructions."
    exit 1
}

# Check if the help option is called
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print_help
fi

# Check if the correct number of arguments are provided
if [[ $# -lt 1 ]]; then
    error_usage
fi

# Validate arguments
if [[ ! -d "$1" ]]; then
    echo "Error: The first argument must be a valid directory."
    exit 1
fi

# Check if required tools are installed
check_tools

# Directory containing APK files
directory="$1"
output_file="$2"
debuggable_only_report=false
no_report=false

# Determine if we're generating a report or just running the scan
if [[ "$2" == "--report-debuggable-only" ]]; then
    if [[ -z "$3" ]]; then
        error_usage
    fi
    debuggable_only_report=true
    output_file="$3"
elif [[ -z "$2" ]]; then
    no_report=true
fi

declare -A shared_uid_map
declare -a no_shared_uid_apps
declare -a debuggable_apps

# Function to strip the directory path from the filename
strip_directory() {
    echo "$(basename "$1")"
}

# Function to print and optionally write output to file and terminal simultaneously
write_output() {
    echo "$1"  # Print to terminal
    if [[ -n "$output_file" && "$no_report" == false ]]; then
        echo "$1" >> "$output_file"  # Write to file if output file is specified
    fi
}

# Function to print the summary after scanning
print_summary() {
    write_output ""
    write_output "===== Debuggable Apps Report ====="
    
    # Print apps grouped by shared UID
    if [ ${#shared_uid_map[@]} -gt 0 ]; then
        for uid in "${!shared_uid_map[@]}"; do
            write_output "Shared UID: $uid"
            write_output "Apps: ${shared_uid_map[$uid]}"
            write_output ""
        done
    fi

    # Print apps without shared UID
    if [ ${#no_shared_uid_apps[@]} -gt 0 ]; then
        write_output "Apps without shared UID:"
        for app in "${no_shared_uid_apps[@]}"; do
            write_output "$app"
        done
    else
        write_output "No debuggable apps found."
    fi
}

# Function to print the final report on debuggable apps only (for -report-debuggable-only option)
report_debuggable_only() {
    print_summary
    
    # Now using sed to cut the output before "===== Debuggable Apps Report =====" in the report file
    if [[ -n "$output_file" ]]; then
        sed -i '1,/===== Debuggable Apps Report =====/d' "$output_file"
    fi
}

# Function to print the full report
report_full() {
    write_output ""
    write_output "===== Full Debuggable Apps Report ====="
    
    if [ ${#debuggable_apps[@]} -eq 0 ]; then
        write_output "No debuggable apps found."
        return
    fi

    # Print apps grouped by shared UID
    if [ ${#shared_uid_map[@]} -gt 0 ]; then
        for uid in "${!shared_uid_map[@]}"; do
            write_output "Shared UID: $uid"
            write_output "Apps: ${shared_uid_map[$uid]}"
            write_output ""
        done
    fi

    # Print apps without shared UID
    if [ ${#no_shared_uid_apps[@]} -gt 0 ]; then
        write_output "Apps without shared UID:"
        for app in "${no_shared_uid_apps[@]}"; do
            write_output "$app"
        done
    fi
}

# Function to print the summary after scanning
print_summary() {
    write_output ""
    write_output "===== Debuggable Apps Report ====="
    
    if [ ${#debuggable_apps[@]} -eq 0 ]; then
        write_output "No debuggable apps found."
        return
    fi

    # Print apps grouped by shared UID
    if [ ${#shared_uid_map[@]} -gt 0 ]; then
        for uid in "${!shared_uid_map[@]}"; do
            write_output "Shared UID: $uid"
            write_output "Apps: ${shared_uid_map[$uid]}"
            write_output ""
        done
    fi

    # Print apps without shared UID
    if [ ${#no_shared_uid_apps[@]} -gt 0 ]; then
        write_output "Apps without shared UID:"
        for app in "${no_shared_uid_apps[@]}"; do
            write_output "$app"
        done
    fi
}

# Iterate over files in the directory
for file in "$directory"/*; do
    # Check if the file is an APK
    if [[ "$file" == *.apk ]]; then
        # Use apktool to decompile the APK
        apktool d "$file" -o "${file}_decompiled" &>/dev/null

        # Check if the decompilation was successful
        if [[ $? -eq 0 ]]; then
            debuggable_status="No"
            
            # Check if the decompiled files contain debuggable indicators
            if grep -Rq "android:debuggable=\"true\"" "${file}_decompiled"; then
                debuggable_status="Yes"
                debuggable_apps+=("$(strip_directory "$file")")
            fi

            # Find and extract the sharedUserId from AndroidManifest.xml if it exists
            shared_uid=$(grep -Po '(?<=android:sharedUserId=")[^"]*' "${file}_decompiled/AndroidManifest.xml")

            # Store data for debuggable report only if debuggable
            if [[ "$debuggable_status" == "Yes" ]]; then
                if [[ -n "$shared_uid" ]]; then
                    shared_uid_map["$shared_uid"]+="$(strip_directory "$file") "
                else
                    no_shared_uid_apps+=("$(strip_directory "$file")")
                fi
            fi

            # Print debuggable status and shared UID for each app in both modes
            write_output "APK: $(strip_directory "$file")"
            write_output "Debuggable: $debuggable_status"
            
            if [[ -n "$shared_uid" ]]; then
                write_output "Shared UID: $shared_uid"
            else
                write_output "Shared UID: None"
            fi

            write_output ""

            # Remove the decompiled directory
            rm -rf "${file}_decompiled"
        else
            write_output "Failed to decompile APK: $(strip_directory "$file")"
            rm -rf "${file}_decompiled"
        fi
    fi
done

# If not in debug-only mode and not skipping report, print the full report and summary of debuggable apps
if [[ "$debuggable_only_report" == false && "$no_report" == false ]]; then
    # Print debuggable apps summary
    if [ ${#debuggable_apps[@]} -gt 0 ]; then
        write_output "Debuggable apps found:"
        for app in "${debuggable_apps[@]}"; do
            write_output "$app"
        done
    else
        write_output "No debuggable apps found."
    fi

    # Print the full report of debuggable apps grouped by shared UID
    report_full
elif [[ "$debuggable_only_report" == true ]]; then
    # If in debug-only mode, print only the debuggable apps grouped by shared UID
    report_debuggable_only
fi

# If no report, print the summary in the terminal at the end
if [[ "$no_report" == true ]]; then
    print_summary
fi

# Notify user if a report has been generated
if [[ -n "$output_file" ]]; then
    echo "Report saved to $output_file"
fi
