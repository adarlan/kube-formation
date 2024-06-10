#!/bin/bash
set -e

# Shutdown the instances every 5 hours in case you forget the cluster running
sudo echo "0 */5 * * * root /sbin/shutdown -h now" >> /etc/crontab
