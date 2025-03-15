# VMRegistration PowerShell Module

## Overview

The `vmx_recovery.ps1` PowerShell module automates the process of registering virtual machines (VMs) on an ESXi host by locating VMX files within a specified datastore. Originally a standalone script, it has been refactored into a reusable PowerShell module with a single exported cmdlet, `Register-VMsFromDatastore`, designed for direct ESXi host connections (not via vCenter). This tool is ideal for administrators managing ESXi hosts where VMs need to be registered from existing VMX files, such as after a migration or recovery scenario.

## Features

- Connects to an ESXi host using provided credentials.
- Searches a specified datastore recursively for `.vmx` files.
- Corrects VMX file paths to the format required by PowerCLI’s `New-VM` cmdlet.
- Registers VMs on the specified host with error handling.
- Supports ignoring certificate errors for hosts with self-signed certificates.

## Requirements

- **VMware PowerCLI**: This module relies on VMware PowerCLI for ESXi interactions. Install it via PowerShell Gallery:
  ```powershell
  Install-Module -Name VMware.PowerCLI -Scope CurrentUser