#!/usr/lib/dodate/dodate_env/bin/python3
# -*- coding: utf-8 -*-

"""
dodate - A simple utility to display the current time in different regions.
"""

import datetime
import pytz
import os
import sys

# ANSI color codes for colorful output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def get_formatted_time(timezone_str):
    """Get the current time in the specified timezone."""
    tz = pytz.timezone(timezone_str)
    current_time = datetime.datetime.now(tz)
    return current_time.strftime("%H:%M:%S"), current_time.strftime("%d-%m-%Y")

def main():
    """Display the current time in Réunion, Guadeloupe, and local time (France)."""
    # Check if pytz is installed
    try:
        import pytz
    except ImportError:
        print(f"{Colors.RED}Error: The required 'pytz' package is not installed.{Colors.ENDC}")
        print(f"Please install it using: pip install pytz")
        sys.exit(1)

    print(f"\n{Colors.BOLD}===== Current Time in Different Regions ====={Colors.ENDC}\n")

    # Define regions and their corresponding timezones
    regions = [
        ("🇷🇪 Réunion", "Indian/Reunion"),
        ("🇬🇵 Guadeloupe", "America/Guadeloupe"),
        ("🇫🇷 Heure Locale (France)", "Europe/Paris")
    ]

    # Get and display the time for each region
    max_region_length = max(len(region[0]) for region in regions)

    for region_name, timezone_str in regions:
        time_str, date_str = get_formatted_time(timezone_str)

        # Format the output with padding for alignment
        padding = " " * (max_region_length - len(region_name))
        print(f"{Colors.BOLD}{region_name}:{padding}{Colors.ENDC} {Colors.GREEN}{time_str}{Colors.ENDC} | {Colors.YELLOW}{date_str}{Colors.ENDC}")

    print(f"\n{Colors.CYAN}(Developed for Debian Package Tutorial){Colors.ENDC}")

if __name__ == "__main__":
    main()
