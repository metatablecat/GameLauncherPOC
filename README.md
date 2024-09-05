# AvatarStore

Toolchain for saving Roblox avatars outside Roblox.

Made because Roblox wont add outfit privacy!! Get this done!

# Authenticating

You can authenticate direclty using the Quick Login system, to do this, just type `auth`.

This application appears in your account security settings as `Roblox Unknown App`, and you can log it out there or by using `auth logout`.

## Auth cookie usage

This tool uses your Roblox authentication cookie to:
* Fetch your outfits
* Fetch your avatar
* Know who you are
* Wear outfits for you

You can vet this by searching for `Http.AuthenticatedRequest` calls within the sourcecode.

# Installation

We recomend building from source since this relies on auth cookies. You can do this
using `darklua` and `lune`.

```
darklua process src/init.luau build/a.luau
lune build -t win-x86_64 -o build/avatarstore.exe build/a.luau
```