[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

# Raspberry Pi Provisioning Setup


## References
https://docs.ansible.com/ansible/latest/user_guide/playbooks_intro.html


## Setup
The installation needs a folder *secret* (not tracked) containing the credential files. *secret* is not checked in, and needs to be provided manually as shown below.  

For my embedded automation controller the following shows a final setup:  

- **dhcp client** on wlan0 (with configured `wpa_supplicant` from *secret*), as uplink
- **dhcp server** (dnsmasq) running on eth0 to manage the DUTs
- rootfs expanded to the entire SD card
- Serial console login enabled
- Early output on serial enabled
- Bluetooth disabled to make console print readable (RPI issue)
- SSH daemon enabled
- Locale `US_en.UTF-8`
- screen using CTRL-b (emacs user)
- vimrc, emacsrc, mc, bashrc, etc. environment settings
- ~/.local is a symlink to /usr/local i.e. actually a one-user-system
- (opt) Xilinx `hw_server` for JTAG over USB to a DUT
- (opt) Camera (legacy) enabled, setup for motion (useful to remote observe LEDs blinking)
- (opt) Pengutronix's labgrid-exporter exporting: console to DUT, ssh to CTRL, gpio26 for powercycle
- (opt) Pengugtronix's usbsdmux in virtualenv
- (opt) Pyrelayctl and script relctl.py for sainsmart 4-way-relay

Ideally an ansible "role" (i.e. a module) will drop its usage as README file in /home/pi.  

login: pi / xdr5XDR%  

### IP ranges
| IP             | hostname | setup         |
| +------------- | +------- | +------------ |
| 192.168.123.71 | unit01   | router        |
| 192.168.123.72 | unit02   | Linux, SPI    |
| 192.168.123.73 | unit03   | Linux, I2C    |
| 192.168.123.74 | unit04   | Linux, custom |
| 192.168.123.75 | unit05   | Zephyr        |
| 192.168.123.76 | unit06   | Zephyr        |
| 192.168.123.77 | unit07   | Zephyr        |
| 192.168.123.78 | unit08   | Zephyr        |

## Preparation (first usage)
On host PC  

```
$ python3 -m venv ansible-venv
$ . ./ansible-venv/bin/activate
(ansible-venv)$ pip install --upgrade pip setuptools wheel

(ansible-venv)$ pip install ansible
```

### 1. Download RPI/OS image (64 bit)
Download a recent Raspi OS image for Raspi 4 or 3b [64 bit], plug SD card in reader  
```
$ mkdir ./downloads
$ cd ./downloads
$ wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2026-10-06/2026-10-06-raspios-trixie-arm64-lite.img.xz
$ unxz 2026-10-06-raspios-trixie-arm64-lite.img.xz
```

### 2. SD card: Prepare Secrets
Add secret information (e.g. wifi access) to this folder, not to be committed.
```
$ tree -L 2 ./common/
./common/
├── boot
│   ├── cmdline.txt
│   ├── config.txt
│   ├── ssh.txt
│   └── userconf.txt
└── rootfs
    ├── boot
    ├── etc
    ├── home
    └── usr
```
Individual files for the place exporters go here:
```
$ tree -L 2 ./overlay/
./overlay/
├── unit01
│   └── etc
├── unit02
│   └── etc
├── unit03
│   └── etc
├── unit04
│   └── etc
├── unit05
│   └── etc
├── unit06
│   └── etc
├── unit07
│   └── etc
└── unit08
    └── etc
```
Make sure that SD card OS will work out for ansible, so typically check:
- hostname
- ip address
- wifi access
- ssh `authorized_keys`

### 3. SD card: Flash the minimal Setup
Plug card into the card reader. In case configure ./setup.sh to use the 64-bit or the 32-bit Pi OS image.   
```
$ lsblk
   -> /dev/sdi

$ cd ./sd
$ ./setup.sh /dev/sdi unit01
    ...
    READY.
```
NB: If there is no `READY.` the SD card setup failed, check the error.  

### 4. Ansible: Prepare the setup
check configuration
```
$ cd ./ansible
$ ansible-inventory --graph
```

Now Plug the card into the RPI. Connect ethernet to the RPI. Power the RPI. Test network.  
```
$ ansible unit07 -m ping
unit07 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

### 5. Raspberry: Automized Setup
Dry-run (enter the target password once, when asked)
```
$ ansible-playbook site.yml --limit unit07 --check --diff -K
```

Execute ansible provisioning
```
$ ansible-playbook site.yml --limit unit07 -K
    BECOME password:
```
- Enter user password
- Wait ~60 min

In case restart, if the provisioning runs into load issues..  

#### 5.1 Quickfix: update ssh ``known_hosts`` (optionally)
```
$ ssh-keygen -f ~/.ssh/known_hosts -R "192.168.123.71"
$ ssh-keyscan 192.168.123.71 >> ~/.ssh/known_hosts
    # 192.168.123.71:22 SSH-2.0-OpenSSH_8.4p1 Debian-5+deb11u1
    # 192.168.123.71:22 SSH-2.0-OpenSSH_8.4p1 Debian-5+deb11u1
    # 192.168.123.71:22 SSH-2.0-OpenSSH_8.4p1 Debian-5+deb11u1
    # 192.168.123.71:22 SSH-2.0-OpenSSH_8.4p1 Debian-5+deb11u1
    # 192.168.123.71:22 SSH-2.0-OpenSSH_8.4p1 Debian-5+deb11u1
```

Verify the board is up and connection works out.  
```
$ cd ./ansible
$ ansible all -m ping
    192.168.123.71 | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/python"
        },
        "changed": false,
        "ping": "pong"
    }
```

## Usage
```
$ ssh pi@192.168.123.71
    login: pi
    password: xdr5XDR%
    (but should use certificate!)
```

#### When working with screen
```
$ screen

<open up some sessions>
```

#### When working with Pengutronix labgrid
```
$ sudo systemctl status labgrid-exporter
```

Modify `/etc/labgrid/exporter.yaml` and `/etc/systemd/system/labgrid-exporter.service`, then
```
$ sudo systemctl start labgrid-exporter
```


#### When working with Pengutronix usbsdmux / labgrid
For the specific setting use `labgrid-suggest`...
```
$ source /opt/labgrid-venv/bin/activate
(labview-venv)$ ls /dev/usb-sd-mux/
    id-000000001444

(labview-venv)$ usbsdmux /dev/usb-sd-mux/id-000000001444 get
    dut

(labgrid-venv)$ usbsdmux /dev/usb-sd-mux/id-000000001444 host
(labgrid-venv)$ lsblk
     NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
     sda           8:0    1 29.8G  0 disk
     ├─sda1        8:1    1  256M  0 part
     └─sda2        8:2    1 29.6G  0 part

(labgrid-venv)$ sudo udisksctl mount -b /dev/sda1

<copy over what is needed>

(labgrid-venv)$ sync
(labgrid-venv)$ sudo udisksctl unmount -b /dev/sda1
```

switchover  
```
(labgrid-venv)$ usbsdmux /dev/usb-sd-mux/id-000000001444 dut
```

#### When working with pyrelayctl
power the device  
```
(labgrid-venv)$ relctl.py -d0 -t1
```

#### When using GPIO26 and any relay
power the device
```
$ sudo systemctl start gpio26
```

unpower the device
```
$ sudo systemctl stop gpio26
```

In case of labgrid this is to be forwarded, then `lc power on` (if `labgrid-client` aliased to `lc`) powers the device.


#### When working with serial connection
in another screen session e.g. open a terminal  
```
$ tio /dev/ttyUSB1
```

In case of labgrid this is to be forwareded, then `lc con` should provide the shell to the DUT.


#### When working with xvcpi server
in another screen session e.g. run xvcpi server  
```
$ cd ./github__xvcpi
$ sudo xvcpi -v &
```

#### When working with Xilinx `hw_server` (JTAG server)
```
$ sudo systemctl start hw_server
```

NB: the server is highly (more or less) dependent on the installed version of Xilinx Lab Edition, here the setup is provided for 2022.1, 2023.1 and 2024.1. In this case the specific
`Xilinx Vivado Lab Edition` for Linux has to be downloaded and placed into the `downloads` folder. Then `./ansible/mod-xilinxsrv/tasks/*` needs to be adjusted accordingly before
ansible installation.


## Development
sd card mux  
ref: https://www.linux-automation.com/usbsdmux-M01/  

first usage, setup udevrule for usbsdcard mux  
```
$ git clone https://github.com/pengutronix/usbsdmux.git
$ sudo cp contrib/udev/99-usbsdmux.rules /etc/udev/rules.d/
$ sudo udevadm control --reload-rules
$ reboot
```
now, connect the usbsdmux device  

first usage, build xvcpi software on the RPI (arm toolchain)  
```
$ cd ./github__xvcpi
$ make
```


## TODO
- quickfix: dnsmasq keeps IP as listen ip, when adjusting IP needs to be mentioned how & where to change, too
- quickfix: describe how and where to set hostname
- Fix xvcpi JTAG forwareder not working
- Provide README_<ansible mod>.md for each optionally selected ansible module to be placed into /home/pi


## Issues
*issue*: how to change hostname in sd setup  

fix: edit ``sd/rootfs/etc/hosts`` and ``sd/rootfs/etc/hostname``  

*issue*: ssh certificate falls back to password login  

fix: check ``/home/pi`` and ``/home/pi/.ssh`` folders need permissions *0700* (check systemctl log on the device why authentication failed)  

*issue*: prefer pip installed ansible?  

```
$ pip3 install --upgrade --user ansible
$ pip3 show ansible
```

*issue*: ping fails  
```
$ ansible raspi -m ping
10.1.10.200 | UNREACHABLE! => {
    "changed": false,
	    "msg": "Failed to connect to the host via ssh: @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\r\n@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @\r\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\r\nIT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!\r\nSomeone could be eavesdropping on you right now (man-in-the-middle attack)!\r\nIt is also possible that a host key has just been changed.\r\nThe fingerprint for the ED25519 key sent by the remote host is\nSHA256:vH4JKH+RXxG85SiYz26U7xX7aCgZ1a/YqF5Ip643vVQ.\r\nPlease contact your system administrator.\r\nAdd correct host key in /home/user/.ssh/known_hosts to get rid of this message.\r\nOffending ECDSA key in /home/user/.ssh/known_hosts:78\r\n  remove with:\r\n  ssh-keygen -f \"/home/user/.ssh/known_hosts\" -R \"10.1.10.200\"\r\nHost key for 192.168.123.71 has changed and you have requested strict checking.\r\nHost key verification failed.",
		    "unreachable": true
			}
```
*fix*: adjust .ssh/known_hosts  
```
ssh-keygen -f "/home/user/.ssh/known_hosts" -R "192.168.123.71"
```


*issue*: login failed, no login possible  

*fix*: provide a /boot/userconf.txt file, e.g. when SD card is mounted  
```
$ echo -n "pi:" > ./boot/userconf.txt
$ echo 'mypassword' | openssl passwd -6 -stdin >> /boot/userconf.txt
```

*issue*: when installing linux-image.deb error on the RPI `uses unknown compression for member 'control.tar.zst', giving up`  

*fix*: repack .zst to .xz, example linux-image (analogue for linux-libc and linux-headers)  
```
$ mkdir deb-temp
$ cd deb-temp
$ ar x ../linux-image-6.3.0-rc6-v8+_6.3.0-rc6-gbc5ee0e040c4-2_arm64.deb
$ zstd -d *.zst
$ rm *.zst
$ xz *.tar
$ mkdir ../repacked
$ ar r ../repacked/linux-image-6.3.0-rc6-v8+_6.3.0-rc6-gbc5ee0e040c4-2_arm64.deb  debian-binary control.tar.xz data.tar.xz
$ cd ..
```


*issue*: userspace application is (cross)compiled against wrong GLIBC version  
executing on the target shows the following error  
```
$ ./userland.elf 
    ./userland.elf: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by ./userland.elf)
$ /lib/aarch64-linux-gnu/libc.so.6 
    GNU C Library (Debian GLIBC 2.31-13+rpt2+rpi1+deb11u5) stable release version 2.31.
    Copyright (C) 2020 Free Software Foundation, Inc.
    This is free software; see the source for copying conditions.
    There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
    PARTICULAR PURPOSE.
    Compiled by GNU CC version 10.2.1 20210110.
    libc ABIs: UNIQUE ABSOLUTE
    For bug reporting instructions, please see:
    <http://www.debian.org/Bugs/>.
```

fix: probably use build docker for ubuntu 20.04 instead of 22.04  


*issue*: while performing ansible provisioning, provisioning stops, with a huge red output ending with ``Temporary failure resolving 'deb.debian.org'"``  

fix: wait some seconds, restart ansible commissioning (...)   
