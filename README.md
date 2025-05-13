# POP Cache Node Setup Script

This script automates the setup of a POP Cache Node for the Pipe Network Testnet on Linux. It prompts for configuration details at runtime.

## Usage
1. Make executable:
   ```bash
   chmod +x setup_popcache_node.sh
   ```
2. Run:
   ```bash
   sudo ./setup_popcache_node.sh```
3. Follow prompts to enter Invite Code, Solana Wallet Address, etc.

4. Verify the Setup:Check service status:
   ```bash
   sudo systemctl status popcache
   ```
Monitor logs:
```bash
tail -f /opt/popcache/logs/*.log
```
Check health endpoint:
```bash
curl http://localhost/health
```
Check metrics:
```curl http://localhost/metrics
```
Troubleshooting (if needed):
Check logs for errors:
```bash
sudo journalctl -u popcache -n 100
```
Verify permissions:
```bash
sudo chmod 755 /opt/popcache/pop
sudo chown -R popcache:popcache/opt/popcache
```
Check for port conflicts:
```bash
sudo netstat -tuln | grep -E ':(80|443)'
```

## Requirements
- Ubuntu Linux
- Root access
- Invite code from Pipe Network
- Solana wallet address
- 
