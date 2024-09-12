#!/bin/bash
check_tools() {
    if ! command -v aapt &> /dev/null; then
        echo "Error: aapt is not installed. Please install aapt to use this script."
        exit 1
    fi
}

print_help() {
    echo "Usage: ./scan_apk_for_debuggable.sh [directory] [report.txt]"
    echo "       ./scan_apk_for_debuggable.sh [directory] --report-debuggable-only [report.txt]"
    echo
    echo "Options:"
    echo "  -h, --help                      Show this help message."
    echo "  --report-debuggable-only [file]   Generate a report containing debuggable apps sorted by their UIDs."
    echo "  [directory]                     Scan APKs in the directory without creating a report."
    echo
    echo "Examples:"
    echo "  ./scan_apk_for_debuggable.sh /path/to/apk/files"
    echo "  ./scan_apk_for_debuggable.sh /path/to/apk/files report.txt"
    exit 0
}

error_usage() {
    echo "Error: Invalid usage."
    echo "Use ./scan_apk_for_debuggable.sh -h or --help for usage instructions."
    exit 1
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print_help
fi

if [[ $# -lt 1 ]]; then
    error_usage
fi

if [[ ! -d "$1" ]]; then
    echo "Error: The first argument must be a valid directory."
    exit 1
fi
check_tools
directory="$1"
output_file="$2"
debuggable_only_report=false
no_report=false

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

strip_directory() {
    echo "$(basename "$1")"
}
write_output() {
    echo "$1"  # Print to terminal
    if [[ -n "$output_file" && "$no_report" == false ]]; then
        echo "$1" >> "$output_file"  # Write to file if output file is specified
    fi
}
report_full() {
    write_output ""
    write_output "===== Full Debuggable Apps Report ====="

    if [ ${#debuggable_apps[@]} -eq 0 ]; then
        write_output "No debuggable apps found."
    fi
    if [ ${#shared_uid_map[@]} -gt 0 ]; then
        for uid in "${!shared_uid_map[@]}"; do
            write_output "Shared UID: $uid"
            write_output "Apps: ${shared_uid_map[$uid]}"
            write_output ""
        done
    fi
    if [ ${#no_shared_uid_apps[@]} -gt 0 ]; then
        write_output "Apps without shared UID:"
        for app in "${no_shared_uid_apps[@]}"; do
            write_output "$app"
        done
    fi
}
report_debuggable_only() {
    write_output ""
    write_output "===== Debuggable Apps Report (Debuggable Only) ====="

    if [ ${#debuggable_apps[@]} -eq 0 ]; then
        write_output "No debuggable apps found."
        return
    fi
    if [ ${#shared_uid_map[@]} -gt 0 ]; then
        for uid in "${!shared_uid_map[@]}"; do
            if [[ -n "${shared_uid_map[$uid]}" ]]; then
                write_output "Shared UID: $uid"
                write_output "Apps: ${shared_uid_map[$uid]}"
                write_output ""
            fi
        done
    fi
    if [ ${#no_shared_uid_apps[@]} -gt 0 ]; then
        write_output "Apps without shared UID:"
        for app in "${no_shared_uid_apps[@]}"; do
            write_output "$app"
        done
    fi
    if [[ -n "$output_file" ]]; then
        sed -i '1,/===== Debuggable Apps Report (Debuggable Only) =====/d' "$output_file"
    fi
}
for file in "$directory"/*.apk; do
    if [[ "$file" == *.apk ]]; then
        debuggable_status="Unknown"
        aapt dump xmltree "$file" AndroidManifest.xml &> "${file}_manifest.txt"
        if grep -q 'android:debuggable(0x0101000f)=(type 0x12)0xffffffff' "${file}_manifest.txt"; then
            debuggable_status="Yes"
            debuggable_apps+=("$(strip_directory "$file")")
        else
            debuggable_status="No"
        fi
        shared_uid=$(grep -Po 'android:sharedUserId\(.*\)="\K[^"]+' "${file}_manifest.txt")
        write_output "APK: $(strip_directory "$file")"
        write_output "Debuggable: $debuggable_status"
        
        if [[ -n "$shared_uid" ]]; then
            write_output "Shared UID: $shared_uid"
        else
            write_output "Shared UID: None"
        fi

        write_output ""
        if [[ "$debuggable_status" == "Yes" ]]; then
            if [[ -n "$shared_uid" ]]; then
                shared_uid_map["$shared_uid"]+="$(strip_directory "$file") "
            else
                no_shared_uid_apps+=("$(strip_directory "$file")")
            fi
        fi
        rm -f "${file}_manifest.txt"
    fi
done
if [[ "$debuggable_only_report" == false && "$no_report" == false ]]; then
    report_full
    if [[ -n "$output_file" ]]; then
        echo "Report saved to $output_file"
    fi
elif [[ "$debuggable_only_report" == true ]]; then
    report_debuggable_only
    if [[ -n "$output_file" ]]; then
        echo "Report saved to $output_file"
    fi
fi
print_summary() {
    echo ""
    echo "===== Scan Summary ====="
    if [ ${#shared_uid_map[@]} -gt 0 ]; then
        for uid in "${!shared_uid_map[@]}"; do
            echo "Shared UID: $uid"
            echo "Apps: ${shared_uid_map[$uid]}"
            echo ""
        done
    fi
    if [ ${#no_shared_uid_apps[@]} -gt 0 ]; then
        echo "Apps without shared UID:"
        for app in "${no_shared_uid_apps[@]}"; do
            echo "$app"
        done
    fi
}
if [[ "$no_report" == true ]]; then
    print_summary
fi
