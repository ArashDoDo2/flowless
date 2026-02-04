# Troubleshooting Guide

## General Diagnostics

### Check Service Status

```bash
# Paqet
sudo systemctl status flowless-paqet

# GFW-Knocker
sudo systemctl status flowless-gfk
```

Look for:
- `Active: active (running)` = Service is running
- `Active: failed` = Service crashed or failed to start
- `Active: inactive (dead)` = Service is stopped

### View Logs

```bash
# View recent logs
sudo journalctl -u flowless-paqet -n 100

# Follow logs in real-time
sudo journalctl -u flowless-gfk -f

# View logs since specific time
sudo journalctl -u flowless-paqet --since "1 hour ago"
```

### Test Connectivity

```bash
# Test if proxy is listening
netstat -tlnp | grep -E "(1080|14000)"

# Test SOCKS5 connection
curl --socks5 127.0.0.1:1080 https://example.com -v
curl --socks5 127.0.0.1:14000 https://example.com -v
```

## Common Issues

### Issue: Service Won't Start

**Symptom:**
```
● flowless-paqet.service - Flowless Paqet Stateless Relay
   Loaded: loaded
   Active: failed (Result: exit-code)
```

**Possible Causes:**

1. **Binary not found**
   ```bash
   # Check if binary exists
   ls -la /usr/local/bin/paqet
   ls -la /usr/local/bin/gfw-knocker
   ```
   
   **Solution:** Install the binary manually or re-run installer

2. **Configuration file missing**
   ```bash
   # Check config exists
   ls -la /etc/flowless/paqet.conf
   ls -la /etc/flowless/gfk.conf
   ```
   
   **Solution:** Create config from template in `/config/` directory

3. **Permission issues**
   ```bash
   # Check binary is executable
   sudo chmod +x /usr/local/bin/paqet
   sudo chmod +x /usr/local/bin/gfw-knocker
   ```

4. **Configuration syntax error**
   ```bash
   # Check logs for parse errors
   sudo journalctl -u flowless-paqet -n 50
   ```
   
   **Solution:** Review config file, check for typos

### Issue: Service Starts But Can't Connect

**Symptom:**
```bash
$ curl --socks5 127.0.0.1:1080 https://example.com
curl: (7) Failed to connect to 127.0.0.1 port 1080: Connection refused
```

**Possible Causes:**

1. **Service not actually running**
   ```bash
   sudo systemctl status flowless-paqet
   ```
   
   **Solution:** Start the service: `sudo systemctl start flowless-paqet`

2. **Wrong port specified**
   - Paqet uses port 1080
   - GFW-Knocker uses port 14000
   
   **Solution:** Verify port in `/etc/flowless/*.conf` matches your command

3. **Service listening on different address**
   ```bash
   # Check what's listening
   sudo netstat -tlnp | grep paqet
   ```
   
   **Solution:** Ensure `local_addr=127.0.0.1` in config

### Issue: Connection Timeouts

**Symptom:**
```bash
$ curl --socks5 127.0.0.1:1080 https://example.com
curl: (7) Failed to receive SOCKS5 connect request ack.
```

**Possible Causes:**

1. **Server not reachable**
   ```bash
   # Test direct connectivity to server
   ping YOUR_SERVER_IP
   telnet YOUR_SERVER_IP 4000
   ```
   
   **Solution:** Verify server is running and accessible

2. **Firewall blocking connection**
   ```bash
   # Check if firewall rules block outbound
   sudo iptables -L OUTPUT -v
   ```
   
   **Solution:** Allow outbound connections to server

3. **Wrong server address in config**
   ```bash
   # Verify config
   grep server_addr /etc/flowless/paqet.conf
   ```
   
   **Solution:** Update `server_addr` and restart service

4. **Server port blocked**
   ```bash
   # Test with different ports
   # Try 443, 80, 8080 on server side
   ```

### Issue: Poor Performance

**Symptom:** Slow speeds, high latency, frequent disconnections

**Paqet-Specific Solutions:**

1. **Adjust KCP mode**
   ```conf
   # Try different modes
   kcp_mode=fast     # More reliable
   kcp_mode=fast3    # Faster but less reliable
   ```

2. **Tune MTU**
   ```conf
   # If packet loss, reduce MTU
   kcp_mtu=1200
   
   # If network is clean, try increasing
   kcp_mtu=1450
   ```

3. **Adjust window sizes**
   ```conf
   # For high bandwidth networks
   kcp_sndwnd=1024
   kcp_rcvwnd=1024
   ```

4. **Tune FEC for network conditions**
   ```conf
   # High packet loss? Increase parity
   kcp_datashard=10
   kcp_parityshard=5
   
   # Clean network? Reduce overhead
   kcp_datashard=10
   kcp_parityshard=2
   ```

**GFW-Knocker-Specific Solutions:**

1. **Try different TCP manipulation mode**
   ```conf
   # If current mode isn't working well
   tcp_malform_mode=fragmentation
   # OR
   tcp_malform_mode=checksum_invalid
   ```

2. **Adjust buffer sizes**
   ```conf
   # Increase for better throughput
   buffer_size=8192
   ```

3. **Check backend connectivity**
   ```bash
   # Verify backend Xray is responding
   ping BACKEND_IP
   ```

### Issue: Service Keeps Restarting

**Symptom:**
```bash
$ sudo systemctl status flowless-paqet
Active: activating (auto-restart)
```

**Possible Causes:**

1. **Continuous crash due to config error**
   ```bash
   # Check for crash logs
   sudo journalctl -u flowless-paqet -n 200 | grep -i error
   ```
   
   **Solution:** Fix configuration errors

2. **Binary corrupted or wrong architecture**
   ```bash
   # Check binary
   file /usr/local/bin/paqet
   ```
   
   **Solution:** Re-download correct binary for your system

3. **Resource exhaustion**
   ```bash
   # Check system resources
   free -h
   df -h
   ```
   
   **Solution:** Free up memory/disk space

### Issue: GFW-Knocker Permission Errors

**Symptom:**
```
Permission denied: CAP_NET_RAW capability required
```

**Cause:** GFW-Knocker needs raw socket capability for packet manipulation

**Solution:**

1. **Verify service file has capabilities**
   ```bash
   grep Capability /etc/systemd/system/flowless-gfk.service
   ```
   
   Should include:
   ```
   CapabilityBoundingSet=CAP_NET_RAW CAP_NET_ADMIN
   AmbientCapabilities=CAP_NET_RAW CAP_NET_ADMIN
   ```

2. **Reload systemd and restart**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart flowless-gfk
   ```

3. **Alternative: Set capability on binary**
   ```bash
   sudo setcap cap_net_raw,cap_net_admin=eip /usr/local/bin/gfw-knocker
   ```

## Advanced Debugging

### Enable Debug Logging

Edit config file to enable verbose output:

**Paqet:**
```conf
debug=true
log_file=/var/log/flowless/paqet-debug.log
```

**GFW-Knocker:**
```conf
debug=true
log_file=/var/log/flowless/gfk-debug.log
```

Restart service and check debug log:
```bash
sudo systemctl restart flowless-paqet
sudo tail -f /var/log/flowless/paqet-debug.log
```

### Network Packet Capture

Capture traffic to diagnose network issues:

```bash
# Capture Paqet traffic (KCP is UDP-based)
sudo tcpdump -i any udp port 4000 -w paqet-capture.pcap

# Capture GFW-Knocker traffic (TCP-based)
sudo tcpdump -i any tcp port 443 -w gfk-capture.pcap
```

Analyze with Wireshark or tcpdump:
```bash
tcpdump -r paqet-capture.pcap -n | less
```

### Check System Resources

```bash
# CPU usage by service
ps aux | grep -E "(paqet|gfw-knocker)"

# Memory usage
sudo systemctl status flowless-paqet | grep Memory

# File descriptors
sudo ls -l /proc/$(pgrep paqet)/fd | wc -l
```

## Getting Help

If you're still experiencing issues:

1. Collect diagnostic information:
   ```bash
   sudo journalctl -u flowless-paqet --no-pager > paqet-logs.txt
   sudo systemctl status flowless-paqet > paqet-status.txt
   cat /etc/flowless/paqet.conf > paqet-config.txt  # Remove sensitive info!
   ```

2. Document your setup:
   - OS version: `lsb_release -a`
   - Kernel version: `uname -r`
   - Binary version: `/usr/local/bin/paqet --version`
   - Network environment description

3. Open an issue on GitHub with:
   - Clear description of the problem
   - Steps to reproduce
   - Diagnostic information
   - What you've already tried

## Prevention Best Practices

1. **Always test configuration before production**
   ```bash
   # Test config syntax (if binary supports it)
   /usr/local/bin/paqet -c /etc/flowless/paqet.conf --test
   ```

2. **Keep backups of working configurations**
   ```bash
   sudo cp /etc/flowless/paqet.conf /etc/flowless/paqet.conf.working
   ```

3. **Monitor service health**
   ```bash
   # Setup monitoring (example with simple cron)
   */5 * * * * systemctl is-active flowless-paqet || systemctl restart flowless-paqet
   ```

4. **Keep logs rotated**
   ```bash
   # Configure logrotate for flowless logs
   sudo nano /etc/logrotate.d/flowless
   ```

5. **Document your custom configurations**
   - Keep notes on why you changed specific parameters
   - Track which settings work best for your network
