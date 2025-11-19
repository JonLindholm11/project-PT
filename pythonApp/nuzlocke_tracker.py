#!/usr/bin/env python3
"""
Nuzlocke Tracker - Python Application
Monitors Lua script output and sends events to .NET backend API
"""

import requests
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import json
import logging


class BackendAPIClient:
    """Handles communication with .NET backend API"""
    
    def __init__(self, base_url: str = "http://localhost:5000/api", 
                 api_key: Optional[str] = None):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.session = requests.Session()
        
        # Set up headers
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'NuzlockeTracker-Python/1.0'
        })
        
        if api_key:
            self.session.headers.update({
                'Authorization': f'Bearer {api_key}'
            })
        
        logging.info(f"✓ API Client initialized: {self.base_url}")
    
    def send_event(self, event: Dict) -> bool:
        """Send an event to the backend API"""
        try:
            # Add timestamp if not present
            if 'timestamp' not in event:
                event['timestamp'] = datetime.utcnow().isoformat()
            
            response = self.session.post(
                f"{self.base_url}/events",
                json=event,
                timeout=10
            )
            
            if response.status_code in [200, 201]:
                logging.info(f"✓ Event sent: {event['type']} for {event['pid']}")
                return True
            else:
                logging.error(
                    f"✗ Failed to send event: {response.status_code} - {response.text}"
                )
                return False
                
        except requests.exceptions.ConnectionError:
            logging.error("✗ Connection error - is the backend running?")
            return False
        except requests.exceptions.Timeout:
            logging.error("✗ Request timeout")
            return False
        except Exception as e:
            logging.error(f"✗ Error sending event: {e}")
            return False
    
    def health_check(self) -> bool:
        """Check if backend API is accessible"""
        try:
            response = self.session.get(
                f"{self.base_url}/health",
                timeout=5
            )
            return response.status_code == 200
        except:
            return False


class LuaOutputParser:
    """Parses Lua script output to extract events"""
    
    # Regex patterns for different event types
    PATTERNS = {
        'CATCH': re.compile(
            r'NEW: Species (\d+) caught! \(PID: (0x[0-9A-F]+), Location: (\w+)\)'
        ),
        'DEATH': re.compile(
            r'DEATH: Species (\d+) fainted! \(PID: (0x[0-9A-F]+)\)'
        ),
        'EVOLUTION': re.compile(
            r'EVOLUTION: Species (\d+) evolved to (\d+) \(PID: (0x[0-9A-F]+)\)'
        ),
        'LEVEL_UP': re.compile(
            r'LEVEL UP: Species (\d+) leveled up (\d+) -> (\d+) \(PID: (0x[0-9A-F]+)\)'
        ),
        'LOCATION_CHANGE': re.compile(
            r'MOVED: Species (\d+) moved from (\w+) to (\w+) \(PID: (0x[0-9A-F]+)\)'
        ),
        'REMOVED': re.compile(
            r'REMOVED: Species (\d+) no longer in save \(PID: (0x[0-9A-F]+)\)'
        )
    }
    
    @classmethod
    def parse_line(cls, line: str) -> Optional[Dict]:
        """Parse a single line of output"""
        line = line.strip()
        
        for event_type, pattern in cls.PATTERNS.items():
            match = pattern.search(line)
            if match:
                return cls._extract_event(event_type, match)
        
        return None
    
    @classmethod
    def _extract_event(cls, event_type: str, match) -> Dict:
        """Extract event data from regex match"""
        if event_type == 'CATCH':
            return {
                'type': 'CATCH',
                'species': int(match.group(1)),
                'pid': match.group(2),
                'location': match.group(3)
            }
        
        elif event_type == 'DEATH':
            return {
                'type': 'DEATH',
                'species': int(match.group(1)),
                'pid': match.group(2)
            }
        
        elif event_type == 'EVOLUTION':
            return {
                'type': 'EVOLUTION',
                'old_species': int(match.group(1)),
                'new_species': int(match.group(2)),
                'pid': match.group(3)
            }
        
        elif event_type == 'LEVEL_UP':
            return {
                'type': 'LEVEL_UP',
                'species': int(match.group(1)),
                'old_level': int(match.group(2)),
                'new_level': int(match.group(3)),
                'pid': match.group(4)
            }
        
        elif event_type == 'LOCATION_CHANGE':
            return {
                'type': 'LOCATION_CHANGE',
                'species': int(match.group(1)),
                'from_location': match.group(2),
                'to_location': match.group(3),
                'pid': match.group(4)
            }
        
        elif event_type == 'REMOVED':
            return {
                'type': 'REMOVED',
                'species': int(match.group(1)),
                'pid': match.group(2)
            }
        
        return None


class NuzlockeTracker:
    """Main tracker application"""
    
    def __init__(self, api_url: str = "http://localhost:5000/api", 
                 api_key: Optional[str] = None):
        self.api = BackendAPIClient(api_url, api_key)
        self.parser = LuaOutputParser()
        logging.info("✓ Nuzlocke Tracker initialized")
    
    def process_event(self, event: Dict):
        """Process a parsed event and send to backend"""
        event_type = event['type']
        pid = event['pid']
        
        logging.info(f"  Processing {event_type} for {pid}")
        
        # Send the event directly to backend
        success = self.api.send_event(event)
        
        if not success:
            logging.warning(f"  Failed to send {event_type} event")
        
        return success
    
    def monitor_log_file(self, log_file: str, interval: float = 1.0):
        """Monitor a log file for new events (tail -f style)"""
        log_path = Path(log_file)
        
        if not log_path.exists():
            logging.warning(f"Log file not found: {log_file}")
            logging.info("Waiting for log file to be created...")
        
        # Wait for file to exist
        while not log_path.exists():
            time.sleep(interval)
        
        logging.info(f"✓ Monitoring: {log_file}")
        
        with open(log_path, 'r') as f:
            # Seek to end of file
            f.seek(0, 2)
            
            while True:
                line = f.readline()
                
                if line:
                    # Parse and process the line
                    event = self.parser.parse_line(line)
                    if event:
                        self.process_event(event)
                else:
                    # No new line, wait a bit
                    time.sleep(interval)
    
    def process_log_file(self, log_file: str):
        """Process entire log file (parse existing content)"""
        log_path = Path(log_file)
        
        if not log_path.exists():
            logging.error(f"Log file not found: {log_file}")
            return
        
        logging.info(f"Processing log file: {log_file}")
        event_count = 0
        
        with open(log_path, 'r') as f:
            for line in f:
                event = self.parser.parse_line(line)
                if event:
                    if self.process_event(event):
                        event_count += 1
        
        logging.info(f"✓ Processed {event_count} events")
    
    def monitor_stdin(self):
        """Monitor stdin for Lua output (for piped input)"""
        logging.info("✓ Monitoring stdin for events...")
        
        try:
            while True:
                line = input()
                event = self.parser.parse_line(line)
                if event:
                    self.process_event(event)
        except EOFError:
            logging.info("✓ Input stream closed")
        except KeyboardInterrupt:
            logging.info("\n✓ Monitoring stopped")


def main():
    """Main entry point"""
    import argparse
    
    # Set up logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    parser = argparse.ArgumentParser(
        description='Nuzlocke Tracker - Monitor Lua script and send events to backend'
    )
    
    parser.add_argument(
        '--api-url',
        default='http://localhost:5000/api',
        help='Backend API URL (default: http://localhost:5000/api)'
    )
    
    parser.add_argument(
        '--api-key',
        help='API key for authentication (optional)'
    )
    
    parser.add_argument(
        '--log-file',
        help='Path to log file to monitor'
    )
    
    parser.add_argument(
        '--process-existing',
        action='store_true',
        help='Process existing log file content before monitoring'
    )
    
    parser.add_argument(
        '--stdin',
        action='store_true',
        help='Read from stdin instead of file'
    )
    
    parser.add_argument(
        '--interval',
        type=float,
        default=1.0,
        help='Polling interval in seconds (default: 1.0)'
    )
    
    parser.add_argument(
        '--test',
        action='store_true',
        help='Test connection to backend API'
    )
    
    args = parser.parse_args()
    
    # Initialize tracker
    tracker = NuzlockeTracker(
        api_url=args.api_url,
        api_key=args.api_key
    )
    
    # Test mode
    if args.test:
        logging.info("Testing connection to backend...")
        if tracker.api.health_check():
            logging.info("✓ Backend is accessible")
        else:
            logging.error("✗ Cannot connect to backend")
        return
    
    # Monitor stdin
    if args.stdin:
        tracker.monitor_stdin()
        return
    
    # Monitor log file
    if args.log_file:
        # Process existing content if requested
        if args.process_existing:
            tracker.process_log_file(args.log_file)
        
        # Start monitoring
        try:
            tracker.monitor_log_file(args.log_file, args.interval)
        except KeyboardInterrupt:
            logging.info("\n✓ Monitoring stopped")
    else:
        logging.error("Error: Must specify --log-file or --stdin")
        parser.print_help()


if __name__ == '__main__':
    main()
