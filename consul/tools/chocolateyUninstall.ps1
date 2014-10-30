$ServiceName = "Consul"
# Stop the service
Stop-Service $ServiceName -ErrorAction SilentlyContinue
# Uninstall the service
nssm remove $ServiceName confirm -ErrorAction SilentlyContinue