# Amazon EBS Volume Lab

Create a volume, put a filesystem on it, write data to it, then move that data to a
**different Availability Zone** using a snapshot.

> **The one thing this lab proves:** an EBS volume can never leave the Availability
> Zone it was created in. A snapshot is regional, so it can. That is how data crosses
> an AZ boundary in AWS.

**Region used throughout:** `us-east-1`
**AMI:** Amazon Linux 2023
**Instance type:** `t3.micro`

---

## 1. Launch two instances in two AZs

| | Instance A | Instance B |
|---|---|---|
| Name tag | `ebs-a` | `ebs-b` |
| AMI | Amazon Linux 2023 | Amazon Linux 2023 |
| Type | `t3.micro` | `t3.micro` |
| Subnet | public subnet in **us-east-1a** | public subnet in **us-east-1b** |
| Auto-assign public IP | Enable | Enable |
| Security group | SSH (22) from **My IP** | same |
| Key pair | your existing key pair | same |

Everything else is identical. Choosing the subnet is how you choose the AZ.

---

## 2. Create and attach a volume

**Create the volume** — EC2 → **Volumes** → **Create volume**

| Setting | Value |
|---|---|
| Volume type | `gp3` |
| Size | `1` GiB |
| **Availability Zone** | **`us-east-1a`** |
| Name tag | `data-volume` |

> The Availability Zone field is permanent. It cannot be changed after creation.

**Check what the instance can see, before attaching.** SSH into instance A:

```bash
sudo lsblk -e7
```

```
NAME          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nvme0n1       259:0    0    8G  0 disk
├─nvme0n1p1   259:1    0    8G  0 part /
├─nvme0n1p127 259:2    0    1M  0 part
└─nvme0n1p128 259:3    0   10M  0 part /boot/efi
```

One disk — the root volume. `-e7` hides loop devices so the output stays readable.

**Attach it** — Volumes → `data-volume` → **Actions** → **Attach volume**

- Instance: `ebs-a`
- Device name: accept the suggested `/dev/sdf`

> Only instances in `us-east-1a` appear in the dropdown. Instance B is running and
> healthy, and AWS will not offer it. That is the AZ rule being enforced.

**Run the same command again:**

```bash
sudo lsblk -e7
```

```
NAME          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nvme0n1       259:0    0    8G  0 disk
├─nvme0n1p1   259:1    0    8G  0 part /
├─nvme0n1p127 259:2    0    1M  0 part
└─nvme0n1p128 259:3    0   10M  0 part /boot/efi
nvme1n1       259:4    0    1G  0 disk
```

> ### ⚠️ The device name is a request, not a promise
> You asked for `/dev/sdf`. Linux is showing `/dev/nvme1n1`.
>
> Every current instance type runs on the Nitro platform, where EBS volumes arrive as
> NVMe devices and are numbered in attach order. **Always use the name `lsblk` reports.**
> The next command destroys everything on the device you point it at — naming the wrong
> one wipes your root volume.

Confirm it is empty:

```bash
sudo file -s /dev/nvme1n1
```

```
/dev/nvme1n1: data
```

`data` means no filesystem. A completely blank disk.

---

## 3. Create a filesystem and mount it

```bash
# 1 — put a filesystem on it (once, ever, for the life of this volume)
sudo mkfs -t xfs /dev/nvme1n1

# 2 — create a mount point
sudo mkdir /data

# 3 — mount it
sudo mount /dev/nvme1n1 /data

# confirm
df -h /data
lsblk -f
```

```
NAME        FSTYPE FSVER LABEL UUID                                 MOUNTPOINTS
nvme1n1     xfs                a1b2c3d4-5678-90ab-cdef-1234567890ab /data
```

Note the **UUID** — the snapshot carries it across, and you need it in the next step.

### Bonus — make the mount survive a reboot

> Not shown in the video, which only flags it as something you'd do on anything real.
> Skip this section if you're just following along; do it if you're building something
> you'll reboot.

Get the UUID:

```bash
sudo blkid /dev/nvme1n1
```

Edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Add this line, substituting your own UUID:

```
UUID=a1b2c3d4-5678-90ab-cdef-1234567890ab  /data  xfs  defaults,nofail  0  2
```

> **Use the UUID, not `/dev/nvme1n1`.** NVMe device numbers are assigned in attach
> order and can change between boots. A device-name entry in `/etc/fstab` can point at
> the wrong disk — or at nothing — after a restart.
>
> `nofail` means the instance still boots if the volume is missing. Without it, an
> unmountable entry in `/etc/fstab` can leave an instance stuck at boot with no SSH.

Test the entry **before** you ever reboot:

```bash
sudo umount /data
sudo mount -a
df -h /data
```

If `/data` is mounted again, the entry is correct.

---

## 4. Write some data

```bash
echo "Written on instance A, in us-east-1a." | sudo tee /data/proof.txt
sudo mkdir /data/ebs-lab
sudo sh -c 'date > /data/ebs-lab/when.txt'

ls -R /data
cat /data/proof.txt
```

This is the evidence. If it reads back on the other instance, the lab worked.

---

## 5. Snapshot the volume

**Unmount first**, so the filesystem flushes everything to disk:

```bash
sudo umount /data
```

Then: Volumes → `data-volume` → **Actions** → **Create snapshot**

- Description: `ebs lab`
- Name tag: `data-volume-snap`

Go to **Snapshots** and wait for the state to reach **Completed**.

---

## 6. Create a volume in us-east-1b from the snapshot

Snapshots → `data-volume-snap` → **Actions** → **Create volume from snapshot**

| Setting | Value |
|---|---|
| Volume type | `gp3` |
| Size | `1` GiB |
| **Availability Zone** | **`us-east-1b`** |
| Name tag | `data-volume-restored` |

> This is the point of the lab. The original volume is locked to `us-east-1a`. The
> snapshot belongs to the Region, so you choose the AZ when you restore it.

**Attach it** — Volumes → `data-volume-restored` → **Actions** → **Attach volume**

- Instance: `ebs-b`
- Device name: `/dev/sdf`

> The dropdown has flipped. `ebs-b` is offered; `ebs-a` is not.

---

## 7. Mount it on instance B and read the data back

SSH into instance B:

```bash
sudo lsblk -e7
sudo file -s /dev/nvme1n1
```

```
/dev/nvme1n1: SGI XFS filesystem data (blksz 4096, inosz 512, v2 dirs)
```

> ### ⚠️ Do NOT run `mkfs` here
> On instance A this said `data`. Here it reports an XFS filesystem, because the
> snapshot copied the filesystem **and the data**. Running `mkfs` now would succeed
> instantly, silently, and erase everything you came for.

Two commands only:

```bash
sudo mkdir /data
sudo mount /dev/nvme1n1 /data

ls -R /data
cat /data/proof.txt
```

```
Written on instance A, in us-east-1a.
```

Different instance, different Availability Zone, different volume ID — same file.

> **Note on UUIDs:** the restored volume has the *same* filesystem UUID as the original,
> because the snapshot copied it. That is fine across two instances. If you ever attach
> a restored volume to the **same** instance as its original, the mount fails on a
> duplicate UUID and you need `sudo mount -o nouuid /dev/nvme1n1 /data`.

---

## 8. Clean up

Skipping this leaves resources billing you monthly.

```bash
# on instance B
sudo umount /data

# on instance A, if you added the fstab entry, remove the line you added
sudo nano /etc/fstab
```

In the console, in this order:

1. **Volumes** → `data-volume-restored` → **Actions** → **Detach volume** → wait for `Available`
2. **Volumes** → `data-volume` → **Actions** → **Detach volume** → wait for `Available`
3. Select both → **Actions** → **Delete volume**
4. **Snapshots** → `data-volume-snap` → **Actions** → **Delete snapshot**
5. **Instances** → select `ebs-a` and `ebs-b` → **Instance state** → **Terminate instance**

> ### ⚠️ Terminating an instance does not delete the volumes you attached
> A root volume has `DeleteOnTermination` set to `true`, so it cleans itself up. A
> volume you attached yourself does **not**. Terminate both instances without deleting
> these two volumes and they keep sitting in your account, billed per GB-month.
>
> The snapshot lives on a **different page** from your volumes, which is exactly why
> it gets left behind. Check it.

---

## Command reference

**Instance A**

```bash
sudo lsblk -e7                                  # before attaching
sudo lsblk -e7                                  # after attaching
sudo file -s /dev/nvme1n1                       # "data" = empty
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir /data
sudo mount /dev/nvme1n1 /data
df -h /data
lsblk -f
sudo blkid /dev/nvme1n1                         # UUID for /etc/fstab
echo "Written on instance A, in us-east-1a." | sudo tee /data/proof.txt
sudo mkdir /data/ebs-lab
sudo sh -c 'date > /data/ebs-lab/when.txt'
ls -R /data
sudo umount /data                               # before the snapshot
```

**Instance B**

```bash
sudo lsblk -e7
sudo file -s /dev/nvme1n1                       # "XFS filesystem" = already formatted
sudo mkdir /data
sudo mount /dev/nvme1n1 /data                   # NO mkfs
ls -R /data
cat /data/proof.txt
sudo umount /data                               # before detaching
```

---

## Resources created

| Resource | Name | AZ |
|---|---|---|
| EC2 instance | `ebs-a` | us-east-1a |
| EC2 instance | `ebs-b` | us-east-1b |
| EBS volume, 1 GiB gp3 | `data-volume` | us-east-1a |
| Snapshot | `data-volume-snap` | *regional* |
| EBS volume from snapshot | `data-volume-restored` | us-east-1b |
