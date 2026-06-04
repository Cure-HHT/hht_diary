#!/usr/bin/env python3
"""Delete clinical_diary's flutter_secure_storage entries from the
gnome-keyring (libsecret default collection).

flutter_secure_storage_linux v1.2.3's plugin registrar tags every item
it writes with attribute `account=<APPLICATION_ID>.secureStorage`
(see flutter_secure_storage_linux_plugin.cc:95-97 in pub-cache). This
script filters on that attribute so it cannot touch unrelated apps'
secrets. Pass the diary's APPLICATION_ID as argv[1].

Exits 0 on success (including "nothing to delete"), 1 on failures
where deletion was attempted but at least one item refused, 2 on
configuration errors (missing arg, no D-Bus, locked collection).
"""

import sys

try:
    import secretstorage
except ImportError:
    print(
        "clear-keyring: python3-secretstorage not installed; "
        "install with: sudo apt install -y python3-secretstorage",
        file=sys.stderr,
    )
    sys.exit(2)


def main(argv):
    if len(argv) != 2:
        print(f"usage: {argv[0]} <APPLICATION_ID>", file=sys.stderr)
        return 2
    application_id = argv[1]
    account_value = f"{application_id}.secureStorage"

    try:
        bus = secretstorage.dbus_init()
    except secretstorage.exceptions.SecretServiceNotAvailableException as exc:
        print(f"clear-keyring: D-Bus secret service unavailable: {exc}", file=sys.stderr)
        return 2

    collection = secretstorage.get_default_collection(bus)
    if collection.is_locked():
        try:
            collection.unlock()
        except Exception as exc:
            print(
                f"clear-keyring: default keyring is locked and unlock failed: {exc}",
                file=sys.stderr,
            )
            return 2

    deleted = 0
    failures = 0
    for item in collection.get_all_items():
        attrs = item.get_attributes()
        if attrs.get("account") != account_value:
            continue
        try:
            item.delete()
            deleted += 1
        except Exception as exc:
            failures += 1
            print(
                f"clear-keyring: failed to delete {item.item_path!s}: {exc}",
                file=sys.stderr,
            )

    print(f"clear-keyring: deleted {deleted} item(s) (account={account_value})")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
