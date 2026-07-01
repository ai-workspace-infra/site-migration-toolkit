#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
from pathlib import Path

def get_inventory_path(toolkit_root: Path) -> Path:
    """Resolve the location of the Ansible inventory."""
    # 1. Inside toolkit root (e.g. CI/CD environment or manual copy)
    if (toolkit_root / "cmdb" / "inventory").is_file():
        return toolkit_root / "cmdb" / "inventory"
    if (toolkit_root / "cmdb" / "inventory.ini").is_file():
        return toolkit_root / "cmdb" / "inventory.ini"
        
    # 2. Adjacent cmdb directory (local execution structure)
    adjacent_cmdb = toolkit_root.parent / "cmdb"
    if (adjacent_cmdb / "inventory").is_file():
        return adjacent_cmdb / "inventory"
    if (adjacent_cmdb / "inventory.ini").is_file():
        return adjacent_cmdb / "inventory.ini"

    return None

def main():
    parser = argparse.ArgumentParser(description="AI Workspace Site Migration & Backup Toolkit Wrapper")
    parser.add_argument("action", choices=["migrate", "backup", "restore"], help="Toolkit action to execute")
    
    # Capture all remaining arguments (e.g., -e "var=value") to pass seamlessly to ansible-playbook
    args, unknown_args = parser.parse_known_args()

    # Resolve paths dynamically
    script_dir = Path(__file__).resolve().parent
    toolkit_root = script_dir.parent
    playbooks_dir = toolkit_root.parent / "playbooks"

    if not playbooks_dir.is_dir():
        print(f"[ERROR] Cannot find playbooks directory at {playbooks_dir}")
        print("Ensure 'playbooks' repository is checked out adjacently.")
        sys.exit(1)

    playbook_file = f"{args.action}_site.yml"
    if not (playbooks_dir / playbook_file).is_file():
        print(f"[ERROR] Playbook '{playbook_file}' not found in {playbooks_dir}")
        sys.exit(1)

    inventory_path = get_inventory_path(toolkit_root)
    
    print("=" * 60)
    print(f"[INFO] Action:   {args.action.upper()}")
    print(f"[INFO] Playbook: {playbook_file}")
    if inventory_path:
        print(f"[INFO] Inventory: {inventory_path}")
    print("=" * 60)
    
    cmd = ["ansible-playbook"]
    if inventory_path:
        cmd.extend(["-i", str(inventory_path)])
    else:
        print("[WARNING] No valid cmdb/inventory file found. Proceeding without explicit -i flag.")
        
    cmd.append(playbook_file)
    if unknown_args:
        cmd.extend(unknown_args)

    print(f"[EXEC] {' '.join(cmd)}\n")
    
    try:
        # Execute Ansible directly from the playbooks directory
        subprocess.run(cmd, cwd=playbooks_dir, check=True)
        print(f"\n[SUCCESS] Toolkit action '{args.action}' completed.")
    except subprocess.CalledProcessError as e:
        print(f"\n[FATAL] Toolkit action '{args.action}' failed (Exit Code: {e.returncode}).")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print(f"\n[WARN] Toolkit action '{args.action}' interrupted by user.")
        sys.exit(130)

if __name__ == "__main__":
    main()
