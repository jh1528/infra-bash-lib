# infra-bash-lib
A modular Bash toolkit for infrastructure automation. Includes reusable functions for logging, system validation, package management, service control, and health checks across Linux environments.


## Overview

`infra-bash-lib` is a modular collection of Bash functions designed to simplify:

- System bootstrap and preflight checks
- Logging and colorized output
- Health checks (CPU, memory, disk)
- Package management helpers (APT/YUM)
- Network validation
- Service management

This library is intended to be reused across multiple projects such as:
- Graylog deployments
- Monitoring stacks (Zabbix, Prometheus)
- Kubernetes node setup
- General Linux server automation

## Structure
