Cloudflare Dynamic DNS tools (Only IPv6)

## Requirements

* curl
* jq
* Cloudflare's Zone ID and API Token (DNS:Edit permission)

## PreInstall

Edit ./systemd/cf-ddns@.service file, change `EnvironmentFile` and `ExecStart`
actual path to file path, if you clone this repo to `~/projects/cf-ddns`, it is
not need to change.

Copy `./systemd/cf-ddns@.{service,timer}` to `$XDG_CONFIG_HOME/systemd/user/`

```sh
cp ./systemd/cf-ddns@.{service,timer} $XDG_CONFIG_HOME/systemd/user/
```

## Install

```sh
systemctl --user enable cf-ddns@<DOMAIN_HERE>.timer
```
**Note: Please change `<DOMAIN_HERE` to your actual domain.**
