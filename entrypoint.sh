#!/bin/sh
set -e

WORKSPACE=/home/user/workspace
PUID=${PUID:-$(id -u user)}
PGID=${PGID:-$(id -g user)}

# Remap user/group IDs by editing the account files directly: `usermod -u`
# would recursively chown the bind-mounted workspace.
if [ "$PGID" != "$(id -g user)" ]; then
    groupmod -o -g "$PGID" user
    sed -i "s/^\(user:[^:]*:[0-9]*:\)[0-9]*:/\1$PGID:/" /etc/passwd
fi
if [ "$PUID" != "$(id -u user)" ]; then
    sed -i "s/^\(user:[^:]*:\)[0-9]*:/\1$PUID:/" /etc/passwd
fi

# Home dotfiles (same filesystem only, so the mounted workspace is skipped)
find /home/user -xdev -not -path "$WORKSPACE" -exec chown -h "$PUID:$PGID" {} +

# Recursive only when the folder's owner differs (first start or UID change);
# tolerate filesystems that refuse chown
if [ "$(stat -c %u:%g "$WORKSPACE")" != "$PUID:$PGID" ]; then
    chown -R "$PUID:$PGID" "$WORKSPACE" || echo "warning: cannot chown $WORKSPACE" >&2
fi

if [ -n "$USER_PASSWORD" ]; then
    echo "user:$USER_PASSWORD" | chpasswd
fi

exec /usr/sbin/sshd -D
