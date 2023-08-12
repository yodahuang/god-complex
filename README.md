# Nix god complex

[This](https://old.reddit.com/r/NixOS/comments/kauf1m/dealing_with_post_nixflake_god_complex/).

## Setting this up a a fresh Nix machine

```bash
nix --experimental-features 'nix-command flakes' run nixpkgs#git clone https://github.com/yodahuang/god-complex.git
```
