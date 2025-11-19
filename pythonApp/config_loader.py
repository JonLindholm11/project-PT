#!/usr/bin/env python3
"""
Configuration loader for Nuzlocke Tracker
Supports loading settings from config.json file
"""

import json
from pathlib import Path
from typing import Dict, Optional


class Config:
    """Configuration manager for Nuzlocke Tracker"""
    
    DEFAULT_CONFIG = {
        "api": {
            "base_url": "http://localhost:5000/api",
            "api_key": None,
            "timeout": 10,
            "retry_attempts": 3
        },
        "monitoring": {
            "log_file": None,
            "poll_interval": 1.0,
            "process_existing_on_start": False,
            "use_stdin": False
        },
        "logging": {
            "level": "INFO",
            "file": None,
            "format": "%(asctime)s [%(levelname)s] %(message)s"
        }
    }
    
    def __init__(self, config_file: Optional[str] = None):
        self.config = self.DEFAULT_CONFIG.copy()
        
        if config_file:
            self.load_from_file(config_file)
    
    def load_from_file(self, config_file: str):
        """Load configuration from JSON file"""
        config_path = Path(config_file)
        
        if not config_path.exists():
            raise FileNotFoundError(f"Config file not found: {config_file}")
        
        with open(config_path, 'r') as f:
            user_config = json.load(f)
        
        # Merge with defaults
        self._deep_merge(self.config, user_config)
    
    def _deep_merge(self, base: Dict, update: Dict):
        """Recursively merge update dict into base dict"""
        for key, value in update.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._deep_merge(base[key], value)
            else:
                base[key] = value
    
    def get(self, *keys):
        """Get configuration value by nested keys"""
        value = self.config
        for key in keys:
            if isinstance(value, dict):
                value = value.get(key)
            else:
                return None
        return value
    
    def set(self, value, *keys):
        """Set configuration value by nested keys"""
        config = self.config
        for key in keys[:-1]:
            config = config.setdefault(key, {})
        config[keys[-1]] = value
    
    @property
    def api_url(self) -> str:
        return self.get('api', 'base_url')
    
    @property
    def api_key(self) -> Optional[str]:
        return self.get('api', 'api_key')
    
    @property
    def log_file(self) -> Optional[str]:
        return self.get('monitoring', 'log_file')
    
    @property
    def poll_interval(self) -> float:
        return self.get('monitoring', 'poll_interval')
    
    @property
    def process_existing(self) -> bool:
        return self.get('monitoring', 'process_existing_on_start')
    
    @property
    def use_stdin(self) -> bool:
        return self.get('monitoring', 'use_stdin')
    
    def to_dict(self) -> Dict:
        """Return configuration as dictionary"""
        return self.config.copy()
    
    def save(self, filename: str):
        """Save current configuration to file"""
        with open(filename, 'w') as f:
            json.dump(self.config, f, indent=2)


# Example usage in main script
if __name__ == '__main__':
    # Example 1: Load from file
    try:
        config = Config('config.json')
        print("Loaded config:")
        print(f"  API URL: {config.api_url}")
        print(f"  Log file: {config.log_file}")
        print(f"  Poll interval: {config.poll_interval}")
    except FileNotFoundError:
        print("Config file not found, using defaults")
    
    # Example 2: Create config programmatically
    config = Config()
    config.set('http://myserver.com/api', 'api', 'base_url')
    config.set('/var/log/emulator.log', 'monitoring', 'log_file')
    
    # Save to file
    config.save('my_config.json')
    print("\nConfig saved to my_config.json")
